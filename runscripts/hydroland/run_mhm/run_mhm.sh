#!/bin/bash

set -xuve

# passing arguments needed
HYDROLAND_DIR=${1}
INI_DATE=${2}
END_DATE=${3}
NEXT_DATE=${4}
CURRENT_MHM_DIR=${5}
FORCINGS_DIR=${6}
MHM_LOG_DIR=${7}
MHM_FLUXES_DIR=${8}
MHM_RESTART_DIR=${9}
HYDROLAND_OPA=${10}
PRE=${11}
STAT_FREQ=${12}
MHM_OUT_FILE=${13}

export OMP_NUM_THREADS=640

# linking input forcings
ln -fs ${FORCINGS_DIR}/mHM_${INI_DATE}_to_${END_DATE}_pre.nc ${CURRENT_MHM_DIR}/input/meteo/pre.nc
ln -fs ${FORCINGS_DIR}/mHM_${INI_DATE}_to_${END_DATE}_tavg.nc ${CURRENT_MHM_DIR}/input/meteo/tavg.nc
ln -fs ${FORCINGS_DIR}/mHM_${INI_DATE}_to_${END_DATE}_pet.nc ${CURRENT_MHM_DIR}/input/meteo/pet.nc

# run mHM
mhm ${CURRENT_MHM_DIR} >"${MHM_LOG_DIR}/mhm_${INI_DATE}_to_${END_DATE}.log"

# moving current restart file to restart folder for next time step
mv ${CURRENT_MHM_DIR}/output/${NEXT_DATE}_mHM_restart.nc "${MHM_RESTART_DIR}/${NEXT_DATE}_mHM_restart.nc"

# linking re-start file to execute next time step
ln -fs ${MHM_RESTART_DIR}/${NEXT_DATE}_mHM_restart.nc ${CURRENT_MHM_DIR}/input/restart/${NEXT_DATE}_mHM_restart.nc

# saving mHM fluxes for current time-step to hydroland & adding DGOV attrs
python3 data_preparation.py \
    --in_dir "${HYDROLAND_OPA}" \
    --out_dir "${MHM_FLUXES_DIR}" \
    --out_file "${MHM_OUT_FILE}" \
    --var "${PRE}" \
    --add_DGOV_data "True" \
    --current_ini_date "${INI_DATE}" \
    --current_end_date "${END_DATE}" \
    --in_hydroland_dir "${CURRENT_MHM_DIR}/output"
