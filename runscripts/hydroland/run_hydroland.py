#!/usr/bin/env python3
from __future__ import annotations

import argparse
import calendar
import inspect
import logging
from datetime import datetime, timedelta
from pathlib import Path

from hydroland.model.completion import cleanup_files

# Defensive: forcings cleanup may not exist in an older container image yet.
try:
    from hydroland.model.completion import cleanup_global_forcings
except ImportError:
    cleanup_global_forcings = None
try:
    from hydroland.model.completion import (
        prune_daily_restarts,
        prune_monthly_subdomain_restarts,
    )
except ImportError:
    prune_daily_restarts = prune_monthly_subdomain_restarts = None
from hydroland.model.create_folders import create_folders
from hydroland.model.flux_merge import merge_monthly_subdomain_fluxes

# Defensive: these may not exist in an older container image yet.
try:
    from hydroland.model.flux_merge import merge_one_model
except ImportError:
    merge_one_model = None
try:
    from hydroland.model.flux_merge import daily_mhm_flux_name
except ImportError:
    daily_mhm_flux_name = None
from hydroland.model.initialisation import start_initialisation
from hydroland.model.mhm import execute_mhm
from hydroland.model.mrm import execute_mrm, execute_mrm_subdomain

# Defensive: the split-daily helpers may not exist in an older container image.
try:
    from hydroland.model.mrm import (
        finalize_mrm,
        prepare_mrm_run,
        run_mrm_one_subdomain,
    )
except ImportError:  # pragma: no cover - depends on the container image
    finalize_mrm = prepare_mrm_run = run_mrm_one_subdomain = None
from hydroland.model.preprocess import preprocess_forcings

# HydroLand execution stages. The Climate DT workflow runs these as separate
# jobs for monthly runs; daily runs use the single full-pipeline stage.
STAGES = (
    "all",
    "forcings",
    "subdomain",
    "merge",
    "forcings-cleanup",
    "day-pre",
    "day-mrm",
    "day-post",
)
# "all"       full pipeline (init -> preprocess -> mHM -> mRM -> cleanup); daily.
# "forcings"  monthly stage A: build the whole-domain merged monthly forcing only.
# "subdomain" monthly stage B: run one subdomain (crop -> mHM -> mRM), no cleanup.
# "merge"     monthly stage C: merge subdomain fluxes onto the global grid + cleanup.
# "forcings-cleanup"  drop the window's global pet/tavg and reduce its pre file.
#             Runs once, after every subdomain has finished, so the 26
#             subdomain processes never race on these shared files.
#
# The three "day-*" stages split a daily run the same way, so the workflow can
# place each mRM subdomain on its own node. mRM cannot fan itself out from
# inside the container: it is launched with --cleanenv (so no SLURM_* variables
# reach it) and the image carries neither srun nor scontrol. Daily runs that
# fit on one node keep using "all", which is unchanged.
# "day-pre"   init -> preprocess -> mHM -> stage mRM inputs. No subdomain runs.
# "day-mrm"   run exactly one mRM --subdomain. One Slurm step per subdomain.
# "day-post"  merge the mRM subdomains, finish the mHM output, clean up.

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")


def _run_mode_label(run_frequency: str) -> str:
    return "Daily run" if run_frequency == "day" else "Monthly run"


def parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run HydroLand initialisation, forcing preprocessing, mHM/mRM "
            "execution, and cleanup, with month/subdomain-aware paths."
        )
    )

    parser.add_argument("--hydroland-opa", required=True, help="OPA directory")
    parser.add_argument(
        "--init-files", required=True, help="Base directory for initial files"
    )
    parser.add_argument(
        "--app-outpath", required=True, help="Application output base directory"
    )

    # Chunk date range (used when --run-frequency month)
    parser.add_argument(
        "--ini-year-chunk", required=True, help="Chunk initialization year (YYYY)"
    )
    parser.add_argument(
        "--ini-month-chunk", required=True, help="Chunk initialization month (MM)"
    )
    parser.add_argument(
        "--ini-day-chunk", required=True, help="Chunk initialization day (DD)"
    )
    parser.add_argument("--end-year-chunk", required=True, help="Chunk end year (YYYY)")
    parser.add_argument("--end-month-chunk", required=True, help="Chunk end month (MM)")
    parser.add_argument("--end-day-chunk", required=True, help="Chunk end day (DD)")

    # Split date range (used when --run-frequency day)
    parser.add_argument(
        "--ini-year-split", required=True, help="Split initialization year (YYYY)"
    )
    parser.add_argument(
        "--ini-month-split", required=True, help="Split initialization month (MM)"
    )
    parser.add_argument(
        "--ini-day-split", required=True, help="Split initialization day (DD)"
    )

    parser.add_argument(
        "--stat-freq",
        required=True,
        choices=["daily", "hourly"],
        help="Input forcing frequency. Only 'daily' and 'hourly' are supported.",
    )
    parser.add_argument("--pre", required=True, help="Precipitation variable")
    parser.add_argument("--temp", required=True, help="Temperature variable")
    parser.add_argument(
        "--grid",
        required=True,
        choices=["0.1/0.1", "0.05/0.05"],
        help="Spatial resolution",
    )
    parser.add_argument(
        "--run-frequency",
        choices=["day", "month"],
        default="day",
        help="HydroLand run frequency",
    )
    parser.add_argument(
        "--stage",
        choices=list(STAGES),
        default="all",
        help=(
            "Pipeline stage to run. 'all' = full pipeline (daily). Monthly is split "
            "into 'forcings' (build whole-domain merged forcing), 'subdomain' (run one "
            "--subdomain), and 'merge' (merge subdomain fluxes + cleanup). Daily can "
            "optionally be split into 'day-pre', 'day-mrm' (one --subdomain per call) "
            "and 'day-post' so the caller can spread mRM across nodes."
        ),
    )
    parser.add_argument(
        "--executable-mhm",
        default="mhm",
        help="Path to the mHM executable",
    )
    parser.add_argument(
        "--executable-mrm",
        default="mrm",
        help="Path to the mRM executable",
    )
    parser.add_argument(
        "--omp-num-threads-mhm",
        type=int,
        default=1,
        help="OMP_NUM_THREADS value to use for mHM",
    )
    parser.add_argument("--merge-timesteps-per-chunk", type=int, default=24)
    parser.add_argument(
        "--merge-buffer-target-mb",
        type=int,
        default=4096,
        help="Per-pass memory budget (MB) for merge's global block. --stage merge only.",
    )
    parser.add_argument(
        "--merge-model",
        choices=("mhm", "mrm"),
        default=None,
        help=(
            "--stage merge only: merge just this model instead of both, e.g. to "
            "run mhm/mrm as separate jobs. Combine with --skip-cleanup, then run "
            "one final --skip-merge call once both are done."
        ),
    )
    parser.add_argument(
        "--skip-merge",
        action="store_true",
        help="Only used with --stage merge. Skip the merge itself, run cleanup only.",
    )
    parser.add_argument(
        "--skip-cleanup",
        action="store_true",
        help="Only used with --stage merge. Skip cleanup, run the merge only.",
    )
    parser.add_argument(
        "--num-subdomains",
        type=int,
        default=None,
        help=(
            "Number of subdomains for monthly runs. "
            "Defaults to 26 at 0.05/0.05 and 53 at 0.1/0.1 when omitted."
        ),
    )
    parser.add_argument(
        "--subdomain",
        type=int,
        choices=range(1, 27),
        metavar="{1..26}",
        default=None,
        help=(
            "Optional subdomain ID (1-26). Used with --run-frequency month, or "
            "with --stage day-mrm to run a single daily mRM subdomain."
        ),
    )
    parser.add_argument(
        "--mrm-parallel-subdomains",
        type=int,
        default=None,
        help=(
            "How many mRM subdomains the whole-domain (non --subdomain) "
            "execution path runs in parallel. Defaults to 26 at 0.05/0.05 and "
            "53 at 0.1/0.1 when omitted. Ignored when --subdomain is set "
            "(always 1 there)."
        ),
    )
    parser.add_argument(
        "--max-workers",
        type=int,
        default=None,
        help=(
            "Maximum number of concurrent precipitation, temperature, and PET "
            "preprocessing worker processes. Defaults to one worker per day in "
            "the chunk for monthly runs (e.g. 31 for a 31-day month)."
        ),
    )
    parser.add_argument(
        "--merge-compression-level",
        type=int,
        default=None,
        help=(
            "zlib compression level for the monthly forcing merge (1-9). "
            "Default None (uncompressed) - compression is CPU-bound and adds "
            "real time to the merge for a smaller output file."
        ),
    )
    parser.add_argument("--bias-adjustment", action="store_true")
    parser.add_argument("--prior-app-outpath", type=str, default="")
    parser.add_argument("--restart-from-prior-run", action="store_true")
    parser.add_argument(
        "--delete-files",
        action="store_true",
        help="Whether to delete intermediate files",
    )
    parser.add_argument(
        "--apply-indicators",
        action="store_true",
        help="If set, keep forcing files to calculate indicators.",
    )

    args = parser.parse_args(argv)

    if args.merge_timesteps_per_chunk < 1:
        parser.error("--merge-timesteps-per-chunk must be >= 1.")
    if args.omp_num_threads_mhm < 1:
        parser.error("--omp-num-threads-mhm must be >= 1.")
    if args.num_subdomains is not None and args.num_subdomains < 1:
        parser.error("--num-subdomains must be >= 1.")
    if args.max_workers is not None and args.max_workers < 1:
        parser.error("--max-workers must be >= 1.")
    if args.mrm_parallel_subdomains is not None and args.mrm_parallel_subdomains < 1:
        parser.error("--mrm-parallel-subdomains must be >= 1.")
    if (
        args.run_frequency != "month"
        and args.subdomain is not None
        and args.stage != "day-mrm"
    ):
        parser.error(
            "--subdomain is only valid when --run-frequency month, or with "
            "--stage day-mrm."
        )
    if args.run_frequency != "month" and args.num_subdomains is not None:
        parser.error("--num-subdomains is only valid when --run-frequency month.")
    # Monthly runs are only supported at 0.05/0.05 (5 km). Daily runs support
    # both 0.05/0.05 and 0.1/0.1.
    if args.run_frequency == "month" and args.grid != "0.05/0.05":
        parser.error(
            "Monthly HydroLand runs are only supported at 0.05/0.05 resolution."
        )
    if args.restart_from_prior_run and not args.prior_app_outpath:
        parser.error(
            "--prior-app-outpath is required if --restart-from-prior-run is set to True."
        )

    # Stage consistency: the staged 'forcings'/'subdomain'/'merge' jobs are
    # monthly-only; 'subdomain' needs a --subdomain, the others must not have one.
    if (
        args.stage in ("forcings", "subdomain", "merge")
        and args.run_frequency != "month"
    ):
        parser.error(f"--stage {args.stage} is only valid with --run-frequency month.")
    if args.stage == "subdomain" and args.subdomain is None:
        parser.error("--stage subdomain requires --subdomain.")
    if args.stage in ("forcings", "merge") and args.subdomain is not None:
        parser.error(f"--stage {args.stage} must not be combined with --subdomain.")
    # The split-daily stages mirror the monthly ones, the other way round:
    # day-only, and only day-mrm carries a --subdomain.
    if args.stage.startswith("day-") and args.run_frequency != "day":
        parser.error(f"--stage {args.stage} is only valid with --run-frequency day.")
    if args.stage == "forcings-cleanup" and args.subdomain is not None:
        parser.error("--stage forcings-cleanup must not be combined with --subdomain.")
    if args.stage == "day-mrm" and args.subdomain is None:
        parser.error("--stage day-mrm requires --subdomain.")
    if args.stage in ("day-pre", "day-post") and args.subdomain is not None:
        parser.error(f"--stage {args.stage} must not be combined with --subdomain.")
    if args.stage != "merge" and (
        args.merge_model is not None or args.skip_merge or args.skip_cleanup
    ):
        parser.error(
            "--merge-model/--skip-merge/--skip-cleanup are only valid with --stage merge."
        )
    if args.skip_merge and args.merge_model is not None:
        parser.error("--skip-merge and --merge-model are mutually exclusive.")
    if args.merge_buffer_target_mb < 1:
        parser.error("--merge-buffer-target-mb must be >= 1.")

    subdomain_count = _effective_subdomain_count(args.grid, args.num_subdomains)
    if args.subdomain is not None and not 1 <= args.subdomain <= subdomain_count:
        parser.error(
            f"--subdomain must be between 1 and {subdomain_count} "
            f"(got {args.subdomain})."
        )

    return args


