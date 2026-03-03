#!/usr/bin/env python3
import argparse
import logging
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta
from pathlib import Path

from cdo import Cdo
from dateutil.relativedelta import relativedelta
from hydroland.model.completion import cleanup_files
from hydroland.model.initialisation import start_initialisation
from hydroland.model.mhm import execute_mhm
from hydroland.model.mrm import execute_mrm
from hydroland.model.preprocess import preprocess_forcings

# Initialize logging
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")


def parse_args(argv=None) -> argparse.Namespace:
    """
    Parses command-line arguments for the Hydroland pipeline.

    Parameters
    ----------
    argv : Optional[List[str]]
        List of arguments (defaults to sys.argv if None).

    Returns
    -------
    argparse.Namespace
        Parsed arguments namespace.
    """
    parser = argparse.ArgumentParser(
        description="Run Hydroland mHM/mRM processing pipeline"
    )

    # Paths
    parser.add_argument(
        "--hydroland-opa", help="OPA directory for Hydroland post-processing"
    )
    parser.add_argument("--init-files", help="Base directory for initial files")
    parser.add_argument("--app-outpath", help="Application output base directory")

    # Chunk date range
    parser.add_argument("--ini-year-chunk", help="Chunk initialization year (YYYY)")
    parser.add_argument("--ini-month-chunk", help="Chunk initialization month (MM)")
    parser.add_argument("--ini-day-chunk", help="Chunk initialization day (DD)")
    parser.add_argument("--end-year-chunk", help="Chunk end year (YYYY)")
    parser.add_argument("--end-month-chunk", help="Chunk end month (MM)")
    parser.add_argument("--end-day-chunk", help="Chunk end day (DD)")

    # Split date range
    parser.add_argument("--ini-year-split", help="Split initialization year (YYYY)")
    parser.add_argument("--ini-month-split", help="Split initialization month (MM)")
    parser.add_argument("--ini-day-split", help="Split initialization day (DD)")
    parser.add_argument("--end-year-split", help="Split end year (YYYY)")
    parser.add_argument("--end-month-split", help="Split end month (MM)")
    parser.add_argument("--end-day-split", help="Split end day (DD)")

    # Processing options
    parser.add_argument(
        "--stat-freq", choices=["daily", "hourly"], help="Output frequency"
    )
    parser.add_argument("--pre", help="Precipitation variable")
    parser.add_argument("--temp", help="Temperature variable")
    parser.add_argument(
        "--grid", choices=["0.1/0.1", "0.05/0.05"], help="Spatial resolution"
    )
    parser.add_argument(
        "--run-frequency",
        choices=["day", "month"],
        default="day",
        help="HydroLand run frequency (only 'day' or 'month' supported)",
    )

    # Executables & threading
    parser.add_argument("--executable-mhm", default="mhm", help="Path to mHM binary")
    parser.add_argument("--executable-mrm", default="mrm", help="Path to mRM binary")
    parser.add_argument(
        "--omp-num-threads", default="53", help="Number of threads for mRM"
    )

    # Cleanup
    (
        parser.add_argument(
            "--delete-files",
            action="store_true",
            help="Whether to delete intermediate files",
        ),
    )

    # execute or not BA
    parser.add_argument(
        "--bias-adjustment",
        action="store_true",
        help=(
            "If set, perform bias adjustment. This will add extra steps to "
            "back up and clean files."
        ),
    )

    # keep files for indicators or not
    parser.add_argument(
        "--apply-indicators",
        action="store_true",
        help=("If set, keep forcing files to calculate indicators."),
    )

    # get restart files from a previous run if needed
    parser.add_argument(
        "--prior-app-outpath",
        type=str,
        help=(
            "Directory with outputs from a previous Hydroland run: "
            "/path/to/${expid}/output/hydroland. "
            "When running Hydroland for the first time (cold start), "
            "current run will pull required files from prior-app-outpath "
            "instead of init-files path."
        ),
    )
    parser.add_argument(
        "--restart-from-prior-run",
        action="store_true",
        help=(
            "If set and running HydroLand for the first time (cold start), "
            "the restart files will be taken from --prior-app-outpath isntead of init-files."
        ),
    )
    parser.add_argument(
        "--apply-cdo-mergetime",
        action="store_true",
        help=("If set, apply CDO mergetime to the output files."),
    )

    args = parser.parse_args(argv)

    return args


