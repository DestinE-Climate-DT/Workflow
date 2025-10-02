#!/bin/bash
# Listing part of the wipe

# INTERFACE

# HEADER

CURRENT_ROOTDIR=${1:-%CURRENT_ROOTDIR%}
CURRENT_ARCH=${2:-%CURRENT_ARCH%}
CHUNK=${3:-%CHUNK%}
START_DATE=${4:-%CHUNK_START_DATE%}
SECOND_TO_LAST_DATE=${5:-%CHUNK_SECOND_TO_LAST_DATE%}
MODEL_NAME=${6:-%REQUEST.MODEL%}
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
WIPE_DOIT=${19:-%CONFIGURATION.WIPE.DOIT%}
MEMBER=${20:-%MEMBER%}
MEMBER_LIST=${21:-%EXPERIMENT.MEMBERS%}
FDB_INFO_FILE_PATH=${22:-%REQUEST.INFO_FILE_PATH%}
FDB_INFO_FILE_NAME=${23:-%REQUEST.INFO_FILE_NAME%}
BASE_VERSION=${24:-%BASE.VERSION%}
SPLIT_END_DATE=${25:-%SPLIT_END_DATE%}
CONTAINER_COMMAND=${26:-%CURRENT_CONTAINER_COMMAND%}
MODIFY_METADATA_TRANSFER=${27:-%CONFIGURATION.TRANSFER.MODIFY_METADATA%}
MODIFY_METADATA_FIELDS=${28:-%CONFIGURATION.TRANSFER.MODIFY_METADATA_FIELDS%}
BRIDGE_EXPVER=${29:-%REQUEST.BRIDGE_EXPVER%}
HPC_PROJECT_ROOT=${30:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${31:-%CURRENT_LOCAL_DIR%}
PROJDEST=${32:-%PROJECT.PROJECT_DESTINATION%}
DQC_PROFILE_ROOT=${33:-%CONFIGURATION.DQC_PROFILE_ROOT%}
DATA_PORTFOLIO=${34:-%CONFIGURATION.DATA_PORTFOLIO%}
DQC_PROFILE=${35:-%CONFIGURATION.DQC_PROFILE%}

# END_HEADER

set -xuve

HPC=$(echo ${CURRENT_ARCH})

# LOAD FDB MODULES & FDB5 CONFIG FILE
. "${LIBDIR}/${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

WIPE_REQUESTS_PATH=${CURRENT_ROOTDIR}/wipe_requests
mkdir -p ${WIPE_REQUESTS_PATH}
cd ${WIPE_REQUESTS_PATH}

# lib/common/util.sh (generate_profiles) (auto generated comment)
generate_profiles

# Call the function and assign the result to TRANSFER_MONTHLY
# lib/common/util.sh (enable_process_monthly) (auto generated comment)
WIPE_MONTHLY=$(enable_process_monthly "$START_DATE" "$SPLIT_END_DATE")

# lib/common/util.sh (get_member_number) (auto generated comment)
REALIZATION=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

ADDITIONAL_BINDINGS=("$(realpath ${FDB_HOME})" "$(realpath ${WIPE_REQUESTS_PATH})"
"${DATABRIDGE_FDB_HOME}" "$(realpath ${DATABRIDGE_FDB_HOME})" "${CURRENT_ROOTDIR}")
# lib/common/util.sh (setup_additional_binds) (auto generated comment)
bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")

# lib/common/util.sh (check_expver_match) (auto generated comment)
check_expver_match "$MODIFY_METADATA_TRANSFER" "$MODIFY_METADATA_FIELDS" "$BRIDGE_EXPVER" "$EXPVER"

# Check each profile has previously been correctly transferred to the brige
for profile_file in "${DQC_PROFILE_PATH}"/*.yaml; do
    # Only check monthly data once (for the chunk/split containing first day of month)
    if [[ "$profile_file" == *monthly* ]] && [[ "$WIPE_MONTHLY" == false ]]; then
        continue
    else
        EXPECTED_MESSAGES=-1
        LISTED_MESSAGES=-2
        ${CONTAINER_COMMAND} exec --cleanenv --no-home \
            --env "FDB_HOME=${FDB_HOME}" \
            --env "EXPVER=${BRIDGE_EXPVER}" \
            --env "START_DATE=${START_DATE}" \
            --env "CHUNK=${CHUNK}" \
            --env "SECOND_TO_LAST_DATE=${SECOND_TO_LAST_DATE}" \
            --env "EXPERIMENT=${EXPERIMENT}" \
            --env "MODEL_NAME=${MODEL_NAME^^}" \
            --env "LIBDIR=${LIBDIR}" \
            --env "ACTIVITY=${ACTIVITY}" \
            --env "GENERATION=${GENERATION}" \
            --env "REALIZATION=${REALIZATION}" \
            --env "profile_file=${profile_file}" \
            --env "DATABRIDGE_FDB_HOME=${DATABRIDGE_FDB_HOME}" \
            --env "SCRIPTDIR=${SCRIPTDIR}" \
            --env "WIPE_REQUESTS_PATH=${WIPE_REQUESTS_PATH}" \
            ${bindings} \
            "$HPC_CONTAINER_DIR"/gsv/gsv_${GSV_VERSION}.sif \
            bash -c \
            '
            set -xuve
            cd ${WIPE_REQUESTS_PATH}
            source "${LIBDIR}"/common/util.sh
            profile_name=$(basename ${profile_file} | cut -d. -f1)
            BASE_NAME=${profile_name}_sdate_${START_DATE}_endate_${SECOND_TO_LAST_DATE}_real_${REALIZATION}
            FLAT_REQ_NAME="${BASE_NAME}_request.flat"
            # lib/common/util.sh (check_messages_wipe) (auto generated comment)
            check_messages_wipe "${profile_file}"
            '
    fi
done
