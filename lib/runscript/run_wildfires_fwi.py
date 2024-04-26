import argparse
import os
import subprocess

import xarray as xr

# First step, create a parser:
parser = argparse.ArgumentParser(
    description="Runscript for the wildfires_fwi application"
)

# Second step, add positional arguments or
# https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
parser.add_argument(
    "-year", required=True, help="Input year for the wildfires_fwi app", default=1
)
parser.add_argument(
    "-month", required=True, help="Input month for the wildfires_fwi app", default=2
)
parser.add_argument(
    "-day", required=True, help="Input day for the wildfires_fwi app", default=3
)
parser.add_argument(
    "-hpctmpdir", required=True, help="Input expid for the wildfires_fwi app", default=4
)

# Third step, parse arguments.
# The default args list is taken from sys.args
args = parser.parse_args()

year = args.year
month = args.month
day = args.day
hpctmpdir = args.hpctmpdir

# Provide the input and output DIR path
os.environ["indir_path"] = f"{hpctmpdir}/"
os.environ["outdir_path"] = f"{hpctmpdir}/"
os.environ["ct_path"] = f"{hpctmpdir}/"

# Provide the data file name for all variables
temp_name = f"{year}_{month}_{day}_T00_00_to_{year}_{month}_{day}_T23_00_2t_raw_data.nc"  # 2m_temperature_DMIN_era5Land.nc"
pr_name = f"{year}_{month}_{day}_T13_tp_daily_noon_sum.nc"  # total_precipitation_DSUM_era5Land.nc"
uwind_name = f"{year}_{month}_{day}_T00_00_to_{year}_{month}_{day}_T23_00_10u_raw_data.nc"  # "10m_u_component_of_wind_DMIN_era5Land.nc"
vwind_name = f"{year}_{month}_{day}_T00_00_to_{year}_{month}_{day}_T23_00_10v_raw_data.nc"  # "10m_v_component_of_wind_DMIN_era5Land.nc"
d2m_name = f"{year}_{month}_{day}_T00_00_to_{year}_{month}_{day}_T23_00_2d_raw_data.nc"  # "2m_dewpoint_temperature_DMIN_era5Land.nc"
out_name = f"FWI_{year}_{month}_{day}_output.nc"
ct_name = f"FWI_Const_{year}_{month}_{day}.nc"


# indir_path1 = 'indir_path '
indir_path1 = "/scratch/project_465000454/tmp/a0in/"


# os.environ['indir_path1'] = f'{hpctmpdir}/'

# Combine data path and file names
input_names = (
    "indir_path "
    + "outdir_path "
    + " "
    + temp_name
    + " "
    + pr_name
    + " "
    + uwind_name
    + " "
    + vwind_name
    + " "
    + d2m_name
    + " "
    + out_name
    + " "
    + "ct_path "
    + ct_name
)


# Extract only 12 UTC time

file_tas = os.path.join(indir_path1 + temp_name)
print(file_tas)
ds_tas = xr.open_dataset(file_tas)
tas = ds_tas.sel(time=ds_tas["time.hour"] == 12)
# print(tas.time)
os.remove(file_tas)
tas.to_netcdf(path=os.path.join(indir_path1 + temp_name))


file_d2m = os.path.join(indir_path1 + d2m_name)
ds_d2m = xr.open_dataset(file_d2m)
d2m = ds_d2m.sel(time=ds_d2m["time.hour"] == 12)
os.remove(file_d2m)
d2m.to_netcdf(path=os.path.join(indir_path1 + d2m_name))

file_uwind = os.path.join(indir_path1 + uwind_name)
ds_uwind = xr.open_dataset(file_uwind)
uwind = ds_uwind.sel(time=ds_uwind["time.hour"] == 12)
os.remove(file_uwind)
uwind.to_netcdf(path=os.path.join(indir_path1 + uwind_name))


file_vwind = os.path.join(indir_path1 + vwind_name)
ds_vwind = xr.open_dataset(file_vwind)
vwind = ds_vwind.sel(time=ds_vwind["time.hour"] == 12)
os.remove(file_vwind)
vwind.to_netcdf(path=os.path.join(indir_path1 + vwind_name))

file_pr = os.path.join(indir_path1 + pr_name)
ds_pr = xr.open_dataset(file_pr)
# Convert nuit m to mm
ds_pr["tp"] = ds_pr["tp"] * 1000
os.remove(file_pr)
ds_pr.to_netcdf(path=os.path.join(indir_path1 + pr_name))


# Call F95 excutable and provide the dir path and data file names
subprocess.run(["/application/bin/fwi_main", "f"], text=True, input=str(input_names))

checkOutputFile = f"{hpctmpdir}/FWI_{year}_{month}_{day}_output.nc"

if os.path.exists(checkOutputFile):
    print("Output for wildfires_fwi application has been generated!")
    print("Inspect output for validity.")
else:
    print("Output for wildfires_fwi application has NOT been generated!")