def _default_subdomain_count(grid: str) -> int:
    return 26 if grid == "0.05/0.05" else 53


def _effective_subdomain_count(grid: str, num_subdomains: int | None) -> int:
    if num_subdomains is not None:
        return num_subdomains
    return _default_subdomain_count(grid)


def _build_previous_date_tag(ini_dt: datetime, run_frequency: str) -> str:
    if run_frequency == "month":
        current_month_start = ini_dt.replace(day=1)
        previous_month_end = current_month_start - timedelta(days=1)
        previous_month_start = previous_month_end.replace(day=1)
        return f"{previous_month_start:%Y_%m_%d}_to_{previous_month_end:%Y_%m_%d}"

    previous_day = ini_dt - timedelta(days=1)
    previous_day_tag = previous_day.strftime("%Y_%m_%d")
    return f"{previous_day_tag}_to_{previous_day_tag}"


def _build_next_date_tag(end_dt: datetime, run_frequency: str) -> str:
    if run_frequency == "month":
        if end_dt.month == 12:
            next_year = end_dt.year + 1
            next_month = 1
        else:
            next_year = end_dt.year
            next_month = end_dt.month + 1
        next_month_start = datetime(next_year, next_month, 1)
        next_month_end = datetime(
            next_year,
            next_month,
            calendar.monthrange(next_year, next_month)[1],
        )
        return f"{next_month_start:%Y_%m_%d}_to_{next_month_end:%Y_%m_%d}"

    next_day = end_dt + timedelta(days=1)
    next_day_tag = next_day.strftime("%Y_%m_%d")
    return f"{next_day_tag}_to_{next_day_tag}"


def _build_mhm_output_filename(ini_date: str, end_date: str, stat_freq: str) -> str:
    if stat_freq == "hourly":
        return f"{ini_date}_T00_00_to_{end_date}_T23_00_mHM_Fluxes_States.nc"
    return f"{ini_date}_to_{end_date}_mHM_Fluxes_States.nc"


def _build_mrm_output_filename(ini_date: str, end_date: str, stat_freq: str) -> str:
    if stat_freq == "hourly":
        return f"{ini_date}_T00_00_to_{end_date}_T23_00_mRM_Fluxes_States.nc"
    return f"{ini_date}_to_{end_date}_mRM_Fluxes_States.nc"


def _resolve_runtime_paths(
    app_outpath: str,
    run_frequency: str,
    subdomain: int | None,
) -> dict[str, Path]:
    hydroland_root = Path(app_outpath) / "hydroland"
    run_subdomain = run_frequency == "month" and subdomain is not None

    if run_subdomain:
        instance_root = hydroland_root / "subdomains" / f"subdomain_{subdomain}"
        shared_forcings_dir = hydroland_root / "forcings"
        instance_forcings_dir = instance_root / "forcings"
    else:
        instance_root = hydroland_root
        shared_forcings_dir = hydroland_root / "forcings"
        instance_forcings_dir = shared_forcings_dir

    return {
        "hydroland_root": hydroland_root,
        "instance_root": instance_root,
        "shared_forcings_dir": shared_forcings_dir,
        "instance_forcings_dir": instance_forcings_dir,
        "current_mhm_dir": instance_root / "mhm" / "current_run",
        "mhm_log_dir": instance_root / "mhm" / "log_files",
        "mhm_fluxes_dir": instance_root / "mhm" / "fluxes",
        "mhm_restart_dir": instance_root / "mhm" / "restart_files",
        "current_mrm_dir": instance_root / "mrm" / "current_run",
        "mrm_log_dir": instance_root / "mrm" / "log_files",
        "mrm_fluxes_dir": instance_root / "mrm" / "fluxes",
        "mrm_restart_dir": instance_root / "mrm" / "restart_files",
    }


