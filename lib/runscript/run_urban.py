#!/usr/bin/env python3

# Load libraries
import argparse
import os
from datetime import datetime as dt

import xarray as xr

from urban_heat.core import convert_temperature
from urban_heat import tropical_nights


def run_tropical_nights(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path):

    from urban_heat.core import convert_temperature
    from urban_heat import tropical_nights
    
    # Provide the data file name for all variables 
    #t_file = f'{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_2t_daily_min.nc'
    t_file = f'{iniyear}_{inimonth}_{iniday}_2t_daily_min.nc'

    absolute_path = os.path.join(in_path, t_file)

    data = xr.open_dataset(absolute_path)

    #Import processing script.

    data = data['2t']
    tn = convert_temperature(data,unit='C')

    tr = tropical_nights(tn,threshold=20.0)

    output_file_path = os.path.join(out_path, f"test_tropic_{tn['time'].values[0]}.nc")

    tr.to_netcdf(path=output_file_path, mode='w')

    print('The test has been completed.')

    return



# First step, create a parser:
parser = argparse.ArgumentParser(description="Runscript for Urban app.")

# Second step, add positional arguments. THESE ARGUMENTS CHANGE DYNAMICALLY WITH THE WORKFLOW
# https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
parser.add_argument('-iniyear', required=True, help="Input year for the urban app", default=1)
parser.add_argument('-inimonth', required=True, help="Input month for the urban app", default=2)
parser.add_argument('-iniday', required=True, help="Input day for the urban app", default=3)
parser.add_argument('-hpcrootdir', required=True, help="ROOT directory of the experiment", default=4)
parser.add_argument('-finyear', required=True, help="Input year for the urban app", default=5)
parser.add_argument('-finmonth', required=True, help="Input month for the urban app", default=6)
parser.add_argument('-finday', required=True, help="Input day for the urban app", default=7)

# Third step, parse arguments.
# The default args list is taken from sys.args
args = parser.parse_args()

#hour = args.hour
iniyear = args.iniyear
inimonth = args.inimonth
iniday = args.iniday
hpcrootdir = args.hpcrootdir
finyear = args.finyear
finmonth = args.finmonth
finday = args.finday
# Provide the input and output DIR path
in_path = f'{hpcrootdir}'
out_path = f'{hpcrootdir}' #TODO: outpath to be determined by pillar 3

run_tropical_nights(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path)


