#!/bin/bash

# Utils functions for fix_constant_variables.sh

#####################################################
# Function to fix first day missing in constant variables
# Globals:
#   HPCROOTDIR
#   SCRIPTDIR
# Arguments:
#   LIBDIR
#   DQC_PROFILE_PATH
#   EXPVER
#   EXPERIMENT
#   ACTIVITY
#   MODEL_NAME
#   FIRST_DATE
#   LAST_DATE
#   CHUNK
#   FDB_HOME
#   GENERATION
#####################################################
function fix_constant_variables() {
    LIBDIR=$1
    DQC_PROFILE_PATH=$2
    EXPVER=$3
    EXPERIMENT=$4
    ACTIVITY=$5
    MODEL_NAME=$6
    FIRST_DATE=$7
    LAST_DATE=$8
    CHUNK=$9
    FDB_HOME=${10}
    REALIZATION=${11:-1}
    GENERATION=${12:-1}
    SIM_START_DATE=${13}

    cd "${HPCROOTDIR}"
    export FDB_HOME="${FDB_HOME}"

    if [ ! -f flag_constant_variables_fixed_${SIM_START_DATE}_${REALIZATION} ]; then
        for PROFILE in ${DQC_PROFILE_PATH}/sfc_daily_*.yaml; do
            if [ -f "${PROFILE}" ]; then
                echo "Fixing missing first date in profile ${PROFILE}"

                # Name of resulting GRIB file
                GRIB_FILE_NAME="$(basename "${PROFILE}" ".yaml")_sdate_${SIM_START_DATE}_chunk_${CHUNK}_real_${REALIZATION}.grb"

                # Retrieve GRIB file from a profile YAML file
                python3 "${SCRIPTDIR}/FDB/yaml_to_mars_retrieve.py" --file="${PROFILE}" \
                    --expid="${EXPVER}" --experiment="${EXPERIMENT,,}" --activity="${ACTIVITY,,}" \
                    --model="${MODEL_NAME,,}" --realization="${REALIZATION}" \
                    --startdate="${LAST_DATE}" --enddate="${LAST_DATE}" --generation="${GENERATION}" \
                    --chunk="${CHUNK}" --grib_file_name="${GRIB_FILE_NAME}"

                # Set date of first date of CHUNK
                FIXED_GRIB_FILE_NAME=fixed_${SIM_START_DATE}_${REALIZATION}.grb
                grib_set -s date="${FIRST_DATE}" "${GRIB_FILE_NAME}" "${FIXED_GRIB_FILE_NAME}"

                # Write date-fixed file in FDB
                fdb-write ${FIXED_GRIB_FILE_NAME}

                # Remove tempfiles
                rm "${GRIB_FILE_NAME}" ${FIXED_GRIB_FILE_NAME}
            fi
        done
        # Create a flag to indicate that the constant variables have been fixed
        touch flag_constant_variables_fixed_${SIM_START_DATE}_${REALIZATION}
        echo "Constant variables fixed for start date ${SIM_START_DATE}, realization ${REALIZATION}."

    fi
}
