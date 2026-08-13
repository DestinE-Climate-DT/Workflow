#!/bin/bash
#
# Configuration for BSC platform

#####################################################
# Sets up array of bindings.
# Globals:
#   SCRATCH_DIR
#   HPC_PROJECT_ROOT
#   PWD
#   MARS_BINARY
#####################################################
function load_singularity() {
    export SINGULARITY_BIND="${SCRATCH_DIR},${HPC_PROJECT_ROOT},$(realpath $PWD)"
    # make it so that a user's local env can't interfere with the container
    export SINGULARITYENV_PYTHONUSERBASE=1
    true
}

#####################################################
# Copies the data to the data bridge using FDB copy.
# Globals:
#   CONTAINER_COMMAND
#   FDB_HOME
#   EXPVER
#   START_DATE
#   CHUNK
#   SPLIT_SECOND_TO_LAST_DATE
#   EXPERIMENT
#   MODEL_NAME
#   ACTIVITY
#   REALIZATION
#   GENERATION
#   LIBDIR
#   SCRIPTDIR
#   BASE_NAME
#   CHUNK_SECOND_TO_LAST_DATE
#   TRANSFER_REQUESTS_PATH
#   TRANSFER_MONTHLY
#   SCRATCH_DIR
#   HPC
#   MARS_BINARY
#   CURRENT_FDB_COPY_BIN
#   BRIDGE_EXPVER
# Arguments:
######################################################
function fdb_transfer() {
    # lib/common/util.sh (generate_fdb_info_file) (auto generated comment)
    generate_fdb_info_file ${BRIDGE_EXPVER}

    if [ ${MODIFY_METADATA,,} == "true" ]; then
        modify_metadata_flag="--modifiers=expver=${BRIDGE_EXPVER}"
    else
        modify_metadata_flag=""
    fi

    export_env_transfer

    # MN5 only needs one profile per stream
    DQC_PROFILES=("FDB/general_request_clte.yaml" "FDB/general_request_clmn.yaml")

    for profile_file in "${DQC_PROFILES[@]}"; do

        profile_file="${SCRIPTDIR}/${profile_file}"

        if [[ "$profile_file" == *clmn* ]] && [[ "$TRANSFER_MONTHLY" == false ]]; then
            # Skip the monthly profile if it is not the first chunk
            continue
        fi

        # Monthly means are keyed by month/year, and yaml_to_flat_request.py
        # only emits those keys when day 1 of the month is inside the date
        # range. NRT boundary splits start on the last day of the month, so
        # widen the monthly request to cover the month from its first day.
        # lib/common/util.sh (get_request_start_date) (auto generated comment)
        REQUEST_START_DATE=$(get_request_start_date "${profile_file}" "${START_DATE}")

        profile_name=$(basename "$profile_file" | cut -d. -f1)
        BASE_NAME=${profile_name}_sdate_${REQUEST_START_DATE}_endate_${SPLIT_SECOND_TO_LAST_DATE}_real_${REALIZATION}

        # Transfer data in the DataBridge using FDB copy, if it was not completed before
        if [ ! -f "${BASE_NAME}_COMPLETED" ]; then

            export PATH="${MARS_BINARY}":$PATH

            FLAT_REQ_NAME="${BASE_NAME}_request.flat"
            ADDITIONAL_BINDINGS=()
            # lib/common/util.sh (setup_additional_binds) (auto generated comment)
            bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")

            ${CONTAINER_COMMAND} exec --cleanenv --no-home \
                --env "EXPVER=${EXPVER}" \
                --env "START_DATE=${REQUEST_START_DATE}" \
                --env "SPLIT_SECOND_TO_LAST_DATE=${SPLIT_SECOND_TO_LAST_DATE}" \
                --env "EXPERIMENT=${EXPERIMENT}" \
                --env "MODEL_NAME=${MODEL_NAME}" \
                --env "ACTIVITY=${ACTIVITY}" \
                --env "REALIZATION=${REALIZATION}" \
                --env "GENERATION=${GENERATION}" \
                --env "profile_file=${profile_file}" \
                --env "SCRIPTDIR=$(realpath ${SCRIPTDIR})" \
                --env "FLAT_REQ_NAME=${FLAT_REQ_NAME}" \
                ${bindings} \
                "${CONTAINER_DIR}/gsv/gsv_${GSV_VERSION}.sif" \
                bash -c \
                ' set -xuve
                python3 "${SCRIPTDIR}/FDB/yaml_to_flat_request.py" --file="$profile_file" \
                --expver="${EXPVER}" --startdate="${START_DATE}" --experiment="${EXPERIMENT,,}" \
                --enddate="${SPLIT_SECOND_TO_LAST_DATE}" --model="${MODEL_NAME,,}" \
                --activity="${ACTIVITY,,}" --generation="${GENERATION}" --realization="${REALIZATION}" \
                --omit-keys "time,levelist,resolution,type,levtype,param" --request_name="${FLAT_REQ_NAME}"'

            # fdb-copy aborts with an opaque eckit read error ("failed to
            # read 1 byte") when the request matches nothing in the source
            # FDB (e.g. monthly streams before the month is complete) --
            # list first so missing data fails with a clear message.
            FDB_LIST_BIN="$(dirname "${FDB_COPY_BIN}")/fdb-list"
            if ! ${FDB_LIST_BIN} --raw --porcelain --config=${FDB_CONFIG_HPC} "$(<${FLAT_REQ_NAME})" | grep -q .; then
                echo "ERROR: no data in the source FDB matches the request in ${FLAT_REQ_NAME}: $(<${FLAT_REQ_NAME})"
                exit 1
            fi

            ${FDB_COPY_BIN} --sort --source ${FDB_CONFIG_HPC} \
                --target ${FDB_CONFIG_DATABRIDGE} --from-list "$(<${FLAT_REQ_NAME})" \
                ${modify_metadata_flag}

            touch "${BASE_NAME}_COMPLETED"
        fi
    done
}

