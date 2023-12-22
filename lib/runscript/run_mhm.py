#!/scratch/project_465000454/devaraju/SW/LUMI-22.08/C/python-climatedt/bin/python
# Import required libraries
import subprocess
import argparse

# Create a parser
parser = argparse.ArgumentParser(description="Runscript for mHM/mRM job.")

# Add positional arguments or
# https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
parser.add_argument('-EXPID', required=True, help="Input expid to run mhm")
parser.add_argument('-HPCROOTDIR', required=True, help="HPC root dir extended until the EXPID")
parser.add_argument('-PROJDEST', required=True, help="Project folder")
parser.add_argument('-start_year', required=True, help="Input start year ")
parser.add_argument('-start_month', required=True, help="Input start month ")
parser.add_argument('-start_day', required=True, help="Input start day ")
parser.add_argument('-end_year', required=True, help="Input end year ")
parser.add_argument('-end_month', required=True, help="Input end month ")
parser.add_argument('-end_day', required=True, help="Input end day ")

# Parse arguments
args= parser.parse_args()

EXPID = args.EXPID
HPCROOTDIR = args.HPCROOTDIR
PROJDEST = args.PROJDEST
start_year = args.start_year
start_month = args.start_month
start_day = args.start_day
end_year = args.end_year
end_month = args.end_month
end_day = args.end_day

# preprocesing of data for mHM
command = f"cd run_mhm && source mHM_preprocessor.sh {EXPID} {start_day}"
subprocess.run(command, shell=True, executable="/bin/bash")

# estimates evapotranspiration from temperature and precipitation
command_pet = "cd run_mhm && python PET_calculator.py"
subprocess.run(command_pet, shell=True, executable="/bin/bash")

#run mHM
command_run = "cd run_mhm && source run_mhm.sh"
subprocess.run(command_run, shell=True, executable="/bin/bash")

# setting up start and end date variables
start = f"{start_year} {start_month} {start_day}"
end = f"{end_year} {end_month} {end_day}"

# postprocesing of data for mHM
command = f"cd run_mhm && source mHM_postprocessor.sh {HPCROOTDIR} {PROJDEST} {start}"
subprocess.run(command, shell=True, executable="/bin/bash")

#run mRM
#command_run = f"cd run_mrm && source run_mrm.sh {HPCROOTDIR} {PROJDEST} {start} {end}"
#subprocess.run(command_run, shell=True, executable="/bin/bash")

# postprocesing of data for mRM
#command_run = f"cd run_mrm && source mRM_postprocessor.sh {HPCROOTDIR} {PROJDEST} {start}"
#subprocess.run(command_run, shell=True, executable="/bin/bash")
