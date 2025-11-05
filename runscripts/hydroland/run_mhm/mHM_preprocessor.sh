#!/bin/bash

set -xuve

# passing needed arguments
HYDROLAND_DIR=${1}
INI_DATE=${2}
END_DATE=${3}
STAT_FREQ=${4}
temp_var=${5}
pre_var=${6}
INIT_FILES=${7}
FORCINGS_DIR=${8}
LON_NUMBER=${9}
HYDROLAND_OPA=${10}

# ======================================== READ INPUT DATA ===============================================
# select hourly or daily data for current run
if [ "${STAT_FREQ}" == "hourly" ]; then
    pre_file=$(find "$HYDROLAND_OPA" -maxdepth 1 -type f -name ${INI_DATE}_T00*to_${END_DATE}_T23*${pre_var}_*.nc | head -n 1)
    tavg_file=$(find "$HYDROLAND_OPA" -maxdepth 1 -type f -name ${INI_DATE}_T00*to_${END_DATE}_T23*${temp_var}_*.nc | head -n 1)
elif [ "${STAT_FREQ}" == "daily" ]; then
    pre_file=$(find "$HYDROLAND_OPA" -maxdepth 1 -type f -name ${INI_DATE}_${pre_var}_timestep_60_daily_*.nc | head -n 1)
    tavg_file=$(find "$HYDROLAND_OPA" -maxdepth 1 -type f -name ${INI_DATE}_${temp_var}_timestep_60_daily_*.nc | head -n 1)
else
    echo "Error: No forcings files matching hydroland criteria found at '${HYDROLAND_OPA}'."
    exit 1
fi
# Remove './' from the beginning of the filename
pre_file=${pre_file#./}
tavg_file=${tavg_file#./}
# ======================================================================================================

# ======================================= PREPARE DATA TO RUN mHM ======================================
# Data preparation for tavg
out_tavg_file="mHM_${INI_DATE}_to_${END_DATE}_tavg.nc"
python3 data_preparation.py \
    --in_dir "${HYDROLAND_OPA}" \
    --in_file "${tavg_file}" \
    --out_dir "${FORCINGS_DIR}" \
    --out_file "${out_tavg_file}" \
    --var "${temp_var}" \
    --stat_freq "${STAT_FREQ}" &
# Data preparation for pre
out_pre_file="mHM_${INI_DATE}_to_${END_DATE}_pre.nc"
python3 data_preparation.py \
    --in_dir "${HYDROLAND_OPA}" \
    --in_file "${pre_file}" \
    --out_dir "${FORCINGS_DIR}" \
    --out_file "${out_pre_file}" \
    --var "${pre_var}" \
    --stat_freq "${STAT_FREQ}" &
wait
# ======================================================================================================

# ========================================= ESTIMATE PET ===============================================
# estimates & saves evaporation from temperature according to Oudin (2005)
out_pet_file="mHM_${INI_DATE}_to_${END_DATE}_pet.nc"
python3 PET_calculator.py \
    --ini_date "${INI_DATE}" \
    --end_date "${END_DATE}" \
    --stat_freq "${STAT_FREQ}" \
    --in_dir "${FORCINGS_DIR}" \
    --out_dir "${FORCINGS_DIR}" \
    --in_file "${out_tavg_file}" \
    --out_file "${out_pet_file}" \
    --lon_number "${LON_NUMBER}"
# ======================================================================================================
