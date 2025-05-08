#!/bin/bash

set -xuve

# Passing arguments
INI_DATE=${1}
END_DATE=${2}
NEXT_DATE=${3}
APP_OUTPATH=${4}
CURRENT_MRM_DIR=${5}
MRM_RESTART_DIR=${6}
MRM_FLUXES_DIR=${7}
MRM_OUT_FILE=${8}
HYDROLAND_DIR=${9}
HYDROLAND_OPA=${10}
PRE=${11}
STAT_FREQ=${12}

# ==============================================================================
# Merging mRM fluxes using xarray
# ==============================================================================
python3 "${HYDROLAND_DIR}/run_mrm/process_mrm_fluxes.py" \
    --current_mrm_dir "${CURRENT_MRM_DIR}" \
    --mrm_out_file "${MRM_OUT_FILE}"

# ==============================================================================
# Adding DGOV attributes & saving flux output (unchanged)
# ==============================================================================
python3 "${HYDROLAND_DIR}/run_mhm/data_preparation.py" \
    --in_dir "${HYDROLAND_OPA}" \
    --out_dir "${MRM_FLUXES_DIR}" \
    --out_file "${MRM_OUT_FILE}" \
    --var "${PRE}" \
    --add_DGOV_data "True" \
    --mRM "True" \
    --stat_freq "${STAT_FREQ}" \
    --current_ini_date "${INI_DATE}" \
    --current_end_date "${END_DATE}" \
    --in_hydroland_dir "${CURRENT_MRM_DIR}"

# ==============================================================================
# Moving files and finishing current hydroland execution
# Updating subdomains and moving log files for next time step
# ==============================================================================
for subdomain_id in {1..53}; do
    mv "${CURRENT_MRM_DIR}/subdomain_${subdomain_id}/output/mRM_restart_${NEXT_DATE}.nc" \
        "${MRM_RESTART_DIR}/subdomain_${subdomain_id}/${NEXT_DATE}_mRM_restart.nc" &
    mv "${CURRENT_MRM_DIR}/subdomain_${subdomain_id}/mrm_${INI_DATE}_to_${END_DATE}.log" \
        "${APP_OUTPATH}/hydroland/mrm/log_files/subdomain_${subdomain_id}/" &
done
wait
