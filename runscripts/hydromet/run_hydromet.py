import argparse
import os
import yaml
import shutil
import glob
from datetime import datetime
from HydroMet.run_kostradamus import run_kostradamus
from HydroMet import run_WetCat_object_detection as run_WetCatO
from HydroMet import run_WetCat_event_detection as run_WetCatE


# Create an ArgumentParser object
parser = argparse.ArgumentParser(description="HydroMet Script")

# Add the positional arguments
parser.add_argument("config_dir", help="Directory to HydroMet config yaml")
parser.add_argument(
    "iniyear", nargs="?", type=str, help="Input year for the HydroMet app", default=None
)
parser.add_argument(
    "inimonth",
    nargs="?",
    type=str,
    help="Input month for the HydroMet app",
    default=None,
)
parser.add_argument(
    "iniday", nargs="?", type=str, help="Input day for the HydroMet app", default=None
)
parser.add_argument(
    "finyear", nargs="?", type=str, help="Input year for the HydroMet app", default=None
)
parser.add_argument(
    "finmonth",
    nargs="?",
    type=str,
    help="Input month for the HydroMet app",
    default=None,
)
parser.add_argument(
    "finday", nargs="?", type=str, help="Input day for the HydroMet app", default=None
)

# Parse the command line arguments
args = parser.parse_args()

print("Runing HydroMet")


def check_directory(directory_path, ending):
    """
    Check the directory for a specific type of files.

    Parameters
    ----------
    directory_path : str
        Directory to check for iams-files.

    ending : str
        Ending of the files to check for.

    Returns
    ----------
    int
        The number of files.
    list
        List of the files

    """

    files = [file for file in os.listdir(directory_path) if file.endswith(ending)]
    return len(files), files


def process_netcdf_files(
    iniyear,
    inimonth,
    iniday,
    finyear,
    finmonth,
    finday,
    directory,
    config_dir,
    WetCat_out,
):
    """
    Process NetCDF files between two dates.

    Parameters
    ----------
    iniyear : str
        Start year of streaming step.
    inimonth : str
        Start month of streaming step.
    iniday : str
        Start day of streaming step.
    finyear : str
        End year of streaming step.
    finmonth : str
        End month of streaming step.
    finday : str
        End day of streaming step.
    directory : str
        Rain data directory.
    config_dir : str
        path to configuration yaml.
    WetCat_out : str
        Path to WetCat:out.

    Returns
    ----------
    None

    """
    start_date = iniyear + inimonth + iniday
    end_date = finyear + finmonth + finday

    # Convert dates to datetime objects
    start = datetime.strptime(start_date, "%Y%m%d")
    end = datetime.strptime(end_date, "%Y%m%d")

    # List all files in the directory
    files = [f for f in os.listdir(directory) if f.endswith(".nc")]

    # Filter files by date range
    for file in files:
        # Extract date from filename
        try:
            file_date = datetime.strptime(file.split("_T00")[0], "%Y_%m_%d")
        except ValueError:
            print(f"Skipping file with invalid date format: {file}")
            continue

        # Check if file is within the date range
        if start <= file_date <= end:
            filepath = os.path.join(directory, file)
            # process the file
            run_WetCatO.run_WetCat_object_detection(config_dir, filepath)

    run_WetCatE.run_WetCat_event_detection(config_dir)
    object_count, files = check_directory(WetCat_out + "/objects", ".csv")
    if os.path.isdir(directory + "processed_output/"):
        for i in files:
            shutil.move(
                WetCat_out + "/objects/" + i,
                directory + "processed_output/" + i,
            )


