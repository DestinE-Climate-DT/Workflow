#!/usr/bin/env bash
set -xuveo

HYDROLAND_DIR="$1"
INI_YEAR="$2"
INI_MONTH="$3"
END_YEAR="$4"
END_MONTH="$5"
INI_DATE="$6"
END_DATE="$7"
PREVIOUS_DATE="$8"
STAT_FREQ="$9"
INIT_FILES="${10}"
APP_OUTPATH="${11}"
RESOLUTION="${12}"
CURRENT_MHM_DIR="${13}"
FORCINGS_DIR="${14}"
MHM_RESTART_DIR="${15}"
CURRENT_MRM_DIR="${16}"
MRM_RESTART_DIR="${17}"
TEM="${18}"
PRE="${19}"
HYDROLAND_OPA="${20}"

# Always clear out previous-model outputs to avoid stale data
rm -rf "${CURRENT_MHM_DIR}"/*.nc \
    "${CURRENT_MHM_DIR}/output"/*.nc \
    "${CURRENT_MRM_DIR}"/*.nc \
    "${CURRENT_MRM_DIR}/run_parallel_mrm.sh" \
    "${CURRENT_MRM_DIR}/parallel_mrm.py" \
    "${CURRENT_MRM_DIR}"/subdomain_*

# Define paths to restart files
previous_re_file="${MHM_RESTART_DIR}/${PREVIOUS_DATE}_mHM_restart.nc"
current_re_file="${CURRENT_MHM_DIR}/input/restart/${INI_DATE}_mHM_restart.nc"

if [[ ! -e "$previous_re_file" ]]; then
    #
    # First time through (no previous restart):
    #   - clean up any half‑baked files
    #   - create directories
    #   - generate config with header.sh, mhm_nml.sh, outputs_nml.sh, parameter_nml.sh
    #   - validate/adjust STAT_FREQ
    #   - link/copying initial restart files
    #
    rm -rf "${FORCINGS_DIR}"/mHM_"${INI_DATE}"_to_"${END_DATE}"_*.nc \
        "${CURRENT_MHM_DIR}/input/restart"/*.nc

    for i in {1..53}; do
        rm -f "${CURRENT_MRM_DIR}/subdomain_${i}/${INI_DATE}_mRM_restart.nc"
    done

    mkdir -p \
        "${FORCINGS_DIR}" \
        "${APP_OUTPATH}/hydroland/mhm/log_files" \
        "${APP_OUTPATH}/hydroland/mhm/restart_files" \
        "${APP_OUTPATH}/hydroland/mhm/current_run/input/meteo" \
        "${APP_OUTPATH}/hydroland/mhm/current_run/input/restart" \
        "${APP_OUTPATH}/hydroland/mhm/current_run/output" \
        "${APP_OUTPATH}/hydroland/mhm/fluxes" \
        $(for i in {1..53}; do echo "${APP_OUTPATH}/hydroland/mrm/log_files/subdomain_${i}"; done) \
        $(for i in {1..53}; do echo "${APP_OUTPATH}/hydroland/mrm/restart_files/subdomain_${i}"; done) \
        "${APP_OUTPATH}/hydroland/mrm/current_run" \
        "${APP_OUTPATH}/hydroland/mrm/fluxes"

    bash "${HYDROLAND_DIR}/run_mhm/header.sh" "${CURRENT_MHM_DIR}/input/meteo" "${RESOLUTION}"
    bash "${HYDROLAND_DIR}/run_mhm/mhm_nml.sh" "${CURRENT_MHM_DIR}"
    bash "${HYDROLAND_DIR}/run_mhm/outputs_nml.sh" "${CURRENT_MHM_DIR}"
    bash "${HYDROLAND_DIR}/run_mhm/parameter_nml.sh" "${CURRENT_MHM_DIR}"

    case "${STAT_FREQ}" in
    daily)
        # default, nothing to do
        ;;
    hourly)
        sed -i 's/timeStep_model_outputs = -1/timeStep_model_outputs = 1/' \
            "${CURRENT_MHM_DIR}/mhm_outputs.nml"
        ;;
    *)
        echo "Invalid STAT_FREQ: ${STAT_FREQ}. Supported values: daily or hourly." >&2
        exit 1
        ;;
    esac

    # Copying initial re-start file from init folders and linking it
    cp -r "${INIT_FILES}/mhm/restart_files/mHM_restart_${RESOLUTION}.nc" \
        "${MHM_RESTART_DIR}/${INI_DATE}_mHM_restart.nc"
    # Link in the “cold‐start” restart files
    ln -srf \
        "${MHM_RESTART_DIR}/${INI_DATE}_mHM_restart.nc" \
        "${current_re_file}"

    for i in {1..53}; do
        ln -srf \
            "${INIT_FILES}/mrm/restart_files/subdomain_${i}/mRM_restart_${RESOLUTION}.nc" \
            "${MRM_RESTART_DIR}/subdomain_${i}/${INI_DATE}_mRM_restart.nc"
    done

else
    #
    # Subsequent runs: just point to the last checkpoint
    #
    ln -srf \
        "${MHM_RESTART_DIR}/${INI_DATE}_mHM_restart.nc" \
        "${current_re_file}"
fi