def _cleanup_daily_outputs(
    paths: dict[str, Path],
    ini_date: str,
    run_frequency: str,
    delete_files: bool,
) -> None:
    """Per-day cleanup shared by the single-node ("all") and split ("day-post")
    daily paths.

    A daily run reaches exactly one of those two branches once per day, so the
    cleanup is safe to do inline - no separate stage is needed the way it is for
    the 26 monthly subdomains. Both branches must call this; keeping two copies
    is how the multi-node path came to be missed, leaving its pre forcings
    unreduced and its restarts unpruned.

    The ``is not None`` guards matter: both callees are imported under
    ``try``/``except ImportError`` so this runscript still works against older
    container images that lack them.
    """
    if not delete_files:
        return

    if cleanup_global_forcings is not None:
        cleanup_global_forcings(
            str(paths["shared_forcings_dir"]),
            prefix=ini_date,
            run_frequency=run_frequency,
        )
    # Thin the day-run restarts to one per completed month. The month being
    # run is left alone, since a later day of it still needs those.
    if prune_daily_restarts is not None:
        prune_daily_restarts(str(paths["hydroland_root"]), ini_date)


def run_pipeline(
    hydroland_opa: str,
    init_files: str,
    app_outpath: str,
    ini_year_chunk: str,
    ini_month_chunk: str,
    ini_day_chunk: str,
    end_year_chunk: str,
    end_month_chunk: str,
    end_day_chunk: str,
    ini_year_split: str,
    ini_month_split: str,
    ini_day_split: str,
    stat_freq: str,
    pre: str,
    temp: str,
    grid: str,
    run_frequency: str,
    merge_timesteps_per_chunk: int,
    max_workers: int | None,
    subdomain: int | None,
    num_subdomains: int | None,
    executable_mhm: str,
    executable_mrm: str,
    omp_num_threads_mhm: int,
    bias_adjustment: bool,
    prior_app_outpath: str,
    restart_from_prior_run: bool,
    delete_files: bool,
    apply_indicators: bool,
    stage: str = "all",
    merge_buffer_target_mb: int = 4096,
    merge_model: str | None = None,
    skip_merge: bool = False,
    skip_cleanup: bool = False,
    mrm_parallel_subdomains: int | None = None,
    merge_compression_level: int | None = None,
) -> dict[str, Path]:
    """Run the HydroLand pipeline, or one stage of it (see ``STAGES``).

    ``stage`` selects how much of the pipeline runs:
      * ``"all"``       full pipeline + cleanup (daily runs).
      * ``"forcings"``  monthly stage A: whole-domain merged monthly forcing only.
      * ``"subdomain"`` monthly stage B: one subdomain (crop -> mHM -> mRM), no cleanup.
      * ``"merge"``     monthly stage C: merge subdomain fluxes + cleanup (no model run).
    """
    run_mode_label = _run_mode_label(run_frequency)

    # Select ini/end date parts based on run_frequency: daily runs use the
    # split date, monthly runs use the chunk date range.
    run_frequency_mapping = {
        "day": (
            (ini_year_split, ini_month_split, ini_day_split),
            (ini_year_split, ini_month_split, ini_day_split),
        ),
        "month": (
            (ini_year_chunk, ini_month_chunk, ini_day_chunk),
            (end_year_chunk, end_month_chunk, end_day_chunk),
        ),
    }
    ini_year, ini_month, ini_day = run_frequency_mapping[run_frequency][0]
    end_year, end_month, end_day = run_frequency_mapping[run_frequency][1]
    ini_dt = datetime.strptime(f"{ini_year}-{ini_month}-{ini_day}", "%Y-%m-%d")
    end_dt = datetime.strptime(f"{end_year}-{end_month}-{end_day}", "%Y-%m-%d")
    ini_date = ini_dt.strftime("%Y_%m_%d")
    end_date = end_dt.strftime("%Y_%m_%d")
    previous_date = _build_previous_date_tag(ini_dt, run_frequency)
    next_date = _build_next_date_tag(end_dt, run_frequency)

    mhm_out_file = _build_mhm_output_filename(ini_date, end_date, stat_freq)
    mrm_out_file = _build_mrm_output_filename(ini_date, end_date, stat_freq)

    resolution = 0.1 if grid == "0.1/0.1" else 0.05

    # Are we running a single named subdomain?
    run_subdomain = run_frequency == "month" and subdomain is not None

    # How many mRM subdomains the non-subdomain execution path runs in
    # parallel. A named subdomain (month-mode per-subdomain call) always
    # wins over any override; otherwise an explicit --mrm-parallel-subdomains
    # replaces the resolution-based default (26 at 5 km, 53 at 10 km).
    if subdomain is not None:
        mrm_parallel_subdomains = 1
    elif mrm_parallel_subdomains is None:
        mrm_parallel_subdomains = 26 if resolution == 0.05 else 53

    subdomain_count = _effective_subdomain_count(grid, num_subdomains)
    paths = _resolve_runtime_paths(app_outpath, run_frequency, subdomain)

    # Monthly stage C: merge the per-subdomain fluxes onto the global grid and
    # clean up. No initialisation / preprocessing / model execution is needed.
    # merge_model/skip_merge/skip_cleanup split this into separate mhm/mrm
    # jobs plus a final cleanup-only call - see --merge-model's help text.
    if stage == "merge":
        if not skip_merge:
            logger.info(f"{run_mode_label}: merging subdomain fluxes.")
            merge_kwargs = {}
            # This runscript is bind-mounted and can be newer than the hydroland
            # package inside the container; only pass params the installed
            # merge functions actually support.
            # Monthly runs reduce each subdomain's mHM fluxes to daily means
            # in the subdomain stage, so the merge reads the daily file that
            # aggregation wrote, not the hourly name mHM produced. mRM is
            # untouched and keeps its own (hourly) name and time axis.
            mhm_merge_name = (
                daily_mhm_flux_name(ini_date, end_date)
                if daily_mhm_flux_name is not None
                else mhm_out_file
            )
            if merge_model is None:
                merge_fn = merge_monthly_subdomain_fluxes
                merge_call_kwargs = dict(
                    hydroland_root=str(paths["hydroland_root"]),
                    mhm_flux_name=mhm_merge_name,
                    mrm_flux_name=mrm_out_file,
                    time_chunk=merge_timesteps_per_chunk,
                    resolution=resolution,
                )
            else:
                if merge_one_model is None:
                    raise RuntimeError(
                        "--merge-model was given but the installed hydroland package "
                        "does not provide merge_one_model - it is older than this "
                        "runscript. Rebuild/update the hydroland container image, or "
                        "drop --merge-model (HYDROLAND_MERGE_SPLIT_NODES=False) to "
                        "merge both models together on this one process/node instead."
                    )
                merge_fn = merge_one_model
                merge_call_kwargs = dict(
                    hydroland_root=str(paths["hydroland_root"]),
                    model_name=merge_model,
                    flux_name=(
                        mhm_merge_name if merge_model == "mhm" else mrm_out_file
                    ),
                    time_chunk=merge_timesteps_per_chunk,
                    resolution=resolution,
                )
            merge_params = inspect.signature(merge_fn).parameters
            days_in_window = (end_dt - ini_dt).days + 1
            steps_per_day = 24 if stat_freq == "hourly" else 1
            if "expected_timesteps" in merge_params:
                # mRM keeps the model's own step; mHM is daily after the
                # subdomain-stage aggregation, i.e. one step per day.
                if merge_model == "mhm":
                    merge_kwargs["expected_timesteps"] = days_in_window
                else:
                    merge_kwargs["expected_timesteps"] = days_in_window * steps_per_day
            if "expected_mhm_timesteps" in merge_params:
                merge_kwargs["expected_mhm_timesteps"] = days_in_window
            if "buffer_target_bytes" in merge_params:
                merge_kwargs["buffer_target_bytes"] = (
                    merge_buffer_target_mb * 1024 * 1024
                )
            merge_fn(**merge_call_kwargs, **merge_kwargs)
        if not skip_cleanup:
            logger.info(f"{run_mode_label}: cleaning up.")
            cleanup_files(
                ini_date=ini_date,
                forcings_dir=str(paths["instance_forcings_dir"]),
                mhm_restart_dir=str(paths["mhm_restart_dir"]),
                mhm_log_dir=str(paths["mhm_log_dir"]),
                mrm_restart_dir=str(paths["mrm_restart_dir"]),
                mrm_log_dir=str(paths["mrm_log_dir"]),
                hydroland_opa=hydroland_opa,
                delete_files=delete_files,
                bias_adjustment=bias_adjustment,
                apply_indicators=apply_indicators,
                end_date=end_date,
                run_frequency=run_frequency,
                hydroland_root=str(paths["hydroland_root"]),
                mhm_out_file=mhm_out_file,
                mrm_out_file=mrm_out_file,
                subdomain_count=subdomain_count,
            )
        return paths

    # Drop the forcings this window no longer needs. Separate from the merge so
    # the disk is freed as soon as the models are done, rather than whenever the
    # merge happens to be run.
    if stage == "forcings-cleanup":
        if not delete_files:
            logger.info(
                f"{run_mode_label}: stage 'forcings-cleanup' - --delete-files "
                "not set, keeping all forcings."
            )
            return paths
        if cleanup_global_forcings is None:
            raise RuntimeError(
                "--stage forcings-cleanup needs a hydroland build with "
                "cleanup_global_forcings(); this container image is too old."
            )
        prefix = ini_date[:7] if run_frequency == "month" else ini_date
        logger.info(
            f"{run_mode_label}: stage 'forcings-cleanup' - {prefix} in "
            f"{paths['shared_forcings_dir']}."
        )
        cleanup_global_forcings(
            str(paths["shared_forcings_dir"]),
            prefix=prefix,
            run_frequency=run_frequency,
        )
        # Entering a new year means the previous one is finished and its
        # monthly restarts are no longer needed to continue - keep January's
        # as that year's single restart point. Only files starting inside that
        # year are touched, so the restart this run depends on (which starts in
        # the current year) is never at risk.
        if (
            run_frequency == "month"
            and ini_dt.month == 1
            and prune_monthly_subdomain_restarts is not None
        ):
            prune_monthly_subdomain_restarts(
                str(paths["hydroland_root"]),
                ini_dt.year - 1,
                subdomain_count=subdomain_count,
            )
        return paths

    # Daily stage B: run exactly one mRM subdomain and nothing else. The caller
    # (the workflow) has already placed this process on the node it wants, and
    # "day-pre" has already staged run_parallel_mrm.sh and the mHM flux input.
    if stage == "day-mrm":
        if run_mrm_one_subdomain is None:
            raise RuntimeError(
                "--stage day-mrm needs a hydroland build with "
                "run_mrm_one_subdomain(); this container image is too old."
            )
        logger.info(f"{run_mode_label}: stage 'day-mrm' - subdomain {subdomain}.")
        run_mrm_one_subdomain(
            current_mrm_dir=str(paths["current_mrm_dir"]),
            init_files=init_files,
            resolution=resolution,
            subdomain=subdomain,
        )
        return paths

    # Daily stage C: every subdomain has finished, so merge them onto the global
    # grid, finish the mHM output, and clean up.
    if stage == "day-post":
        if finalize_mrm is None:
            raise RuntimeError(
                "--stage day-post needs a hydroland build with finalize_mrm(); "
                "this container image is too old."
            )
        logger.info(f"{run_mode_label}: stage 'day-post' - merging mRM subdomains.")
        finalize_mrm(
            current_mrm_dir=str(paths["current_mrm_dir"]),
            mrm_restart_dir=str(paths["mrm_restart_dir"]),
            mrm_log_dir=str(paths["mrm_log_dir"]),
            ini_date=ini_date,
            end_date=end_date,
            next_date=next_date,
            stat_freq=stat_freq,
            init_files=init_files,
            mhm_fluxes_dir=str(paths["mhm_fluxes_dir"]),
            mrm_fluxes_dir=str(paths["mrm_fluxes_dir"]),
            mhm_out_file=mhm_out_file,
            mrm_out_file=mrm_out_file,
            hydroland_opa=hydroland_opa,
            pre=pre,
            resolution=resolution,
        )
        logger.info(
            f"{run_mode_label}: cleaning up files and finishing Hydroland execution."
        )
        cleanup_files(
            ini_date=ini_date,
            forcings_dir=str(paths["instance_forcings_dir"]),
            mhm_restart_dir=str(paths["mhm_restart_dir"]),
            mhm_log_dir=str(paths["mhm_log_dir"]),
            mrm_restart_dir=str(paths["mrm_restart_dir"]),
            mrm_log_dir=str(paths["mrm_log_dir"]),
            hydroland_opa=hydroland_opa,
            delete_files=delete_files,
            bias_adjustment=bias_adjustment,
            apply_indicators=apply_indicators,
            end_date=end_date,
            run_frequency=run_frequency,
            hydroland_root=str(paths["hydroland_root"]),
            mhm_out_file=mhm_out_file,
            mrm_out_file=mrm_out_file,
        )
        # Same cleanup the single-node "all" path performs. Without it a
        # multi-node daily run never cleans up, because it never enters the
        # "all" branch.
        _cleanup_daily_outputs(paths, ini_date, run_frequency, delete_files)
        return paths

    # Monthly stage A: only the whole-domain merged monthly forcing is needed.
    # Skip the day-style folder tree and initialisation entirely - they set up
    # whole-domain mHM/mRM execution (namelists, restart links) that no
    # monthly stage ever reads (subdomains have their own instance trees, and
    # preprocess_forcings creates the forcings dir itself).
    if stage == "forcings":
        logger.info(
            f"{run_mode_label}: stage 'forcings' - preprocessing Hydroland "
            f"forcing files for {ini_date} → {end_date} into "
            f"{paths['instance_forcings_dir']}."
        )
        logger.info(
            "Forcing preprocessing maximum workers: %s.",
            max_workers if max_workers is not None else "default",
        )
        preprocess_forcings(
            ini_date=ini_date,
            end_date=end_date,
            stat_freq=stat_freq,
            temp_var=temp,
            pre_var=pre,
            forcings_dir=str(paths["instance_forcings_dir"]),
            hydroland_opa=hydroland_opa,
            run_frequency=run_frequency,
            max_workers=max_workers,
            merge_timesteps_per_chunk=merge_timesteps_per_chunk,
            subdomain=subdomain,
            run_subdomain=run_subdomain,
            resolution=resolution,
            init_files=init_files,
            compression_level=merge_compression_level,
        )
        logger.info(
            f"{run_mode_label}: stage 'forcings' complete ({ini_date} → {end_date})."
        )
        return paths

    # Build the full execution directory tree up front so the run is
    # self-sufficient (no separate `hydroland create_folders` step needed). The
    # model/initialisation paths only create a subset (notably not mhm/log_files
    # or mhm/fluxes), so reuse the canonical, tested create_folders layout:
    #   * month + named subdomain -> that subdomain's instance tree
    #   * everything else         -> the whole-domain (day-style) tree
    if run_subdomain:
        create_folders(
            app_outpath,
            run_frequency="month",
            subdomains=subdomain_count,
            subdomain_ids=[subdomain],
        )
    else:
        create_folders(app_outpath, run_frequency="day", subdomains=subdomain_count)

    paths["mrm_log_dir"].mkdir(parents=True, exist_ok=True)
    paths["mrm_fluxes_dir"].mkdir(parents=True, exist_ok=True)
    preprocess_forcings_dir = (
        paths["shared_forcings_dir"]
        if run_subdomain
        else paths["instance_forcings_dir"]
    )

    # Only log settings that actually take effect for the current configuration.
    log_lines = [
        "",
        "Running Hydroland initialisation, preprocessing, mHM/mRM execution, and cleanup:",
        f"  execution mode              = {run_mode_label}",
        f"  date range                  = {ini_date} → {end_date}",
        f"  stat freq                   = {stat_freq}",
        f"  run frequency               = {run_frequency}",
        f"  precipitation               = {pre}",
        f"  temperature                 = {temp}",
        f"  spatial resolution          = {grid}",
        f"  hydroland root              = {paths['hydroland_root']}",
        f"  preprocess forcings dir     = {preprocess_forcings_dir}",
    ]
    if run_frequency == "month":
        # --subdomain only applies to monthly runs.
        log_lines.append(f"  subdomain                   = {subdomain}")
        log_lines.append(f"  run_subdomain               = {run_subdomain}")
        log_lines.append(f"  num subdomains              = {subdomain_count}")
    log_lines += [
        f"  mHM executable              = {executable_mhm}",
        f"  mRM executable              = {executable_mrm}",
        f"  mHM OpenMP threads          = {omp_num_threads_mhm}",
    ]
    if not run_subdomain:
        # mrm_parallel_subdomains only feeds execute_mrm(), not execute_mrm_subdomain().
        log_lines.append(f"  mRM parallel subdomains     = {mrm_parallel_subdomains}")
        # max_workers only affects the day-by-day prep/PET preprocessing; the
        # subdomain-crop path never reaches that code, so skip logging it there.
        log_lines.append(
            f"  preprocessing max workers   = "
            f"{max_workers if max_workers is not None else 'default'}"
        )
    if run_frequency == "month" and not run_subdomain:
        # merge_timesteps_per_chunk only affects the whole-domain monthly merge step.
        log_lines.append(f"  merge time steps per chunk  = {merge_timesteps_per_chunk}")
    log_lines.append(f"  bias adjustment             = {bias_adjustment}")
    if restart_from_prior_run:
        # prior_app_outpath is only consulted when restarting from a prior run.
        log_lines.append(f"  prior app outpath           = {prior_app_outpath}")
    log_lines.append(f"  restart from prior run      = {restart_from_prior_run}")
    log_lines.append(f"  delete intermediate files   = {delete_files}")
    log_lines.append(f"  apply indicators            = {apply_indicators}")
    logger.info("\n".join(log_lines) + "\n")

    logger.info(f"{run_mode_label}: initialising Hydroland runtime files.")
    start_initialisation(
        ini_date=ini_date,
        end_date=end_date,
        previous_date=previous_date,
        stat_freq=stat_freq,
        init_files=init_files,
        app_outpath=app_outpath,
        resolution=resolution,
        current_mhm_dir=str(paths["current_mhm_dir"]),
        forcings_dir=str(paths["instance_forcings_dir"]),
        mhm_restart_dir=str(paths["mhm_restart_dir"]),
        current_mrm_dir=str(paths["current_mrm_dir"]),
        mrm_restart_dir=str(paths["mrm_restart_dir"]),
        hydroland_opa=hydroland_opa,
        bias_adjustment=bias_adjustment,
        prior_app_outpath=prior_app_outpath,
        restart_from_prior_run=restart_from_prior_run,
        run_frequency=run_frequency,
        subdomain=subdomain,
    )

    logger.info(f"{run_mode_label}: preprocessing Hydroland forcing files.")
    preprocess_forcings(
        ini_date=ini_date,
        end_date=end_date,
        stat_freq=stat_freq,
        temp_var=temp,
        pre_var=pre,
        forcings_dir=str(preprocess_forcings_dir),
        hydroland_opa=hydroland_opa,
        run_frequency=run_frequency,
        max_workers=max_workers,
        merge_timesteps_per_chunk=merge_timesteps_per_chunk,
        subdomain=subdomain,
        run_subdomain=run_subdomain,
        resolution=resolution,
        init_files=init_files,
        compression_level=merge_compression_level,
    )

    # Run mHM after forcings are ready for the current day or month window.
    logger.info(f"{run_mode_label}: starting execution process for mHM.")
    execute_mhm(
        ini_date=ini_date,
        end_date=end_date,
        next_date=next_date,
        current_mhm_dir=str(paths["current_mhm_dir"]),
        forcings_dir=str(paths["instance_forcings_dir"]),
        mhm_log_dir=str(paths["mhm_log_dir"]),
        mhm_fluxes_dir=str(paths["mhm_fluxes_dir"]),
        mhm_restart_dir=str(paths["mhm_restart_dir"]),
        hydroland_opa=hydroland_opa,
        pre=pre,
        stat_freq=stat_freq,
        mhm_out_file=mhm_out_file,
        executable_mhm=executable_mhm,
        omp_num_threads_mhm=omp_num_threads_mhm,
        run_frequency=run_frequency,
    )

    # Daily stage A stops here: stage everything mRM needs, but run no
    # subdomain. The workflow then issues one "day-mrm" Slurm step per
    # subdomain, and finally one "day-post".
    if stage == "day-pre":
        if prepare_mrm_run is None:
            raise RuntimeError(
                "--stage day-pre needs a hydroland build with prepare_mrm_run(); "
                "this container image is too old."
            )
        logger.info(f"{run_mode_label}: stage 'day-pre' - staging mRM inputs.")
        arg_list = prepare_mrm_run(
            current_mrm_dir=str(paths["current_mrm_dir"]),
            mrm_restart_dir=str(paths["mrm_restart_dir"]),
            ini_date=ini_date,
            end_date=end_date,
            next_date=next_date,
            stat_freq=stat_freq,
            init_files=init_files,
            forcings_dir=str(paths["instance_forcings_dir"]),
            mhm_fluxes_dir=str(paths["mhm_fluxes_dir"]),
            mhm_out_file=mhm_out_file,
            resolution=resolution,
            executable_mrm=executable_mrm,
        )
        logger.info(
            f"{run_mode_label}: stage 'day-pre' complete - {len(arg_list)} mRM "
            f"subdomains staged and ready to run."
        )
        return paths

    logger.info(f"{run_mode_label}: starting execution process for mRM.")
    if run_subdomain:
        execute_mrm_subdomain(
            current_mrm_dir=str(paths["current_mrm_dir"]),
            mrm_restart_dir=str(paths["mrm_restart_dir"]),
            mrm_log_dir=str(paths["mrm_log_dir"]),
            ini_date=ini_date,
            end_date=end_date,
            next_date=next_date,
            stat_freq=stat_freq,
            init_files=init_files,
            forcings_dir=str(paths["instance_forcings_dir"]),
            mhm_fluxes_dir=str(paths["mhm_fluxes_dir"]),
            mrm_fluxes_dir=str(paths["mrm_fluxes_dir"]),
            mhm_out_file=mhm_out_file,
            mrm_out_file=mrm_out_file,
            hydroland_opa=hydroland_opa,
            pre=pre,
            resolution=resolution,
            subdomain=subdomain,
            executable_mrm=executable_mrm,
            **(
                {"delete_files": delete_files}
                if "delete_files" in inspect.signature(execute_mrm_subdomain).parameters
                else {}
            ),
        )
    else:
        execute_mrm(
            current_mrm_dir=str(paths["current_mrm_dir"]),
            mrm_restart_dir=str(paths["mrm_restart_dir"]),
            mrm_log_dir=str(paths["mrm_log_dir"]),
            ini_date=ini_date,
            end_date=end_date,
            next_date=next_date,
            stat_freq=stat_freq,
            init_files=init_files,
            forcings_dir=str(paths["instance_forcings_dir"]),
            mhm_fluxes_dir=str(paths["mhm_fluxes_dir"]),
            mrm_fluxes_dir=str(paths["mrm_fluxes_dir"]),
            mhm_out_file=mhm_out_file,
            mrm_out_file=mrm_out_file,
            hydroland_opa=hydroland_opa,
            pre=pre,
            resolution=resolution,
            executable_mrm=executable_mrm,
            mrm_parallel_subdomains=mrm_parallel_subdomains,
        )

    # Monthly stage B ("subdomain") stops here: cleanup/merge happen later in the
    # "merge" stage once every subdomain has finished. Only the full ("all")
    # pipeline (daily runs) cleans up inline.
    if stage == "all":
        logger.info(
            f"{run_mode_label}: cleaning up files and finishing Hydroland execution."
        )
        cleanup_files(
            ini_date=ini_date,
            forcings_dir=str(paths["instance_forcings_dir"]),
            mhm_restart_dir=str(paths["mhm_restart_dir"]),
            mhm_log_dir=str(paths["mhm_log_dir"]),
            mrm_restart_dir=str(paths["mrm_restart_dir"]),
            mrm_log_dir=str(paths["mrm_log_dir"]),
            hydroland_opa=hydroland_opa,
            delete_files=delete_files,
            bias_adjustment=bias_adjustment,
            apply_indicators=apply_indicators,
            end_date=end_date,
            run_frequency=run_frequency,
            hydroland_root=str(paths["hydroland_root"]),
            mhm_out_file=mhm_out_file,
            mrm_out_file=mrm_out_file,
        )
        _cleanup_daily_outputs(paths, ini_date, run_frequency, delete_files)

    return paths