def run_hydromet(
    config_dir,
    iniyear=None,
    inimonth=None,
    iniday=None,
    finyear=None,
    finmonth=None,
    finday=None,
):
    """
    Run the HydroMet application.

    Parameters
    ----------
    config_dir : str
        Directory path to the HydroMet config YAML file.
    iniyear : int, optional
        Initial year for the HydroMet app, by default None.
    inimonth : int, optional
        Initial month for the HydroMet app, by default None.
    iniday : int, optional
        Initial day for the HydroMet app, by default None.
    finyear : int, optional
        Final year for the HydroMet app, by default None.
    finmonth : int, optional
        Final month for the HydroMet app, by default None.
    finday : int, optional
        Final day for the HydroMet app, by default None.
    """

    # Load config file
    with open(config_dir) as f:
        config_data = yaml.safe_load(f)

    # Extract necessary config parameters
    iams_dir = config_data.get("kostra_indir", "")
    nr_years = config_data.get("nr_years", "")
    DDF_dir = config_data.get("DDF_dir", "")
    KO_params_dir = config_data.get("KO_params_dir", "")
    rain_data_dir = config_data.get("rain_data_dir", "")
    WetCat_out = config_data.get("catalogue_dir", "")

    # Check if necessary files exist
    if KO_params_dir and DDF_dir:
        if not os.path.exists(DDF_dir) or not os.path.exists(KO_params_dir):
            print("\nRequired files for cataloguing software not available.")
            print("Running KOSTRADAMUS")

            # Check if enough OPA statistics are available to run Kostradamus
            file_count, files = check_directory(iams_dir, "iams.nc")

            if file_count >= nr_years:
                print("Enough OPA statistics available! Running Kostradamus.")
                run_kostradamus(config_dir)
                print("\nKostradamus analysis done!\n")
            else:
                print("Waiting for OPA results.")
                print(
                    f"Only {file_count} of {nr_years} required years "
                    f"have been computed yet."
                )

        if os.path.exists(DDF_dir) and os.path.exists(KO_params_dir):
            print("\nAll required files for cataloguing software exist")
            print(f"Depth Duration Frequency: \n{DDF_dir}")
            print(f"Kostradamus Distribution Parameter: \n{KO_params_dir} ")

            # Check if the file exists for the current step
            if iniyear and inimonth and iniday:
                if iniday == finday:
                    file_pattern = (
                        f"{iniyear}_{inimonth}_{iniday}*{finyear}_"
                        f"{finmonth}_{finday}*.nc"
                    )
                    match = glob.glob(os.path.join(rain_data_dir, file_pattern))
                    if match:
                        print("\nData from DestinE stream available")
                        print("Initiating Cataloguing Software")
                        run_WetCatO.run_WetCat_object_detection(
                            config_dir, file_pattern
                        )
                        run_WetCatE.run_WetCat_event_detection(config_dir)
                        object_count, files = check_directory(
                            WetCat_out + "/objects", ".csv"
                        )
                        if (
                            os.path.isdir(rain_data_dir + "processed_output/")
                            and object_count > 11
                        ):
                            files = sorted(files)
                            for i in files[:-1]:
                                shutil.move(
                                    WetCat_out + "/objects/" + i,
                                    rain_data_dir + "processed_output/" + i,
                                )
                    else:
                        print("Could not find DestinE data")
                else:
                    process_netcdf_files(
                        iniyear,
                        inimonth,
                        iniday,
                        finyear,
                        finmonth,
                        finday,
                        rain_data_dir,
                        config_dir,
                        WetCat_out,
                    )

            else:
                print(f"\nProcessing directory: {rain_data_dir}")
                run_WetCatO.run_WetCat_object_detection(config_dir)
                raw_count, files = check_directory(rain_data_dir, "data.nc")
                run_WetCatE.run_WetCat_event_detection(config_dir)
                object_count, files = check_directory(
                    rain_data_dir + "WetCat_out/objects", ".csv"
                )
                if (
                    os.path.isdir(rain_data_dir + "processed_output/")
                    and object_count > 11
                ):
                    for i in files:
                        shutil.move(
                            rain_data_dir + "WetCat_out/objects/" + i,
                            rain_data_dir + "processed_output/" + i,
                        )

    # Check again if enough OPA statistics are
    # available to get new KOSTRADAMUS file
    file_count, files = check_directory(iams_dir, "iams.nc")
    if file_count >= nr_years:
        print("Enough OPA statistics available! Running Kostradamus.")
        run_kostradamus(config_dir)
        print("\nKostradamus analysis done!\n")


# Run the HydroMet App
run_hydromet(
    args.config_dir,
    args.iniyear,
    args.inimonth,
    args.iniday,
    args.finyear,
    args.finmonth,
    args.finday,
)
