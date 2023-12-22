#!/bin/bash

set -xuve 

# passing arguments needed
HPCROOTDIR=$1
PROJDEST=$2
start_year=$3
start_month=$4
start_day=$5

# mHM dir
export MHM_DIR="$HPCROOTDIR/$PROJDEST/lib/runscript/run_mhm"

# current time-step's date
DATE="${start_year}_${start_month}_${start_day}"

# copying mHM fluxes for current time-step to final_results
cp ${MHM_DIR}/output/mHM_Fluxes_States.nc ${WORK_DIR}/final_results/mHM_Fluxes_States_${DATE}.nc

# moving re-start file for the next time step
mv ${MHM_DIR}/output/mHM_restart_001.nc ${MHM_DIR}/input/restart/

# adding extra day to current mHM_Fluxes_States.nc
shift="1day"
mv ${MHM_DIR}/output/mHM_Fluxes_States.nc ${MHM_DIR}/output/temp_1.nc
cdo copy "${MHM_DIR}/output/temp_1.nc" "${MHM_DIR}/output/temp_2.nc"
cdo -shifttime,${shift} "${MHM_DIR}/output/temp_2.nc" "${MHM_DIR}/output/temp_3.nc"
cdo -cat "${MHM_DIR}/output/temp_1.nc" "${MHM_DIR}/output/temp_3.nc" "${MHM_DIR}/output/mHM_Fluxes_States.nc"

# removing temporal files
rm ${MHM_DIR}/output/temp*
