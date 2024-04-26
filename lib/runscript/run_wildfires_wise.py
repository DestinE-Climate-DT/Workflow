# import modules
import argparse
import os
import subprocess


print("running run_wildfires.py")


# parser etc. to be added in application integration

# creating the parser
parser = argparse.ArgumentParser(description="Runscript for data notifier job.")

# adding year, month, day and experiment id arguments
parser.add_argument("-year_start", required=True, help="Input year start", default=1)
parser.add_argument("-month_start", required=True, help="Input month start", default=2)
parser.add_argument("-day_start", required=True, help="Input day start", default=3)

parser.add_argument("-year_end", required=True, help="Input year end", default=4)
parser.add_argument("-month_end", required=True, help="Input month end", default=5)
parser.add_argument("-day_end", required=True, help="Input day end", default=6)

parser.add_argument("-expid", required=True, help="experiment id", default=7)

# parsing the arguments
args = parser.parse_args()
year_start = str(args.year_start)
month_start = str(args.month_start)
day_start = str(args.day_start)
year_end = str(args.year_end)
month_end = str(args.month_end)
day_end = str(args.day_end)
expid = str(args.expid)
# placeholder values for manual runs
# year_start = "2021"
# year_end = "2021"
# month_start = "06"
# month_end = "06"
# day_start = "24"
# day_end = "30"

# create .txt file with start and end dates
all_dates = [year_start, year_end, month_start, month_end, day_start, day_end]

file_name = "/projappl/project_465000454/kolstela/wise_lumi_container/wise_lumi_files/run_dates.txt"
with open(file_name, "w") as file:
    for element in all_dates:
        file.write(element + "\n")

# current working dir
current_directory = os.getcwd()

# get the group id
directory_stat = os.stat(current_directory)

# get group ownership
group_owner_gid = directory_stat.st_gid

parent_directory = os.path.dirname(file_name)
parent_gid = os.stat(parent_directory).st_gid

# change group ownership
os.chown(file_name, -1, parent_gid)

print("Data written to 'formatted_data.txt'")

# build the command for running the singularity container wise.sif
cmd = [
    "singularity",
    "run",
    "--bind",
    "/projappl/project_465000454/kolstela/wise_lumi_container/wise_lumi_files:/testjobs",
    "--bind",
    "/scratch/project_465000454/kolstela/wise_outputs:/testjobs/testjobs/area1/Outputs",
    "--bind",
    "/scratch/project_465000454/kolstela/wise_outputs:/testjobs/testjobs/area2/Outputs",
    "--bind",
    "/scratch/project_465000454/kolstela/wise_outputs:/testjobs/testjobs/area3/Outputs",
    "--bind",
    "/scratch/project_465000454/kolstela/" + expid + "/tmp/:/input_data",
    "/projappl/project_465000454/kolstela/wise_lumi_container/wise.sif",
]

# run the container wise.sif
print("launching WISE runs")
subprocess.run(cmd)