def cdo_mergetime_in_dir(glob_pattern: str, out_path: Path, work_dir: Path) -> None:
    """Run cdo mergetime on files in work_dir matching glob_pattern.

    - If no files match: raise.
    - If exactly one file matches: warn and just copy that file to out_path.
    - If multiple files match: run cdo mergetime to concatenate along time.
    """
    cdo = Cdo()
    inputs = sorted(str(p) for p in work_dir.glob(glob_pattern))
    if not inputs:
        raise FileNotFoundError(
            f"No inputs matched pattern {glob_pattern} in {work_dir}"
        )
    if len(inputs) == 1:
        logger.info(
            f"Only one file matched pattern {glob_pattern} in {work_dir}. Skipping CDO mergetime."
        )
    else:
        logger.info(f"Found {len(inputs)} files.")
        out_path.parent.mkdir(parents=True, exist_ok=True)
        logger.debug(f"Running CDO mergetime to merge following {inputs=}")
        cdo.mergetime(input=" ".join(inputs), output=str(out_path), options="-O -s")
        logger.info(f"CDO merged {len(inputs)} files.")


def run_merges_in_parallel(
    pairs: list[tuple[str, Path]],
    work_dir: Path,
    run_frequency: str = None,
    stat_freq: str = None,
    max_workers: int = 2,
) -> None:
    """
    Run multiple cdo_mergetime_in_dir tasks concurrently.

    Each element in `pairs` is (glob_pattern, output_path).

    Behavior:
    run merges in parallel (up to max_workers).
    """
    logger.info(f"Running {run_frequency=} and {stat_freq=}, applying CDO mergetime.")
    with ThreadPoolExecutor(max_workers=min(max_workers, len(pairs))) as ex:
        fut_map = {
            ex.submit(cdo_mergetime_in_dir, g, out, work_dir): (g, out)
            for g, out in pairs
        }

        for fut in as_completed(fut_map):
            g, out = fut_map[fut]
            try:
                fut.result()  # will raise if cdo_mergetime_in_dir failed
            except Exception as e:
                logger.error(f"CDO merge failed for {g} -> {out}: {e}")
                raise


