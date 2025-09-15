#!/scratch/project_465000454/devaraju/SW/LUMI-23.03/C/python-climatedt/bin/python
# OBSALL Apps (3 parts: SYNOP, TEMP, AMSU-A observations)

# Import required libraries
import sys
import subprocess

# --- Processing ground-based observations (SYNOP)
print("**********************************************************")
print("DestinE Climate Digital Twin - OBSALL Apps")
print("--- Processing ground-based observations (SYNOP)")
print("**********************************************************")
command_synop_run = "cd SYNOP; pwd; ./main_synop.sh; exit 0"
subprocess.run(command_synop_run, shell=True, check=True, executable="/bin/bash")

# --- Processing radiosounding observations (TEMP)
print("**********************************************************")
print("DestinE Climate Digital Twin - OBSALL Apps")
print("--- Processing radiosounding-based observations (TEMP)")
print("**********************************************************")
command_radsound_run = "cd RADSOUND; pwd; ./main_radsound.sh; exit 0"
subprocess.run(command_radsound_run, shell=True, check=True, executable="/bin/bash")

# IN IMPLEMENTATION
# --- Processing satellite observations (AMSU-A)
print("**********************************************************")
print("DestinE Climate Digital Twin - OBSALL Apps")
print("--- Processing satellite-based observations (AMSU-A)")
print("**********************************************************")
command_satellite_run = "cd SATELLITE; pwd; ./main_amsua.sh; exit 0"
subprocess.run(command_satellite_run, shell=True, check=True, executable="/bin/bash")

sys.exit(0)