if __name__ == "__main__":
    args = parse_args()
    run_pipeline(
        hydroland_opa=args.hydroland_opa,
        init_files=args.init_files,
        app_outpath=args.app_outpath,
        ini_year_chunk=args.ini_year_chunk,
        ini_month_chunk=args.ini_month_chunk,
        ini_day_chunk=args.ini_day_chunk,
        end_year_chunk=args.end_year_chunk,
        end_month_chunk=args.end_month_chunk,
        end_day_chunk=args.end_day_chunk,
        ini_year_split=args.ini_year_split,
        ini_month_split=args.ini_month_split,
        ini_day_split=args.ini_day_split,
        stat_freq=args.stat_freq,
        pre=args.pre,
        temp=args.temp,
        grid=args.grid,
        run_frequency=args.run_frequency,
        merge_timesteps_per_chunk=args.merge_timesteps_per_chunk,
        max_workers=args.max_workers,
        subdomain=args.subdomain,
        num_subdomains=args.num_subdomains,
        executable_mhm=args.executable_mhm,
        executable_mrm=args.executable_mrm,
        omp_num_threads_mhm=args.omp_num_threads_mhm,
        bias_adjustment=args.bias_adjustment,
        prior_app_outpath=args.prior_app_outpath,
        restart_from_prior_run=args.restart_from_prior_run,
        delete_files=args.delete_files,
        apply_indicators=args.apply_indicators,
        stage=args.stage,
        merge_buffer_target_mb=args.merge_buffer_target_mb,
        merge_model=args.merge_model,
        skip_merge=args.skip_merge,
        skip_cleanup=args.skip_cleanup,
        mrm_parallel_subdomains=args.mrm_parallel_subdomains,
        merge_compression_level=args.merge_compression_level,
    )
