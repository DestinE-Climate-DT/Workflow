import subprocess
import argparse
import os
import numpy as np

# First step, create a parser:
parser = argparse.ArgumentParser(description="Runscript for the wildfires_fwi application")

# Second step, add positional arguments or
# https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
parser.add_argument('-year', required=True, help="Input year for the wildfires_fwi app", default=1)
parser.add_argument('-month', required=True, help="Input month for the wildfires_fwi app", default=2)
parser.add_argument('-day', required=True, help="Input day for the wildfires_fwi app", default=3)
parser.add_argument('-hpctmpdir', required=True, help="Input expid for the wildfires_fwi app", default=4)

# Third step, parse arguments.
# The default args list is taken from sys.args
args = parser.parse_args()

year = args.year
month = args.month
day = args.day
hpctmpdir = args.hpctmpdir

# Provide the input and output DIR path
os.environ['indir_path'] = f'{hpctmpdir}/' 
os.environ['outdir_path'] = f'{hpctmpdir}/' 
os.environ['ct_path'] = f'{hpctmpdir}/'

# Provide the data file name for all variables 
temp_name   = f'{year}_{month}_{day}_T00_00_to_{year}_{month}_{day}_T23_00_2t_raw_data.nc' #2m_temperature_DMIN_era5Land.nc"
pr_name     = f'{year}_{month}_{day}_T13_tp_daily_noon_sum.nc' #total_precipitation_DSUM_era5Land.nc"
uwind_name  = f'{year}_{month}_{day}_T00_00_to_{year}_{month}_{day}_T23_00_10u_raw_data.nc'#"10m_u_component_of_wind_DMIN_era5Land.nc"
vwind_name  = f'{year}_{month}_{day}_T00_00_to_{year}_{month}_{day}_T23_00_10v_raw_data.nc' #"10m_v_component_of_wind_DMIN_era5Land.nc"
d2m_name    = f'{year}_{month}_{day}_T00_00_to_{year}_{month}_{day}_T23_00_2d_raw_data.nc'#"2m_dewpoint_temperature_DMIN_era5Land.nc"
out_name    = f'FWI_{year}_{month}_{day}_output.nc'
ct_name     = f"FWI_Const_{year}_{month}_{day}.nc"

# Combine data path and file names
input_names = 'indir_path ' + 'outdir_path ' + ' ' + temp_name + ' ' + pr_name + ' ' + uwind_name + ' ' + vwind_name + ' ' + d2m_name  + ' ' + out_name + ' ' + 'ct_path '+ ct_name

# Call F95 excutable and provide the dir path and data file names
subprocess.run(["/application/bin/fwi_main", "f"], text=True, input=str(input_names))

checkOutputFile = f'{hpctmpdir}/FWI_{year}_{month}_{day}_output.nc'

if os.path.exists(checkOutputFile):
    print('Output for wildfires_fwi application has been generated!')
    print('Inspect output for validity.')
else:
    print('Output for wildfires_fwi application has NOT been generated!')
