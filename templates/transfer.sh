#!/bin/bash

# INTERFACE
set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
CURRENT_ARCH=${2:-%CURRENT_ARCH%}
CHUNK=${3:-%CHUNK%}
START_DATE=${4:-%SPLIT_START_DATE%}
SPLIT_SECOND_TO_LAST_DATE=${5:-%SPLIT_SECOND_TO_LAST_DATE%}
MODEL_NAME=${6:-%REQUEST.MODEL%}
EXPERIMENT=${7:-%REQUEST.EXPERIMENT%}
ACTIVITY=${8:-%REQUEST.ACTIVITY%}
DQC_PROFILE_PATH=${9:-%CONFIGURATION.DQC_PROFILE_PATH%}
FDB_HOME=${10:-%REQUEST.FDB_HOME%}
EXPVER=${11:-%REQUEST.EXPVER%}
SCRATCH_DIR=${12:-%CURRENT_SCRATCH_DIR%}
HPC_CONTAINER_DIR=${13:-%CURRENT_CONTAINER_DIR%}
GSV_VERSION=${14:-%GSV.VERSION%}
LIBDIR=${15:-%CONFIGURATION.LIBDIR%}
MEMBER=${16:-%MEMBER%}
MEMBER_LIST=${17:-%EXPERIMENT.MEMBERS%}
GENERATION=${18:-%REQUEST.GENERATION%}
SCRIPTDIR=${19:-%CONFIGURATION.SCRIPTDIR%}
FDB_PROD=${20:-%CURRENT_FDB_PROD%}
DATABRIDGE_FDB_HOME=${21:-%CURRENT_DATABRIDGE_FDB_HOME%}
FDB_INFO_FILE_PATH=${22:-%REQUEST.INFO_FILE_PATH%}
FDB_INFO_FILE_NAME=${23:-%REQUEST.INFO_FILE_NAME%}
SPLIT_FIRST=${24:-%SPLIT_FIRST%}
CHUNK_SECOND_TO_LAST_DATE=${25:-%CHUNK_SECOND_TO_LAST_DATE%}
SPLITS=${26:-%SPLITS%}
EXPID=${27:-%DEFAULT.EXPID%}
SIM_START_DATE=${28:-%SDATE%}
SPLIT_END_DATE=${29:-%SPLIT_END_DATE%}
CONTAINER_COMMAND=${30:-%CURRENT_CONTAINER_COMMAND%}
DQC_PROFILE=${31:-%CONFIGURATION.DQC_PROFILE%}
DATA_PORTFOLIO=${32:-%CONFIGURATION.DATA_PORTFOLIO%}
DQC_PROFILE_ROOT=${33:-%CONFIGURATION.DQC_PROFILE_ROOT%}
PROJECT=${34:-%CURRENT_PROJECT%}
USER=${35:-%CURRENT_USER%}
CURRENT_ROOTDIR=${36:-%CURRENT_ROOTDIR%}
MARS_BINARY=${37:-%CURRENT_MARS_BINARY%}
PROJDEST=${38:-%PROJECT.PROJECT_DESTINATION%}
DATABRIDGE_DATABASE=${39:-%CURRENT_DATABRIDGE_DATABASE%}
CONTAINER_DIR=${40:-%CURRENT_CONTAINER_DIR%}
# Extra bindings needed for the container in hpc-fdb
OPERATIONAL_PROJECT_SCRATCH=${41:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${42:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}
MODIFY_METADATA=${43:-%CONFIGURATION.TRANSFER.MODIFY_METADATA%}
MODIFY_METADATA_FIELDS=${44:-%CONFIGURATION.TRANSFER.MODIFY_METADATA_FIELDS%}
HPC_PROJECT_ROOT=${45:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${46:-%CURRENT_LOCAL_DIR%}
FDB_COPY_BIN=${47:-%CURRENT_FDB_COPY_BIN%}
FDB_CONFIG_HPC=${48:-%CONFIGURATION.FDB_CONFIG_HPC%}
FDB_CONFIG_DATABRIDGE=${49:-%CONFIGURATION.FDB_CONFIG_DATABRIDGE%}
BRIDGE_EXPVER=${50:-%REQUEST.BRIDGE_EXPVER%}
AQUA_START_DATE=${51:-%AQUA.START_DATE%}
MODEL=${52:-%REQUEST.MODEL%}

# END_HEADER

HPC=$(echo ${CURRENT_ARCH})

# LOAD FDB MODULES & FDB5 CONFIG FILE
. "${LIBDIR}/${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh
. "${LIBDIR}"/common/utils/transfer_utils.sh

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

# lib/common/util.sh (generate_profiles) (auto generated comment)
generate_profiles

export METKIT_PARAM_RAW=1
export SCRATCH_DIR="${SCRATCH_DIR}"

# if the length of BRIDGE_EXPVER is 0, use the EXPVER
if [ -z "${BRIDGE_EXPVER}" ]; then
    BRIDGE_EXPVER=${EXPVER}
fi

FDB_DIR_HEALPIX="${FDB_HOME}"
FDB_DIR_LATLON="${FDB_HOME}/latlon"
FDB_DIR_NATIVE="${FDB_HOME}/native"

if [ -d "${DQC_PROFILE_PATH}" ]; then
    echo "Transferring profiles in ${DQC_PROFILE_PATH}"
else
    echo "ERROR: The path ${DQC_PROFILE_PATH} does not exist."
    exit 1
fi

TRANSFER_REQUESTS_PATH="${CURRENT_ROOTDIR}/transfer_requests"
mkdir -p ${TRANSFER_REQUESTS_PATH}
cd ${TRANSFER_REQUESTS_PATH}

# lib/common/util.sh (get_member_number) (auto generated comment)
REALIZATION=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

# Call the function and assign the result to TRANSFER_MONTHLY
# lib/common/util.sh (enable_process_monthly) (auto generated comment)
TRANSFER_MONTHLY=$(enable_process_monthly "$START_DATE" "$SPLIT_END_DATE")

# lib/LUMI/config.sh (fdb_transfer) (auto generated comment)
# lib/MARENOSTRUM5-TRANSFER/config.sh (fdb_transfer) (auto generated comment)
fdb_transfer

LOGS_FOLDER="${CURRENT_ROOTDIR}/LOG_${EXPID}"
# Only update the YAML file when a full month is transferred
# We check if the current chunk was completely transferred (number of splits - 1 that is the current split)
# Count the number of _COMPLETED files in the previous chunk
# They follow the pattern t039_19900101_fc0_1_31_TRANSFER_COMPLETED
# And are located in the LOGS_FOLDER
NUMBER_OF_COMPLETED_SPLITS=$(find "${LOGS_FOLDER}" -type f -name "${EXPID}_${SIM_START_DATE}_${MEMBER}_${CHUNK}_*_TRANSFER_COMPLETED" | wc -l)

if [ "$((NUMBER_OF_COMPLETED_SPLITS + 1))" == "${SPLITS}" ]; then
    ADDITIONAL_BINDINGS=("${FDB_INFO_FILE_PATH}")
    # lib/common/util.sh (setup_additional_binds) (auto generated comment)
    bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")
    ${CONTAINER_COMMAND} exec \
        --env "SCRIPTDIR=${SCRIPTDIR}" \
        --env "FDB_INFO_FILE_NAME=${FDB_INFO_FILE_NAME}" \
        --env "HPCROOTDIR=${CURRENT_ROOTDIR}" \
        --env "EXPVER=${BRIDGE_EXPVER}" \
        --env "CHUNK=${CHUNK}" \
        --env "SPLIT_SECOND_TO_LAST_DATE=${SPLIT_SECOND_TO_LAST_DATE}" \
        --env "START_DATE=${START_DATE}" \
        --env "SPLIT_FIRST=${SPLIT_FIRST}" \
        --env "CHUNK_SECOND_TO_LAST_DATE=${CHUNK_SECOND_TO_LAST_DATE}" \
        --env "SPLIT_END_DATE=${SPLIT_END_DATE}" \
        ${bindings} \
        "${HPC_CONTAINER_DIR}"/gsv/gsv_${GSV_VERSION}.sif \
        bash -c \
        '
            set -xuve
            if [ "${CHUNK}" == "1" ] && [ "${SPLIT_FIRST}" == "TRUE" ]; then
                python3 ${SCRIPTDIR}/FDB/update_fdb_info.py --file ${FDB_INFO_FILE_NAME} \
                --bridge_expver ${EXPVER} --bridge_start_date ${START_DATE}
            else
                python3 ${SCRIPTDIR}/FDB/update_fdb_info.py --file ${FDB_INFO_FILE_NAME} \
                --bridge_expver ${EXPVER} --bridge_end_date ${SPLIT_END_DATE}
            fi
        '
fi
