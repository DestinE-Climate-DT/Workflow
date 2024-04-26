# this script is used to run the HydroMet application that gets streamed data from OPA
from HydroMet.run_kostradamus import run_kostradamus
from HydroMet import run_WetCat_object_detection as run_WetCatO
from HydroMet import run_WetCat_event_detection as run_WetCatE
import argparse
import os
import yaml


print("Trying to run HydroMet !!!!!!!!!!!!")


def run_hydromet(config_dir, iniyear, inimonth, iniday, finyear, finmonth, finday):
    config_file_dir = f"{config_dir}config_hydromet.yml"
    with open(config_file_dir) as f:
        config_data = yaml.safe_load(f)

    iams_dir = config_data.get("kostra_indir", "")
    nr_years = config_data.get("nr_years", "")
    DDF_dir = config_data.get("DDF_dir", "")
    KO_params_dir = config_data.get("KO_params_dir", "")
    rain_data_dir = config_data.get("rain_data_dir", "")

    if os.path.exists(DDF_dir) and os.path.exists(KO_params_dir):
        print("\nAll required files for cataloguing software exist")
        print(f"Depth Duration Frequency: \n{DDF_dir}")
        print(f"Kostradamus Distribution Parameter: \n{KO_params_dir } ")

        # Filename for raw data of current streaming step
        # Note: If data frequency is not hourly this requires adaptations
        file_name = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_tp_raw_data.nc"

        # Check if the file exist
        if os.path.exists(f"{rain_data_dir}{file_name}"):
            print("\nData from DestinE stream available")
            print("Initiating Cataloguing Software")
            run_WetCatO.run_WetCat_object_detection(config_file_dir, file_name)
            run_WetCatE.run_WetCat_event_detection(config_file_dir)
        else:
            print("Could not find DestinE data")

    else:
        print("\nRequired files for cataloguing software not available.")
        print("Only running KOSTRADAMUS for this Experiment")

    def check_directory(directory_path):
        files = [
            file for file in os.listdir(directory_path) if file.endswith("iams.nc")
        ]
        return len(files)

    file_count = check_directory(iams_dir)

    if file_count >= nr_years:
        print("Enough OPA statistics available! Running Kostradamus.")
        run_kostradamus(config_file_dir)
        print("\nKostradamus analysis done!\n")
    else:
        print("Waiting for OPA results.")
        print(f"Only {file_count} of {nr_years} required years have been computed yet.")


# Create an ArgumentParser object
parser = argparse.ArgumentParser(description="HydroMet Script")

# Add the positional arguments
parser.add_argument(
    "-config_dir", required=True, help="Directory to HydroMet config yaml", default=1
)
parser.add_argument(
    "-iniyear", required=True, help="Input year for the HydroMet app", default=2
)
parser.add_argument(
    "-inimonth", required=True, help="Input month for the HydroMet app", default=3
)
parser.add_argument(
    "-iniday", required=True, help="Input day for the HydroMet app", default=4
)
parser.add_argument(
    "-finyear", required=True, help="Input year for the HydroMet app", default=5
)
parser.add_argument(
    "-finmonth", required=True, help="Input month for the HydroMet app", default=6
)
parser.add_argument(
    "-finday", required=True, help="Input day for the HydroMet app", default=7
)


# Parse the command line arguments
args = parser.parse_args()

config_dir = args.config_dir
iniyear = args.iniyear
inimonth = args.inimonth
iniday = args.iniday
finyear = args.finyear
finmonth = args.finmonth
finday = args.finday

# Run the HydroMet App
run_hydromet(config_dir, iniyear, inimonth, iniday, finyear, finmonth, finday)