def run_hydroland(
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
    executable_mhm: str,
    executable_mrm: str,
    omp_num_threads: str,
    delete_files: bool,
    bias_adjustment: bool,
    apply_indicators: bool,
    prior_app_outpath: str,
    restart_from_prior_run: bool,
    apply_cdo_mergetime: bool,
):
    """
    Executes the full Hydroland pipeline.
    """
    # Select ini/end date parts based on run_frequency
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
    ini_tuple, end_tuple = run_frequency_mapping[run_frequency]
    ini_year, ini_month, ini_day = ini_tuple
    end_year, end_month, end_day = end_tuple

    # Build dates
    ini_dt = datetime.strptime(f"{ini_year}-{ini_month}-{ini_day}", "%Y-%m-%d")
    end_dt = datetime.strptime(f"{end_year}-{end_month}-{end_day}", "%Y-%m-%d")
    ini_date = ini_dt.strftime("%Y_%m_%d")
    end_date = end_dt.strftime("%Y_%m_%d")
    if run_frequency == "month":
        prev_month_dt = ini_dt - relativedelta(months=1)
        prev_month_start = prev_month_dt.replace(day=1)
        start_previous_date = prev_month_start.strftime("%Y_%m_%d")
        end_previous_date = (ini_dt - timedelta(days=1)).strftime("%Y_%m_%d")

        start_next_date = (end_dt + timedelta(days=1)).strftime("%Y_%m_%d")
        end_next_date = ini_dt + relativedelta(months=1)
        current_start = ini_dt.replace(day=1)

        prev_start = (current_start - relativedelta(months=1)).replace(day=1)
        prev_end = current_start - timedelta(days=1)
        next_start = (current_start + relativedelta(months=1)).replace(day=1)
        next_end = next_start + relativedelta(months=1) - timedelta(days=1)

        start_previous_date = prev_start.strftime("%Y_%m_%d")
        end_previous_date = prev_end.strftime("%Y_%m_%d")
        start_next_date = next_start.strftime("%Y_%m_%d")
        end_next_date = next_end.strftime("%Y_%m_%d")
    else:
        # daily mode
        prev_day = ini_dt - timedelta(days=1)
        next_day = end_dt + timedelta(days=1)
        start_previous_date = prev_day.strftime("%Y_%m_%d")
        end_previous_date = start_previous_date
        start_next_date = next_day.strftime("%Y_%m_%d")
        end_next_date = start_next_date

    previous_date = f"{start_previous_date}_to_{end_previous_date}"
    next_date = f"{start_next_date}_to_{end_next_date}"

    logger.info(
        f"\nExecuting Hydroland within the workflow with the following set‑up:\n"
        f"  output directory         = {app_outpath}\n"
        f"  run frequency            = {run_frequency}\n"
        f"  date range               = {ini_date} → {end_date}\n"
        f"  time‑step frequency      = {stat_freq}\n"
        f"  spatial resolution       = {grid}\n"
        f"  precipitation var        = {pre}\n"
        f"  temperature var          = {temp}\n"
        f"  bias adjustment          = {bias_adjustment}\n"
        f"  delete intermediate      = {delete_files}\n"
        f"  restart from prior run   = {restart_from_prior_run}\n"
        f"  prior hydroland outpath  = {prior_app_outpath}\n"
        f"  merge time with CDO      = {apply_cdo_mergetime}\n"
    )

    # Build out directories
    current_mhm_dir = Path(app_outpath) / "hydroland" / "mhm" / "current_run"
    mhm_log_dir = Path(app_outpath) / "hydroland" / "mhm" / "log_files"
    mhm_restart_dir = Path(app_outpath) / "hydroland" / "mhm" / "restart_files"
    mhm_fluxes_dir = Path(app_outpath) / "hydroland" / "mhm" / "fluxes"
    forcings_dir = Path(app_outpath) / "hydroland" / "forcings"
    current_mrm_dir = Path(app_outpath) / "hydroland" / "mrm" / "current_run"
    mrm_log_dir = Path(app_outpath) / "hydroland" / "mrm" / "log_files"
    mrm_restart_dir = Path(app_outpath) / "hydroland" / "mrm" / "restart_files"
    mrm_fluxes_dir = Path(app_outpath) / "hydroland" / "mrm" / "fluxes"

    # Parse grid
    if grid == "0.1/0.1":
        resolution = 0.1
    else:
        resolution = 0.05

    # running 13 threads for hourly runs at 5km
    if resolution == 0.05 and stat_freq == "hourly":
        omp_num_threads = 13

    # Output filenames
    if stat_freq == "hourly":
        mhm_out_file = f"{ini_date}_T00_00_to_{end_date}_T23_00_mHM_Fluxes_States.nc"
        mrm_out_file = f"{ini_date}_T00_00_to_{end_date}_T23_00_mRM_Fluxes_States.nc"
    else:
        mhm_out_file = f"{ini_date}_to_{end_date}_mHM_Fluxes_States.nc"
        mrm_out_file = f"{ini_date}_to_{end_date}_mRM_Fluxes_States.nc"

    # merge monthly forcings for Hydroland
    if apply_cdo_mergetime:
        opa_dir = Path(hydroland_opa)
        if run_frequency == "month" and stat_freq == "daily":
            pairs = [
                (
                    f"{ini_year_chunk}_{ini_month_chunk}_*_{pre}_timestep_60_daily_mean.nc",
                    opa_dir / f"{ini_date}_to_{end_date}_{pre}_daily_data.nc",
                ),
                (
                    f"{ini_year_chunk}_{ini_month_chunk}_*_{temp}_timestep_60_daily_mean.nc",
                    opa_dir / f"{ini_date}_to_{end_date}_{temp}_daily_data.nc",
                ),
            ]
            run_merges_in_parallel(pairs, opa_dir, run_frequency, stat_freq)

        if run_frequency == "month" and stat_freq == "hourly":
            logger.debug(
                f"Running {run_frequency=} and {stat_freq=}, applying CDO mergetime."
            )
            pairs = [
                (
                    f"{ini_year_chunk}_{ini_month_chunk}_*T00*to_{ini_year_chunk}_{ini_month_chunk}_*T23*_{pre}_raw_data.nc",
                    opa_dir
                    / f"{ini_date}_T00_00_to_{end_date}_T23_00_{pre}_hourly_data.nc",
                ),
                (
                    f"{ini_year_chunk}_{ini_month_chunk}_*T00*to_{ini_year_chunk}_{ini_month_chunk}_*T23*_{temp}_raw_data.nc",
                    opa_dir
                    / f"{ini_date}_T00_00_to_{end_date}_T23_00_{temp}_hourly_data.nc",
                ),
            ]
            run_merges_in_parallel(pairs, opa_dir, run_frequency, stat_freq)

    # initialisation
    logger.info("Setting-up configuration and init files.")
    start_initialisation(
        ini_date=ini_date,
        end_date=end_date,
        previous_date=previous_date,
        stat_freq=stat_freq,
        init_files=init_files,
        app_outpath=app_outpath,
        resolution=resolution,
        current_mhm_dir=current_mhm_dir,
        forcings_dir=forcings_dir,
        mhm_restart_dir=mhm_restart_dir,
        current_mrm_dir=current_mrm_dir,
        mrm_restart_dir=mrm_restart_dir,
        hydroland_opa=hydroland_opa,
        bias_adjustment=bias_adjustment,
        prior_app_outpath=prior_app_outpath,
        restart_from_prior_run=restart_from_prior_run,
    )

    # preprocess forcings
    logger.info("Setting-up forcing files to execute mHM & mRM.")
    preprocess_forcings(
        ini_date=ini_date,
        end_date=end_date,
        stat_freq=stat_freq,
        temp_var=temp,
        pre_var=pre,
        forcings_dir=forcings_dir,
        hydroland_opa=hydroland_opa,
        run_frequency=run_frequency,
    )

    # run mHM
    logger.info("Starting execution process for mHM.")
    execute_mhm(
        ini_date=ini_date,
        end_date=end_date,
        next_date=next_date,
        current_mhm_dir=current_mhm_dir,
        forcings_dir=forcings_dir,
        mhm_log_dir=mhm_log_dir,
        mhm_fluxes_dir=mhm_fluxes_dir,
        mhm_restart_dir=mhm_restart_dir,
        hydroland_opa=hydroland_opa,
        pre=pre,
        stat_freq=stat_freq,
        mhm_out_file=mhm_out_file,
        executable_mhm=executable_mhm,
    )

    # run mRM
    logger.info(f"Starting execution process for mRM with {omp_num_threads=}.")
    execute_mrm(
        current_mrm_dir=current_mrm_dir,
        mrm_restart_dir=mrm_restart_dir,
        mrm_log_dir=mrm_log_dir,
        ini_date=ini_date,
        end_date=end_date,
        next_date=next_date,
        stat_freq=stat_freq,
        init_files=init_files,
        forcings_dir=forcings_dir,
        mhm_fluxes_dir=mhm_fluxes_dir,
        mrm_fluxes_dir=mrm_fluxes_dir,
        mhm_out_file=mhm_out_file,
        mrm_out_file=mrm_out_file,
        hydroland_opa=hydroland_opa,
        pre=pre,
        resolution=resolution,
        executable_mrm=executable_mrm,
        omp_num_threads=omp_num_threads,
    )

    # cleanup
    logger.info("Cleaning up files and finishing Hydroland execution.")
    cleanup_files(
        ini_date=ini_date,
        forcings_dir=forcings_dir,
        mhm_restart_dir=mhm_restart_dir,
        mhm_log_dir=mhm_log_dir,
        mrm_restart_dir=mrm_restart_dir,
        mrm_log_dir=mrm_log_dir,
        hydroland_opa=hydroland_opa,
        delete_files=delete_files,
        bias_adjustment=bias_adjustment,
        apply_indicators=apply_indicators,
    )


if __name__ == "__main__":
    args = parse_args()
    run_hydroland(
        args.hydroland_opa,
        args.init_files,
        args.app_outpath,
        args.ini_year_chunk,
        args.ini_month_chunk,
        args.ini_day_chunk,
        args.end_year_chunk,
        args.end_month_chunk,
        args.end_day_chunk,
        args.ini_year_split,
        args.ini_month_split,
        args.ini_day_split,
        args.stat_freq,
        args.pre,
        args.temp,
        args.grid,
        args.run_frequency,
        args.executable_mhm,
        args.executable_mrm,
        args.omp_num_threads,
        args.delete_files,
        args.bias_adjustment,
        args.apply_indicators,
        args.prior_app_outpath,
        args.restart_from_prior_run,
        args.apply_cdo_mergetime,
    )
