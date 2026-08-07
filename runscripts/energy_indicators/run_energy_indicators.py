#!/usr/bin/env python3

# Load libraries
import argparse
import os

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
    run_pv_potential,
    run_capacity_factor_histogram_opa,
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
    "--out_path", required=True, help="Path were to save the results to", default=8
)
parser.add_argument(
    "--mask_file", required=True, help="Mask file to be applied", default="None"
)
parser.add_argument(
    "--mp_proc",
    required=True,
    help="Number of mp processors to use in t-digest calculations",
    default="1",
)
parser.add_argument(
    "--run_type",
    required=True,
    type=str,
    choices=("11", "12", "13", "14", "2", "31", "32", "33", "34"),
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
mask_file = args.mask_file
mp_proc = args.mp_proc
run_type = args.run_type

# Set working dir in the enegry_onshore root
os.chdir(os.sys.path[1])

# Wind speed anomalies

# not ready in MN5
# run_wind_speed_anomalies(iniyear, inimonth, iniday, in_path, out_path, hpcprojdir)

# Execution logic. This script is meant to be run with an argument --run_type which selects a part of
# the application execution. Controlled by the template (TODO: Implement in a bash runscript),
# there are several processes that run in parallel at different stages.
#
# Stage 1: Capacity factor I, II, III, S (4 in parallel)
#
#   --run_type 11, 12, 13, 14
#
# Stage 2: Other statistics
#
#   --run_type 2
#
# Stage 3: Capacity factor histograms I, II, III, S
#
#   --run_type 31, 32, 33, 34

if run_type == "11":
    run_capacity_factor_i(
        iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
    )

elif run_type == "12":
    run_capacity_factor_ii(
        iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
    )

elif run_type == "13":
    run_capacity_factor_iii(
        iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
    )

elif run_type == "14":
    run_capacity_factor_s(
        iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
    )

elif run_type == "2":
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

    # pv potential

    run_pv_potential(
        iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
    )

elif run_type == "31":
    print(f"mask file: {mask_file}")
    run_capacity_factor_histogram_opa(
        iniyear,
        inimonth,
        iniday,
        finyear,
        finmonth,
        finday,
        out_path,
        out_path,
        cf_type="I",
        mask=mask_file,
        nworkers=int(mp_proc),
    )


elif run_type == "32":
    print(f"mask file: {mask_file}")
    run_capacity_factor_histogram_opa(
        iniyear,
        inimonth,
        iniday,
        finyear,
        finmonth,
        finday,
        out_path,
        out_path,
        cf_type="II",
        mask=mask_file,
        nworkers=int(mp_proc),
    )


elif run_type == "33":
    print(f"mask file: {mask_file}")
    run_capacity_factor_histogram_opa(
        iniyear,
        inimonth,
        iniday,
        finyear,
        finmonth,
        finday,
        out_path,
        out_path,
        cf_type="III",
        mask=mask_file,
        nworkers=int(mp_proc),
    )


elif run_type == "34":
    print(f"mask file: {mask_file}")
    run_capacity_factor_histogram_opa(
        iniyear,
        inimonth,
        iniday,
        finyear,
        finmonth,
        finday,
        out_path,
        out_path,
        cf_type="S",
        mask=mask_file,
        nworkers=int(mp_proc),
    )

else:
    raise ValueError("Wrong --run_type argument.")