function export_env_transfer() {
    export FDB_DATA_WRITE_QUEUE_LENGTH=16
    export FDB_READ_LIMIT=102400000
}

function run_DN() {
    base_dir=${10}
    jobname=${9}
    app_list=${4}

    ADDITIONAL_BINDINGS=("$(realpath $PWD)" ${base_dir})
    bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")

    cd ${base_dir}

    requests_dir=${base_dir}/requests

    for app_name in $app_list; do
        request="${base_dir}/request_${app_name}_${jobname}"

        ${CONTAINER_COMMAND} exec --cleanenv --no-home \
            --env "SCRIPTDIR=${SCRIPTDIR}" \
            --env "request=${request}" \
            --env "app_name=${app_name}" \
            --env "jobname=${jobname}" \
            --env "requests_dir=${requests_dir}" \
            --env "EXPVER=${EXPVER}" \
            --env "START_DATE=${SPLIT_START_DATE}" \
            --env "SECOND_TO_LAST_DATE=${SPLIT_SECOND_TO_LAST_DATE}" \
            --env "EXPERIMENT=${EXPERIMENT}" \
            --env "MODEL_NAME=${MODEL_NAME}" \
            --env "ACTIVITY=${ACTIVITY}" \
            --env "REALIZATION=${REALIZATION}" \
            --env "GENERATION=${GENERATION}" \
            ${bindings} \
            "$HPC_CONTAINER_DIR"/gsv/gsv_${GSV_VERSION}.sif \
            bash -c \
            '
            set -xuve

            python3 "${SCRIPTDIR}/FDB/preprocess_requests.py" \
                --file="$request" \
                --omit-keys grid,method,area \
                --output-dir="${requests_dir}" \
                --jobname=${jobname} \
                --process-derived-variables \
                --realization="${REALIZATION}"

            for request in ${requests_dir}/*${jobname}.yaml; do
                echo "Processing request: $request"
                filename=$(basename "$request")
                variable=${filename%"_$jobname.yaml"}
                FLAT_REQ_NAME="request_${app_name}_${jobname}_${variable}.flat"
                # Convert YAML to flat request
                python3 "${SCRIPTDIR}/FDB/yaml_to_flat_request.py" \
                    --file="$request" --request_name="${requests_dir}/${FLAT_REQ_NAME}"
                EXPECTED_MESSAGES=$(python3 "${SCRIPTDIR}/FDB/count_expected_messages.py" \
				--file="$request" --expver="${EXPVER}" --startdate="${START_DATE}" \
				--experiment="${EXPERIMENT,,}" --enddate="${SECOND_TO_LAST_DATE}" \
				--model="${MODEL_NAME}" --activity="${ACTIVITY,,}" \
				--generation="${GENERATION}" --realization="${REALIZATION}")
                echo ${EXPECTED_MESSAGES} > ${requests_dir}/${FLAT_REQ_NAME}_expected.log
            done
            '

        for FLAT_REQ_NAME in ${requests_dir}/request_${app_name}_${jobname}_*.flat; do
            FDB_LIST_OUTPUT="${FLAT_REQ_NAME}_list.log"
            ${FDB_LIST_BIN} --raw --porcelain --config=${FDB_CONFIG_GATEWAY} "$(<${FLAT_REQ_NAME})" >"${FDB_LIST_OUTPUT}"
            LISTED_MESSAGES=$(cat ${FDB_LIST_OUTPUT} | wc -l)

            EXPECTED_MESSAGES=$(<${FLAT_REQ_NAME}_expected.log)
            if [ "$LISTED_MESSAGES" -lt "$EXPECTED_MESSAGES" ]; then
                echo "Not all messages found in HPC"
                echo "Downloading messages for ${FLAT_REQ_NAME}"
                ${FDB_COPY_BIN} --sort --from-list \
                    --source ${FDB_CONFIG_DATABRIDGE} \
                    --target ${FDB_CONFIG_GATEWAY} \
                    "$(<${FLAT_REQ_NAME})"
            else
                echo "All messages found in HPC for ${FLAT_REQ_NAME}"
            fi
        done
    done
}
