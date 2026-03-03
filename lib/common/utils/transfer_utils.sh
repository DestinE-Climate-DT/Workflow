#!/bin/bash

# Utils functions for transfer.sh

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
    # set up for the purge
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
