#!/usr/bin/env python3

import argparse
import re

# First step, create a parser:
parser = argparse.ArgumentParser(description="Date to run the mhm day")

# Second step, add positional arguments or
# https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
parser.add_argument(
    "-date", required=True, help="Input date for mhm runscript", default=1
)

# Third step, parse arguments.
# The default args list is taken from sys.args
args = parser.parse_args()

# Now, you can get the arguments with:
print("-date: ", args.date)

date = args.date

# date = "20200101"


def extract_date_components(date_string):
    year = date_string[:4]
    month = date_string[4:6]
    day = date_string[6:8]
    return year, month, day


# Example usage
date_string = date
yyyy, mm, dd = extract_date_components(date_string)

print("Year:", yyyy)
print("Month:", mm)
print("Day:", dd)

file_path = "mhm.nml"


def update_simulation_parameters(file_path):
    with open(file_path, "r") as file:
        content = file.read()

    # Define the pattern for the specific line to be replaced
    patternyyyy1 = r"eval_Per\(1\)%yStart = \d+"
    patternyyyy2 = r"eval_Per\(1\)%yEnd   = \d+"

    patternmm1 = r"eval_Per\(1\)%mStart = \d+"
    patternmm2 = r"eval_Per\(1\)%mEnd   = \d+"

    patterndd1 = r"eval_Per\(1\)%dStart = \d+"
    patterndd2 = r"eval_Per\(1\)%dEnd   = \d+"

    # Replace the value after '=' with 1991
    content = re.sub(patternyyyy1, f"eval_Per(1)%yStart = {yyyy}", content)
    content = re.sub(patternyyyy2, f"eval_Per(1)%yEnd   = {yyyy}", content)

    content = re.sub(patternmm1, f"eval_Per(1)%mStart = {mm}", content)
    content = re.sub(patternmm2, f"eval_Per(1)%mEnd   = {mm}", content)

    content = re.sub(patterndd1, f"eval_Per(1)%dStart = {dd}", content)
    content = re.sub(patterndd2, f"eval_Per(1)%dEnd   = {dd}", content)

    # Write the updated content back to the file
    with open(file_path, "w") as file:
        file.write(content)


# Specify the path to your file

# Call the function to update the specific simulation parameter
update_simulation_parameters(file_path)

print(f"File '{file_path}' has been updated.")
