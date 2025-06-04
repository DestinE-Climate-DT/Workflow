#!/bin/bash
# Deletion part of the wipe

# INTERFACE

# HEADER

CURRENT_ROOTDIR=${1:-%CURRENT_ROOTDIR%}
CURRENT_ARCH=${2:-%CURRENT_ARCH%}
CHUNK=${3:-%CHUNK%}
START_DATE=${4:-%CHUNK_START_DATE%}
SECOND_TO_LAST_DATE=${5:-%CHUNK_SECOND_TO_LAST_DATE%}
MODEL_NAME=${6:-%MODEL.NAME%}
DATABRIDGE_FDB_HOME=${7:-%CURRENT_DATABRIDGE_FDB_HOME%}
EXPERIMENT=${8:-%REQUEST.EXPERIMENT%}
ACTIVITY=${9:-%REQUEST.ACTIVITY%}
GENERATION=${10:-%REQUEST.GENERATION%}
DQC_PROFILE_PATH=${11:-%CONFIGURATION.DQC_PROFILE_PATH%}
EXPVER=${12:-%REQUEST.EXPVER%}
FDB_HOME=${13:-%REQUEST.FDB_HOME%}
SCRATCH_DIR=${14:-%CURRENT_SCRATCH_DIR%}
HPC_CONTAINER_DIR=${15:-%CONFIGURATION.CONTAINER_DIR%}
GSV_VERSION=${16:-%GSV.VERSION%}
LIBDIR=${17:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${18:-%CONFIGURATION.SCRIPTDIR%}
WIPE_DOIT=${19:-%WIPE_DOIT%}
MEMBER=${20:-%MEMBER%}
MEMBER_LIST=${21:-%EXPERIMENT.MEMBERS%}
FDB_INFO_FILE_PATH=${22:-%REQUEST.INFO_FILE_PATH%}
FDB_INFO_FILE_NAME=${23:-%REQUEST.INFO_FILE_NAME%}
BASE_VERSION=${24:-%BASE.VERSION%}
SPLIT_END_DATE=${25:-%SPLIT_END_DATE%}
# Extra bindings needed for the container in hpc-fdb
OPERATIONAL_PROJECT_SCRATCH=${26:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${27:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}

# END_HEADER

set -xuve

HPC=$(echo ${CURRENT_ARCH} | cut -d- -f1)
ls -a ${LIBDIR}

# LOAD FDB MODULES & FDB5 CONFIG FILE
. "${LIBDIR}/${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

WIPE_REQUESTS_PATH=${CURRENT_ROOTDIR}/wipe_requests
mkdir -p ${WIPE_REQUESTS_PATH}
cd ${WIPE_REQUESTS_PATH}

# Call the function and assign the result to TRANSFER_MONTHLY
# lib/common/util.sh (enable_process_monthly) (auto generated comment)
WIPE_MONTHLY=$(enable_process_monthly "$START_DATE" "$SPLIT_END_DATE")

# lib/common/util.sh (get_member_number) (auto generated comment)
REALIZATION=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

export METKIT_PARAM_RAW=1

GENERAL_REQUEST_CLTE="${SCRIPTDIR}/FDB/general_request_clte.yaml"
GENERAL_REQUEST_CLMN="${SCRIPTDIR}/FDB/general_request_clmn.yaml"
FLAT_REQ_NAME_CLTE="$(basename ${GENERAL_REQUEST_CLTE} | cut -d. -f1)_${CHUNK}_request.flat"
FLAT_REQ_NAME_CLMN="$(basename ${GENERAL_REQUEST_CLMN} | cut -d. -f1)_${CHUNK}_request.flat"

singularity exec --cleanenv --no-home \
    --env "FDB_HOME=$(realpath ${FDB_HOME})" \
    --env "SCRIPTDIR=${SCRIPTDIR}" \
    --env "LIBDIR=${LIBDIR}" \
    --env "GENERAL_REQUEST_CLTE=${GENERAL_REQUEST_CLTE}" \
    --env "GENERAL_REQUEST_CLMN=${GENERAL_REQUEST_CLMN}" \
    --env "EXPVER=${EXPVER}" \
    --env "START_DATE=${START_DATE}" \
    --env "SECOND_TO_LAST_DATE=${SECOND_TO_LAST_DATE}" \
    --env "EXPERIMENT=${EXPERIMENT}" \
    --env "CHUNK=${CHUNK}" \
    --env "MODEL_NAME=${MODEL_NAME}" \
    --env "ACTIVITY=${ACTIVITY}" \
    --env "GENERATION=${GENERATION}" \
    --env "REALIZATION=${REALIZATION}" \
    --env "FLAT_REQ_NAME_CLTE=${FLAT_REQ_NAME_CLTE}" \
    --env "FLAT_REQ_NAME_CLMN=${FLAT_REQ_NAME_CLMN}" \
    --env "WIPE_DOIT=${WIPE_DOIT}" \
    --env "WIPE_MONTHLY=${WIPE_MONTHLY}" \
    --bind "$(realpath $PWD)" \
    --bind "$(realpath ${SCRATCH_DIR})" \
    --bind "$(realpath ${LIBDIR}/common)" \
    --bind "$(realpath ${SCRIPTDIR}/FDB)" \
    --bind "$(realpath ${DQC_PROFILE_PATH})" \
    --bind "$(realpath ${FDB_HOME})" \
    --bind "${FDB_HOME}" \
    --bind "${DEVELOPMENT_PROJECT_SCRATCH}" \
    --bind "$(realpath ${DEVELOPMENT_PROJECT_SCRATCH})" \
    --bind "${OPERATIONAL_PROJECT_SCRATCH}" \
    --bind "$(realpath ${FDB_PROD})" \
    --bind "$(realpath ${CURRENT_ROOTDIR})" \
    "$HPC_CONTAINER_DIR"/gsv/gsv_${GSV_VERSION}.sif \
    bash -c \
    '
    set -xuve
    MINIMUM_KEYS=class,dataset,experiment,activity,expver,model,generation,realization,type,stream
    source "${LIBDIR}"/common/util.sh
    # Wipe clte data always
    # lib/common/util.sh (exec_wipe) (auto generated comment)
    exec_wipe "${WIPE_DOIT}" "${GENERAL_REQUEST_CLTE}" "${FLAT_REQ_NAME_CLTE}" "${MINIMUM_KEYS},date"

    # Wipe clmn data only if first day of month is in the date list
    if [[ "${WIPE_MONTHLY}" == true ]]; then
# lib/common/util.sh (exec_wipe) (auto generated comment)
        exec_wipe "${WIPE_DOIT}" "${GENERAL_REQUEST_CLMN}" "${FLAT_REQ_NAME_CLMN}" "${MINIMUM_KEYS},year,month"
    fi
    '
