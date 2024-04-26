#!/bin/bash

# INTERFACE
set -xuve

HPC_PROJ=${1:-%CURRENT_HPC_PROJECT_DIR%}
EXPID=${2:-%DEFAULT.EXPID%}
HPCROOTDIR=${3:-%HPCROOTDIR%}
START_DATE=${4:-%SDATE%}
CURRENT_ARCH=${5:-%CURRENT_ARCH%}
PROJDEST=${6:-%PROJECT.PROJECT_DESTINATION%}
FDB_PROD=${7:-%CURRENT_FDB_PROD%}
FDB_DIR=${8:-%CURRENT_FDB_DIR%}
CHUNK=${9:-%CHUNK%}
START_DATE=${10:-%CHUNK_START_DATE%}
CHUNK_SECOND_TO_LAST_DATE=${11:-%CHUNK_SECOND_TO_LAST_DATE%}
RAPS_EXPERIMENT=${12:-%CONFIGURATION.RAPS_EXPERIMENT%}
MODEL_NAME=${13:-%MODEL.NAME%}
RUN_TYPE=${14:-%RUN.TYPE%}
HPC_FDB_HOME=${15:-%CURRENT_FDB_PROD%}
DATABRIDGE_FDB_HOME=${17:-%CURRENT_DATABRIDGE_FDB_HOME%}
DQC_PROFILE=${18:-%CONFIGURATION.DQC_PROFILE%}

LIBDIR="${HPCROOTDIR}/${PROJDEST}"/lib
HPC=$(echo ${CURRENT_ARCH} | cut -d- -f1)

# LOAD FDB MODULES & FDB5 CONFIG FILE
. "${LIBDIR}/${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

load_environment_gsv "${FDB_DIR}" "${EXPID}"

export METKIT_PARAM_RAW=1

set_data_gov ${RUN_TYPE}

if [ ${FDB_TYPE} == "LOCAL" ]; then
    echo "ERROR: This type of experiments can't transfer data to the data bridge"
    exit 1
fi

FDB_DIR_HEALPIX="${FDB_PROD}"
FDB_DIR_LATLON="${FDB_PROD}/latlon"
FDB_DIR_NATIVE="${FDB_PROD}/native"

unset FDB5_CONFIG_FILE
export FDB_HOME=${HPC_FDB_HOME}

profiles_path="${HPCROOTDIR}/${PROJDEST}/gsv_interface/gsv/dqc/profiles/${DQC_PROFILE}/${MODEL_NAME,,}"

if [ -d "$profiles_path" ]; then
    echo "Transfering profiles in $profiles_path"
else
    echo "ERROR: The path '$profiles_path' does not exist."
    exit 1
fi

# Check model being used and load DGOV keys
if [ ${MODEL_NAME} == "icon" ]; then
    # Get ICON workflow configuration
    export EXPERIMENT="%SIMULATION.DATA_GOV.EXPERIMENT%"
    export ACTIVITY="%SIMULATION.DATA_GOV.ACTIVITY%"

elif [ ${MODEL_NAME%%-*} == "ifs" ]; then
    # Get RAPS configuration
    export_MULTIO_variables "${RAPS_EXPERIMENT}"
    export EXPERIMENT="${MULTIO_EXPERIMENT}"
    export ACTIVITY="${MULTIO_ACTIVITY}"
else
    echo "Error: Incorrect model name"
    exit 1
fi

mkdir -p ${HPCROOTDIR}/transfer_requests
cd ${HPCROOTDIR}/transfer_requests

for profile_file in "${profiles_path}"/*.yaml; do
    export FDB_HOME=${HPC_FDB_HOME}

    profile_name=$(basename "$profile_file" | cut -d. -f1)

    if [ ! -f "${profile_name}_chunk_${CHUNK}_COMPLETED" ]; then

        python3 "${LIBDIR}/runscript/FDB/yaml_to_mars_retrieve.py" --file="$profile_file" --expid="${EXPVER}" --startdate="${START_DATE}" --experiment="${EXPERIMENT}" --enddate="${CHUNK_SECOND_TO_LAST_DATE}" --chunk="${CHUNK}" --model="${MODEL_NAME^^}" --activity="${ACTIVITY}"

        python3 "${LIBDIR}/runscript/FDB/yaml_to_mars_archive.py" --file="$profile_file" --expid="${EXPVER}" --startdate="${START_DATE}" --experiment="${EXPERIMENT}" --enddate="${CHUNK_SECOND_TO_LAST_DATE}" --chunk="${CHUNK}" --model="${MODEL_NAME^^}" --activity="${ACTIVITY}"

        export FDB_HOME=${DATABRIDGE_FDB_HOME}

        # Write extracted GRIB data in the DataBridge using the MARS client
        if [ -s ${profile_name}_chunk_"${CHUNK}".grb ]; then
            "${HPC_FDB_HOME}"/bin/mars ${profile_name}_chunk_"${CHUNK}".mars
            echo "ARCHIVE OF $(basename "$profile_file" | cut -d. -f1) SUCCESSFUL"
            touch "${profile_name}_chunk_${CHUNK}_COMPLETED"
        else
            echo "ERROR: ARCHIVE OF ${profile_name} NOT SUCCESSFUL"
            exit 1
        fi

        rm "${profile_name}_chunk_${CHUNK}.grb"

    fi
done
