#!/bin/bash

# INTERFACE

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
PRODUCTION=${14:-%RUN.PRODUCTION%}
HPC_FDB_HOME=${15:-%CURRENT_FDB_PROD%}
DATABRIDGE_FDB_HOME=${17:-%CURRENT_DATABRIDGE_FDB_HOME%}
DQC_PROFILE=${18:-%CONFIGURATION.DQC_PROFILE%}

LIBDIR="${HPCROOTDIR}/${PROJDEST}"/lib
HPC=$(echo ${CURRENT_ARCH} | cut -d- -f1)

# LOAD FDB MODULES & FDB5 CONFIG FILE
. "${LIBDIR}/${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

load_environment_gsv ${FDB_DIR} ${EXPID}

# Update FDB to latest stack
export PATH=/users/lrb_465000454_fdb/mars/versions/6.99.1.0/bin:$PATH
# export LD_LIBRARY_PATH=/users/lrb_465000454/mars/versions/current/lib64:$LD_LIBRARY_PATH

export METKIT_PARAM_RAW=1

if [ ${PRODUCTION,,} = "true" ]; then
    FDB_DIR_HEALPIX="${FDB_PROD}"
    FDB_DIR_LATLON="${FDB_PROD}/latlon"
    FDB_DIR_NATIVE="${FDB_PROD}/native"
    EXPID_FDB="0001"
    unset FDB5_CONFIG_FILE
    export FDB_HOME=${HPC_FDB_HOME}
else
    FDB_DIR_NATIVE="${FDB_DIR}/${EXPID}/fdb/NATIVE_grids"
    FDB_DIR_HEALPIX="${FDB_DIR}/${EXPID}/fdb/HEALPIX_grids"
    FDB_DIR_LATLON="${FDB_DIR}/${EXPID}/fdb/REGULARLL_grids"
    EXPID_FDB=${EXPID}
    export FDB5_CONFIG_FILE="${FDB_DIR_HEALPIX}/etc/fdb/config.yaml"
fi

profiles_path="${HPCROOTDIR}/${PROJDEST}/gsv_interface/gsv/dqc/profiles/${DQC_PROFILE}/${MODEL_NAME,,}"

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

mkdir -p ${HPCROOTDIR}/wipe_requests
cd ${HPCROOTDIR}/wipe_requests

for profile_file in "${profiles_path}"/*.yaml; do
    export FDB_HOME=${DATABRIDGE_FDB_HOME}
    python "${LIBDIR}/runscript/FDB/yaml_to_flat_request.py" --file="$profile_file" --expver="${EXPID_FDB}" --startdate="${START_DATE}" --experiment="${EXPERIMENT}" --enddate="${CHUNK_SECOND_TO_LAST_DATE}" --chunk="${CHUNK}" --model="${MODEL_NAME^^}" --activity="${ACTIVITY}" --omit-keys "time,levelist"

    FLAT_REQ_NAME="$(basename $profile_file | cut -d. -f1)_${CHUNK}_request.flat"
    FDB_LIST_OUTPUT="$(basename $profile_file | cut -d. -f1)_${CHUNK}_list.log"
    fdb-list --porcelain "$(<${FLAT_REQ_NAME})" >"${FDB_LIST_OUTPUT}"
    LISTED_MESSAGES=$(cat ${FDB_LIST_OUTPUT} | wc -l)

    EXPECTED_MESSAGES=$(python "${LIBDIR}/runscript/FDB/count_expected_messages.py" --file="$profile_file" --expver="${EXPID_FDB}" --startdate="${START_DATE}" --experiment="${EXPERIMENT}" --enddate="${CHUNK_SECOND_TO_LAST_DATE}" --chunk="${CHUNK}" --model="${MODEL_NAME^^}" --activity="${ACTIVITY}")

    if [ "$LISTED_MESSAGES" == "$EXPECTED_MESSAGES" ]; then
        echo "Number of messages MATCH ${LISTED_MESSAGES}"
    else
        echo "ERROR Number of messages DO NOT MATCH: Listed:  ${LISTED_MESSAGES}, expected: ${EXPECTED_MESSAGES}"
        exit 1
    fi

done

profile_file="${LIBDIR}/runscript/FDB/general_request.yaml"
FLAT_REQ_NAME="$(basename $profile_file | cut -d. -f1)_${CHUNK}_request.flat"

python "${LIBDIR}/runscript/FDB/yaml_to_flat_request.py" --file="${profile_file}" --expver="${EXPID_FDB}" --startdate="${START_DATE}" --experiment="${EXPERIMENT}" --enddate="${CHUNK_SECOND_TO_LAST_DATE}" --chunk="${CHUNK}" --model="${MODEL_NAME^^}" --activity="${ACTIVITY}" --omit-keys="time,levelist,param,levtype"

export FDB_HOME=${HPC_FDB_HOME}
fdb-wipe --minimum-keys class,dataset,experiment,activity,expver,model,generation,realization,type,stream,date "$(<${FLAT_REQ_NAME})"
