#!/bin/bash

# General utils that are used in more than one template

#####################################################
# Computes the member number, taking the list from
# %EXPERIMENT.MEMBERS% and %MEMBER%
# Globals:
# Arguments:
#    MEMBERS_LIST
#    MEMBER
#
#####################################################
function get_member_number() {
    MEMBERS_LIST=$1
    MEMBER=$2

    # Split MEMBERS_LIST into an array
    read -r -a MEMBERS_ARRAY <<<"$MEMBERS_LIST"

    # Find the index of the MEMBER in MEMBERS_ARRAY
    MEMBER_NUMBER=0
    for i in "${!MEMBERS_ARRAY[@]}"; do
        if [ "${MEMBERS_ARRAY[$i]}" == "$MEMBER" ]; then
            MEMBER_NUMBER=$((i + 1))
            break
        fi
    done

    # Print or use the computed MEMBER_NUMBER as needed
    if [ "$MEMBER_NUMBER" -ne 0 ]; then
        echo $MEMBER_NUMBER
    else
        echo "Member not found in the list."
        exit 1
    fi
}

#####################################################
# Detect if the first day of a month is contained in the split
# Arguments:
#   START_DATE
#   SECOND_TO_LAST_DATE
#   END_MONTH
#   END_YEAR
######################################################
# Function to determine if the first day of the month is within the date range
function enable_process_monthly() {
    # TO DO: this function doesn't support month changes in the middle of the chunk/split
    local start_date="$1"
    local end_date="$2"

    # Get first date of the month corresponding to the start date
    local start_date_month=$(date -d "${start_date}" +'%m')
    local start_date_year=$(date -d "${start_date}" +'%Y')
    local first_day_of_month=$(date -d "${start_date_year}${start_date_month}01" +'%Y%m%d')

    # to avoid issues with the while loop, check that the start date is before the split end date
    # convert both dates to seconds since epoch
    local start_date_epoch=$(date -d "${start_date}" +%s)
    local end_date_epoch=$(date -d "${end_date}" +%s)
    if [[ $start_date_epoch -gt $end_date_epoch ]]; then
        echo "Start date is after split end date. Exiting."
        exit 1
    fi

    # Enable PROCESS_MONTHLY only if the first day of the month is in the date list
    local process_monthly="false"
    local date="$start_date"
    while [[ "$date" != "$end_date" ]]; do
        if [[ "$date" == "$first_day_of_month" ]]; then
            process_monthly="true"
            break
        fi
        date=$(date --date="$date + 1 day" +%Y%m%d)
    done

    echo "$process_monthly"
}

#####################################################
# Purges duplicated data.
# Globals:
#   CLEAN_DIR
#   SCRIPTDIR
#   EXPVER
#   START_DATE
#   EXPERIMENT
#   GENERATION
#   REALIZATION
#   SECOND_TO_LAST_DATE
#   CHUNK
#   MODEL_NAME
#   ACTIVITY
#   TRANSFER_REQUESTS_PATH
# Arguments:
#   profile_file
######################################################
function purge_duplicated_data() {

    profile_file=$1
    BASE_NAME=$2

    # Run FDB purge
    FLAT_REQ_NAME="${BASE_NAME}_request.flat"
    CLEAN_DIR=${CURRENT_ROOTDIR}/clean_requests/
    mkdir -p ${CLEAN_DIR}

    ADDITIONAL_BINDINGS=("$(realpath $PWD)" "$(realpath ${FDB_HOME})" "$(realpath ${CLEAN_DIR})")
    bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")

    ${CONTAINER_COMMAND} exec --cleanenv --no-home \
        --env "FDB_HOME=$(realpath ${FDB_HOME})" \
        --env "EXPVER=${EXPVER}" \
        --env "START_DATE=${START_DATE}" \
        --env "CHUNK=${CHUNK}" \
        --env "SECOND_TO_LAST_DATE=${SPLIT_SECOND_TO_LAST_DATE}" \
        --env "EXPERIMENT=${EXPERIMENT}" \
        --env "MODEL_NAME=${MODEL_NAME}" \
        --env "ACTIVITY=${ACTIVITY}" \
        --env "REALIZATION=${REALIZATION}" \
        --env "GENERATION=${GENERATION}" \
        --env "profile_file=${profile_file}" \
        --env "LIBDIR=${LIBDIR}" \
        --env "SCRIPTDIR=$(realpath ${SCRIPTDIR})" \
        --env "BASE_NAME=${BASE_NAME}" \
        --env "FLAT_REQ_NAME=${FLAT_REQ_NAME}" \
        --env "CHUNK_SECOND_TO_LAST_DATE=${CHUNK_SECOND_TO_LAST_DATE}" \
        --env "CLEAN_DIR=${CLEAN_DIR}" \
        --env "TRANSFER_REQUESTS_PATH=${TRANSFER_REQUESTS_PATH}" \
        --env "TRANSFER_MONTHLY=${TRANSFER_MONTHLY}" \
        --env "HPCROOTDIR=${HPCROOTDIR}" \
        ${bindings} \
        "$HPC_CONTAINER_DIR"/gsv/gsv_${GSV_VERSION}.sif \
        bash -c \
        '
        set -xuve

        MINIMUM_KEYS="class,dataset,experiment,activity,expver,model,generation,realization,stream"
        OMIT_KEYS="time,levelist,param,levtype,type,resolution"
        if [[ "$profile_file" == *monthly* ]]; then
            MINIMUM_KEYS+=",year"
            OMIT_KEYS+=",month"
        else
            MINIMUM_KEYS+=",date"
        fi

        cd ${CLEAN_DIR}
        # Convert YAML profile to flat request file
        python3 "${SCRIPTDIR}/FDB/yaml_to_flat_request.py" \
            --file="${profile_file}" --expver="${EXPVER}" --startdate="${START_DATE}" \
            --experiment="${EXPERIMENT}" --generation="${GENERATION}" \
            --realization="${REALIZATION}" --enddate="${SECOND_TO_LAST_DATE}" \
            --model="${MODEL_NAME^^}" --activity="${ACTIVITY}" \
            --request_name="${FLAT_REQ_NAME}" --omit-keys="${OMIT_KEYS}"
        # Purge data using FDB purge command
        fdb purge --ignore-no-data --doit --minimum-keys ${MINIMUM_KEYS} "$(<${FLAT_REQ_NAME})" >/dev/null

        '
}

