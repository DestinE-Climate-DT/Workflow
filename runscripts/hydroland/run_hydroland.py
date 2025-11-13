#!/usr/bin/env python3
import argparse
import logging
from datetime import datetime, timedelta
from pathlib import Path

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

    # Date range
    parser.add_argument("--ini-year", help="Initialization year (YYYY)")
    parser.add_argument("--ini-month", help="Initialization month (MM)")
    parser.add_argument("--ini-day", help="Initialization day (DD)")
    parser.add_argument("--end-year", help="End year (YYYY)")
    parser.add_argument("--end-month", help="End month (MM)")
    parser.add_argument("--end-day", help="End day (DD)")

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
        "--splitsizeunit",
        choices=["day"],
        default="day",
        help="Split-unit for parallel runs (only 'day' supported)",
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

    args = parser.parse_args(argv)

    return args


def run_hydroland(
    hydroland_opa: str,
    init_files: str,
    app_outpath: str,
    ini_year: str,
    ini_month: str,
    ini_day: str,
    end_year: str,
    end_month: str,
    end_day: str,
    stat_freq: str,
    pre: str,
    temp: str,
    grid: str,
    splitsizeunit: str,
    executable_mhm: str,
    executable_mrm: str,
    omp_num_threads: str,
    delete_files: bool,
    bias_adjustment: bool,
    apply_indicators: bool,
    prior_app_outpath: str,
    restart_from_prior_run: bool,
):
    """
    Executes the full Hydroland pipeline.
    """
    # HydroLand runs only in daily splits
    if splitsizeunit != "day":
        msg = f"Error: Invalid SPLITSIZEUNIT '{splitsizeunit}'. Only 'day' supported.'"
        logger.error(msg)
        raise ValueError(msg)

    # Build dates
    # ini_dt == end_dt, a bit redundant, but the workflow will run only day by day
    ini_dt = datetime.strptime(f"{ini_year}-{ini_month}-{ini_day}", "%Y-%m-%d")
    end_dt = datetime.strptime(f"{ini_year}-{ini_month}-{ini_day}", "%Y-%m-%d")
    ini_date = ini_dt.strftime("%Y_%m_%d")
    end_date = end_dt.strftime("%Y_%m_%d")
    previous_date = (ini_dt - timedelta(days=1)).strftime("%Y_%m_%d")
    next_date = (end_dt + timedelta(days=1)).strftime("%Y_%m_%d")
    logger.info(
        f"\nExecuting Hydroland within the workflow with the following set‑up:\n"
        f"  output directory         = {app_outpath}\n"
        f"  splitsizeunit            = {splitsizeunit}\n"
        f"  date range               = {ini_date} → {end_date}\n"
        f"  time‑step frequency      = {stat_freq}\n"
        f"  spatial resolution       = {grid}\n"
        f"  precipitation var        = {pre}\n"
        f"  temperature var          = {temp}\n"
        f"  bias adjustment          = {bias_adjustment}\n"
        f"  delete intermediate      = {delete_files}\n"
        f"  restart from prior run   = {restart_from_prior_run}\n"
        f"  prior hdyroland outpath  = {prior_app_outpath}"
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
        lon_number = 3600
    else:
        resolution = 0.05
        lon_number = 7200

    # Output filenames
    if stat_freq == "hourly":
        mhm_out_file = f"{ini_date}_T00_00_to_{end_date}_T23_00_mHM_Fluxes_States.nc"
        mrm_out_file = f"{ini_date}_T00_00_to_{end_date}_T23_00_mRM_Fluxes_States.nc"
    else:
        mhm_out_file = f"{ini_date}_mHM_Fluxes_States.nc"
        mrm_out_file = f"{ini_date}_mRM_Fluxes_States.nc"

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
        lon_number=lon_number,
        hydroland_opa=hydroland_opa,
    )

    # run mHM
    logger.info("Executing mHM.")
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

    # run mRM (only if resolution is 0.1)
    if resolution == 0.1:
        logger.info("Executing mRM.")
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
        args.ini_year,
        args.ini_month,
        args.ini_day,
        args.end_year,
        args.end_month,
        args.end_day,
        args.stat_freq,
        args.pre,
        args.temp,
        args.grid,
        args.splitsizeunit,
        args.executable_mhm,
        args.executable_mrm,
        args.omp_num_threads,
        args.delete_files,
        args.bias_adjustment,
        args.apply_indicators,
        args.prior_app_outpath,
        args.restart_from_prior_run,
    )
