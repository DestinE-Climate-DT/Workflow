#!/usr/bin/env python3

# Load libraries
import argparse
import os
import multiprocessing

# Import custom functions
from energy_onshore.run_energy_onshore import (
    #    run_wind_speed_anomalies,
    run_capacity_factor_i,
    run_capacity_factor_ii,
    run_capacity_factor_iii,
    run_capacity_factor_s,
    run_cdd,
    run_hdd,
    run_high_wind_events,
    run_low_wind_events,
)

# First step, create a parser:
parser = argparse.ArgumentParser(description="Runscript for Energy Onshore app.")

# Second step, add positional arguments. THESE ARGUMENTS CHANGE DYNAMICALLY WITH THE WORKFLOW
# https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
parser.add_argument(
    "--iniyear", required=True, help="Input year for the urban app", default=1
)
parser.add_argument(
    "--inimonth", required=True, help="Input month for the urban app", default=2
)
parser.add_argument(
    "--iniday", required=True, help="Input day for the urban app", default=3
)
parser.add_argument(
    "--in_path", required=True, help="Input directory that contains OPA data", default=4
)
parser.add_argument(
    "--finyear", required=True, help="Input year for the urban app", default=5
)
parser.add_argument(
    "--finmonth", required=True, help="Input month for the urban app", default=6
)
parser.add_argument(
    "--finday", required=True, help="Input day for the urban app", default=7
)
parser.add_argument(
    "--out_path", required=True, help="PAth were to save the results to", default=8
)

# Third step, parse arguments.
# The default args list is taken from sys.args
args = parser.parse_args()

# hour = args.hour
iniyear = args.iniyear
inimonth = args.inimonth
iniday = args.iniday
in_path = args.in_path
finyear = args.finyear
finmonth = args.finmonth
finday = args.finday
out_path = args.out_path

# Set working dir in the enegry_onshore root
os.chdir(os.sys.path[1])

# Wind speed anomalies

# not ready in MN5
# run_wind_speed_anomalies(iniyear, inimonth, iniday, in_path, out_path, hpcprojdir)

# Compute CFs in parallel

# Define arguments:
args = (iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path)

process1 = multiprocessing.Process(target=run_capacity_factor_i, args=args)
process2 = multiprocessing.Process(target=run_capacity_factor_ii, args=args)
process3 = multiprocessing.Process(target=run_capacity_factor_iii, args=args)
process4 = multiprocessing.Process(target=run_capacity_factor_s, args=args)

# Start the processes
process1.start()
process2.start()
process3.start()
process4.start()

# Wait for both processes to finish
process1.join()
process2.join()
process3.join()
process4.join()

# Cooling degree days (CDD)

run_cdd(iniyear, inimonth, iniday, in_path, out_path)

# Heating degree days (HDD)

run_hdd(iniyear, inimonth, iniday, in_path, out_path)

# High wind events


run_high_wind_events(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
)

# Low wind events


run_low_wind_events(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
)