#####################################################
# Check if the profiles exist already. We should generate them in the first transfer that
# runs.
# Globals:
#   CURRENT_ROOTDIR
#   PROJDEST
#   DQC_PROFILE_ROOT
#   CONTAINER_COMMAND
#   DATA_PORTFOLIO
#   DQC_PROFILE
#   HPC_CONTAINER_DIR
#   GSV_VERSION
######################################################
function generate_profiles() {

    DATA_PORTFOLIO_PATH="${CURRENT_ROOTDIR}/${PROJDEST}/data-portfolio"
    cd ${DATA_PORTFOLIO_PATH}
    DATA_PORTFOLIO_VERSION=$(git describe --exact-match --tags)
    mkdir -p ${DQC_PROFILE_ROOT}

    if [ ! -f flag_profiles_generated ]; then
        echo "Generating profiles"
        ADDITIONAL_BINDINGS=("$PWD")
        bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")
        ${CONTAINER_COMMAND} exec --cleanenv --no-home \
            --env DATA_PORTFOLIO_PATH="${DATA_PORTFOLIO_PATH}" \
            --env DATA_PORTFOLIO="${DATA_PORTFOLIO}" \
            --env DQC_PROFILE="${DQC_PROFILE}" \
            --env DATA_PORTFOLIO_VERSION="${DATA_PORTFOLIO_VERSION}" \
            --env DQC_PROFILE_ROOT="${DQC_PROFILE_ROOT}" \
            ${bindings} \
            "$HPC_CONTAINER_DIR"/gsv/gsv_${GSV_VERSION}.sif \
            bash -c \
            ' set -xuve
            python3 -m gsv.dqc.profiles.scripts.generate_profiles -r "${DATA_PORTFOLIO_PATH}" \
            -p "${DATA_PORTFOLIO}" -c "${DQC_PROFILE}" -t "${DATA_PORTFOLIO_VERSION}" \
            -o "${DQC_PROFILE_ROOT}" '
        touch flag_profiles_generated
    else
        echo "Profiles already generated"
        return 0
    fi
}

######################################################
# Builds binding args for containers.
# Arguments:
#   BINDINGS
######################################################
function build_bindings() {
    for bind in "$@"; do
        printf '  --bind %s' "$bind"
    done
}

######################################################
# Sets up an additional array of necessary bindings.
# Arguments:
#   ADDITIONAL_BINDINGS
######################################################
function setup_additional_binds() {
    bindings=$(build_bindings "${ADDITIONAL_BINDINGS[@]}")
    echo "${bindings}"
}

#####################################################
# Check if the FDB info file exists already.
# We should generate them in the first transfer that
# runs.
# Globals:
#   AQUA_START_DATE
#   START_DATE
#   CURRENT_ROOTDIR
#   SCRIPTDIR
#   FDB_INFO_FILE_NAME
#   MODEL
#   HPC_CONTAINER_DIR
#   GSV_VERSION
#   CONTAINER_COMMAND
# Arguments:
#   EXPVER
######################################################
function generate_fdb_info_file() {
    local EXPVER="$1"
    if [ ! -f "${FDB_INFO_FILE_NAME}" ]; then
        # lib/LUMI/config.sh (load_singularity) (auto generated comment)
        # lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
        load_singularity
        # If AQUA_START_DATE is not set, use the default value (SIM_START_DATE)
        if [ -z "${AQUA_START_DATE}" ]; then
            AQUA_START_DATE="${SIM_START_DATE}"
        fi

        ADDITIONAL_BINDINGS=()
        # lib/common/util.sh (setup_additional_binds) (auto generated comment)
        bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")

        ${CONTAINER_COMMAND} exec --no-home \
            --env "SCRIPTDIR=${SCRIPTDIR}" \
            --env "FDB_INFO_FILE_NAME=${FDB_INFO_FILE_NAME}" \
            --env "HPCROOTDIR=${CURRENT_ROOTDIR}" \
            --env "EXPVER=${EXPVER}" \
            --env "MODEL=${MODEL}" \
            --env "AQUA_START_DATE=${AQUA_START_DATE}" \
            ${bindings} \
            "${HPC_CONTAINER_DIR}"/gsv/gsv_${GSV_VERSION}.sif \
            bash -c \
            'set -xuve && python3 ${SCRIPTDIR}/FDB/update_fdb_info.py --create --file \
            ${FDB_INFO_FILE_NAME} --expver ${EXPVER} --data_start_date ${AQUA_START_DATE} '
    fi
}
