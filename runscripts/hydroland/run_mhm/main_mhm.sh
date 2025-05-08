#!/bin/bash

set -xuve

# passing needed arguments
HYDROLAND_DIR=${1}
INI_DATE=${2}
END_DATE=${3}
NEXT_DATE=${4}
STAT_FREQ=${5}
TEMP=${6}
PRE=${7}
INIT_FILES=${8}
CURRENT_MHM_DIR=${9}
FORCINGS_DIR=${10}
MHM_LOG_DIR=${11}
MHM_FLUXES_DIR=${12}
MHM_RESTART_DIR=${13}
LON_NUMBER=${14}
HYDROLAND_OPA=${15}
MHM_OUT_FILE=${16}

# update mhm name list
python3 update_mhm_nml.py \
    -start_date "${INI_DATE}" \
    -end_date "${END_DATE}" \
    -next_date "${NEXT_DATE}" \
    -mhm_nml "${CURRENT_MHM_DIR}/mhm.nml"

# preprocesing of data for mHM
bash mHM_preprocessor.sh "${HYDROLAND_DIR}" "${INI_DATE}" "${END_DATE}" "${STAT_FREQ}" \
    "${TEMP}" "${PRE}" "${INIT_FILES}" "${FORCINGS_DIR}" "${LON_NUMBER}" "${HYDROLAND_OPA}"

# run mHM & postprocesing of data
bash -e run_mhm.sh "${HYDROLAND_DIR}" "${INI_DATE}" "${END_DATE}" "${NEXT_DATE}" \
    "${CURRENT_MHM_DIR}" "${FORCINGS_DIR}" "${MHM_LOG_DIR}" "${MHM_FLUXES_DIR}" \
    "${MHM_RESTART_DIR}" "${HYDROLAND_OPA}" "${PRE}" "${STAT_FREQ}" "${MHM_OUT_FILE}"
