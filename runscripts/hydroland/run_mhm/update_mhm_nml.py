#!/usr/bin/env python3

import argparse
import re


def update_mhm_nml(
    mhm_nml, start_yyyy, start_mm, start_dd, end_yyyy, end_mm, end_dd, next_date
):
    start_date = f"{start_yyyy}_{start_mm}_{start_dd}"
    with open(mhm_nml, "r") as file:
        content = file.read()

    # Define the pattern for the specific line to be replaced
    patternyyyy1 = r"eval_Per\(1\)%yStart = \d+"
    patternyyyy2 = r"eval_Per\(1\)%yEnd   = \d+"

    patternmm1 = r"eval_Per\(1\)%mStart = \d+"
    patternmm2 = r"eval_Per\(1\)%mEnd   = \d+"

    patterndd1 = r"eval_Per\(1\)%dStart = \d+"
    patterndd2 = r"eval_Per\(1\)%dEnd   = \d+"

    # Replace the value after '=' with the corresponding date component
    content = re.sub(patternyyyy1, f"eval_Per(1)%yStart = {start_yyyy}", content)
    content = re.sub(patternyyyy2, f"eval_Per(1)%yEnd   = {end_yyyy}", content)

    content = re.sub(patternmm1, f"eval_Per(1)%mStart = {start_mm}", content)
    content = re.sub(patternmm2, f"eval_Per(1)%mEnd   = {end_mm}", content)

    content = re.sub(patterndd1, f"eval_Per(1)%dStart = {start_dd}", content)
    content = re.sub(patterndd2, f"eval_Per(1)%dEnd   = {end_dd}", content)

    # Modify input and output mHM restart file patterns
    input_mHM_restart = r'mhm_file_RestartIn\(1\)\s+=\s+".*"'
    output_mHM_restart = r'mhm_file_RestartOut\(1\)\s+=\s+".*"'

    content = re.sub(
        input_mHM_restart,
        f'mhm_file_RestartIn(1)     = "input/restart/{start_date}_mHM_restart.nc"',
        content,
    )
    content = re.sub(
        output_mHM_restart,
        f'mhm_file_RestartOut(1)    = "output/{next_date}_mHM_restart.nc"',
        content,
    )

    # Write the updated content to the new file in the specified folder
    with open(mhm_nml, "w") as file:
        file.write(content)


def extract_date_components(date):
    year, month, day = date.split("_")
    return year, month, day


# create a parser:
parser = argparse.ArgumentParser(
    description="script to modify mHM nml set-up before execution for a current time-step"
)

# add positional arguments
parser.add_argument(
    "-start_date",
    required=True,
    help="start date of the current mhm run in format YYYY_MM_DD",
)
parser.add_argument(
    "-end_date",
    required=True,
    help="end date of the current mhm run in format YYYY_MM_DD",
)
parser.add_argument(
    "-next_date",
    required=True,
    help="date after end day of current mHM run in format YYYY_MM_DD",
)
parser.add_argument("-mhm_nml", required=True, help="path to the mhm.nml file")

# parse arguments.
args = parser.parse_args()
start_date = args.start_date
end_date = args.end_date
next_date = args.next_date
mhm_nml = args.mhm_nml

# separating date in 3 var. YYYY MM DD
start_yyyy, start_mm, start_dd = extract_date_components(start_date)
end_yyyy, end_mm, end_dd = extract_date_components(end_date)

# Call the function to update the specific mHM simulation parameters
update_mhm_nml(
    mhm_nml, start_yyyy, start_mm, start_dd, end_yyyy, end_mm, end_dd, next_date
)
