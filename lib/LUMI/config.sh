#!/bin/bash
# Configuration for LUMI platform

#####################################################
# Loads and sets, most SIM variables needed by the
# ICON run-script. Some settings will be included
# custom confs
# Globals:
# Arguments:
#
######################################################
function load_SIM_env_icon_gpu() {

    export HDF5_USE_FILE_LOCKING="${HDF5_USE_FILE_LOCKING}"
    export FI_CXI_OPTIMIZED_MRS="${FI_CXI_OPTIMIZED_MRS}"
    export FI_CXI_RX_MATCH_MODE="${FI_CXI_RX_MATCH_MODE}"
    export FI_MR_CACHE_MONITOR="${FI_MR_CACHE_MONITOR}"
    export MPICH_ALLREDUCE_NO_SMP="${MPICH_ALLREDUCE_NO_SMP}"
    export MPICH_COLL_OPT_OFF="${MPICH_COLL_OPT_OFF}"
    export PMI_SIGNAL_STARTUP_COMPLETION="${PMI_SIGNAL_STARTUP_COMPLETION}"
    export MPICH_SMP_SINGLE_COPY_MODE="${MPICH_SMP_SINGLE_COPY_MODE}"

    # Load dynamic libraries for GPU support
    export LD_LIBRARY_PATH="${MODEL_PATH}/install/lib:${LD_LIBRARY_PATH}"
    export LD_LIBRARY_PATH="${MODEL_PATH}/install/lib64:${LD_LIBRARY_PATH}"
}

#####################################################
# Set environment to be able to run OBSALL application
# Globals:
# Arguments:
#
######################################################
function load_environment_OBSALL() {
    # Function removed to avoid exposing sensitive information
    true
}

###################################################
## Loads environment for backup job
###################################################
function load_backup_env() {
    module load LUMI/23.03
    module load parallel
}

function load_compile_env_nemo_cpu() {
    true
}

######################################################
# Sets up array of bindings.
# Globals:
#   SCRATCH_DIR
#   HPC_PROJECT_ROOT
#   LOCAL_DIR
#   PWD
######################################################
function load_singularity() {
    echo "Singularity is already loaded"
    # need to bind everything for LUMI because the bindings don't
    # apply to subdirectories in the same way as MN5
    export SINGULARITY_BIND="/pfs/lustrep1/,/pfs/lustrep2/,/pfs/lustrep3/,/pfs/lustrep4/,${SCRATCH_DIR},${HPC_PROJECT_ROOT},${LOCAL_DIR},$(realpath $PWD)"
    # make it so that a user's local env can't interfere with the container
    export SINGULARITYENV_PYTHONUSERBASE=1
}

#####################################################
# Purges duplicate data then retrieves and creates the
# requests for the FDB transfer.
# Globals:
#   CONTAINER_COMMAND
#   FDB_HOME
#   EXPVER
#   START_DATE
#   CHUNK
#   SECOND_TO_LAST_DATE
#   EXPERIMENT
#   MODEL_NAME
#   ACTIVITY
#   REALIZATION
#   GENERATION
#   LIBDIR
#   GRIB_FILE_NAME
#   SCRIPTDIR
#   BASE_NAME
#   CHUNK_SECOND_TO_LAST_DATE
#   TRANSFER_REQUESTS_PATH
#   TRANSFER_MONTHLY
#   SCRATCH_DIR
#   HPC
#   MARS_BINARY
#   MODIFY_METADATA_FIELDS
#   DQC_PROFILE_PATH
# Arguments:
######################################################
function fdb_transfer() {

    for profile_file in "${DQC_PROFILE_PATH}"/*.yaml; do

        if [[ "$profile_file" == *monthly* ]] && [[ "$TRANSFER_MONTHLY" == false ]]; then
            # Skip the monthly profile if it is not the first chunk
            continue
        fi

        profile_name=$(basename "$profile_file" | cut -d. -f1)
        BASE_NAME=${profile_name}_sdate_${START_DATE}_endate_${SPLIT_SECOND_TO_LAST_DATE}_real_${REALIZATION}
        GRIB_FILE_NAME="${BASE_NAME}.grb"
        MARS_REQUEST_NAME="${BASE_NAME}.mars"
        export FDB_HOME=${FDB_DIR_HEALPIX}

        # Write extracted GRIB data in the DataBridge using the MARS client, if it was not completed before
        if [ ! -f "${BASE_NAME}_COMPLETED" ]; then
            # we need to purge the data in LUMI, not LUMI-TRANSFER
            HPC=$(echo ${CURRENT_ARCH} | cut -d- -f1)
            purge_duplicated_data ${profile_file} ${BASE_NAME}
            retrieve_and_create_requests ${profile_file}
        fi

        if [ ! -f "${BASE_NAME}_COMPLETED" ]; then
            export FDB_HOME=${DATABRIDGE_FDB_HOME}
            if [ -s ${GRIB_FILE_NAME} ]; then
                # lib/LUMI/config.sh (export_env_transfer) (auto generated comment)
                export_env_transfer
                ${MARS_BINARY}/mars ${MARS_REQUEST_NAME}
                echo "ARCHIVE OF ${BASE_NAME} SUCCESSFUL"
                touch "${BASE_NAME}_COMPLETED"
            else
                echo "ERROR: ARCHIVE OF ${BASE_NAME} NOT SUCCESSFUL"
                exit 1
            fi
            rm "${GRIB_FILE_NAME}"
        fi

    done
}

#####################################################
# Function to prepare the transfer of a profile
# Globals:
#   FDB_HOME
#   EXPVER
#   START_DATE
#   CHUNK
#   SECOND_TO_LAST_DATE
#   EXPERIMENT
#   MODEL_NAME
#   ACTIVITY
#   GENERATION
#   LIBDIR
#   REALIZATION
#   MARS_BINARY
# Arguments:
#   profile_file
#####################################################
function prepare_transfer() {

    profile_file=$1

    if [ ! -f "${BASE_NAME}_COMPLETED" ]; then

        if [ ! -f "${BASE_NAME}_retrieve_COMPLETED" ]; then

            python3 "${SCRIPTDIR}/FDB/yaml_to_mars_retrieve.py" --file="$profile_file" \
                --expid="${EXPVER}" --startdate="${START_DATE}" --experiment="${EXPERIMENT,,}" \
                --realization="${REALIZATION}" --enddate="${SECOND_TO_LAST_DATE}" --chunk="${CHUNK}" \
                --model="${MODEL_NAME,,}" --activity="${ACTIVITY,,}" --generation="${GENERATION}" \
                --grib_file_name="${GRIB_FILE_NAME}"

            touch "${BASE_NAME}_retrieve_COMPLETED"
        fi

        if [ ${MODIFY_METADATA,,} == "true" ]; then
            # lib/common/util.sh (change_metadata) (auto generated comment)
            change_metadata ${MODIFY_METADATA_FIELDS} ${GRIB_FILE_NAME}
        else
            BRIDGE_EXPVER=${EXPVER}
        fi

        python3 "${SCRIPTDIR}/FDB/yaml_to_mars_archive.py" --file="$profile_file" \
            --expid="${BRIDGE_EXPVER}" --startdate="${START_DATE}" --experiment="${EXPERIMENT,,}" \
            --enddate="${SECOND_TO_LAST_DATE}" --chunk="${CHUNK}" --realization="${REALIZATION}" \
            --generation="${GENERATION}" --model="${MODEL_NAME,,}" --activity="${ACTIVITY,,}" \
            --grib_file_name="${GRIB_FILE_NAME}" --databridge_database="${DATABRIDGE_DATABASE}"

    fi
}

#####################################################
# Retrieves and creates the requests for the FDB transfer.
# Globals:
#   CONTAINER_COMMAND
#   FDB_HOME
#   EXPVER
#   START_DATE
#   CHUNK
#   SECOND_TO_LAST_DATE
#   EXPERIMENT
#   MODEL_NAME
#   ACTIVITY
#   REALIZATION
#   GENERATION
#   LIBDIR
#   GRIB_FILE_NAME
#   SCRIPTDIR
#   BASE_NAME
#   CHUNK_SECOND_TO_LAST_DATE
#   TRANSFER_REQUESTS_PATH
#   TRANSFER_MONTHLY
#   SCRATCH_DIR
#   HPC
#   MARS_BINARY
#   CONTAINER_DIR
# Arguments:
#   profile_file
######################################################
function retrieve_and_create_requests() {

    cd ${TRANSFER_REQUESTS_PATH}

    profile_file=$1

    ADDITIONAL_BINDINGS=("$(realpath $PWD)" "${FDB_HOME}")
    bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")

    ${CONTAINER_COMMAND} exec --cleanenv --no-home \
        --env "FDB_HOME=${FDB_HOME}" \
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
        --env "GRIB_FILE_NAME=${GRIB_FILE_NAME}" \
        --env "SCRIPTDIR=$(realpath ${SCRIPTDIR})" \
        --env "BASE_NAME=${BASE_NAME}" \
        --env "CHUNK_SECOND_TO_LAST_DATE=${CHUNK_SECOND_TO_LAST_DATE}" \
        --env "TRANSFER_REQUESTS_PATH=${TRANSFER_REQUESTS_PATH}" \
        --env "TRANSFER_MONTHLY=${TRANSFER_MONTHLY}" \
        --env "SCRATCH_DIR=${SCRATCH_DIR}" \
        --env "HPC=${HPC}" \
        --env "MARS_BINARY=${MARS_BINARY}" \
        --env "DATABRIDGE_DATABASE=${DATABRIDGE_DATABASE}" \
        --env "FDB_DATA_WRITE_QUEUE_LENGTH=16" \
        --env "FDB_READ_LIMIT=102400000" \
        --env "CONTAINER_DIR=${CONTAINER_DIR}" \
        --env "MODIFY_METADATA=${MODIFY_METADATA}" \
        --env "MODIFY_METADATA_FIELDS=${MODIFY_METADATA_FIELDS}" \
        --env "GRIB_FILE_NAME=${GRIB_FILE_NAME}" \
        --env "BRIDGE_EXPVER=${BRIDGE_EXPVER}" \
        ${bindings} \
        "${CONTAINER_DIR}/gsv/gsv_${GSV_VERSION}.sif" \
        bash -c \
        '
        set -xuve

        . "${LIBDIR}"/common/util.sh
        . "${LIBDIR}/${HPC}"/config.sh
        export_env_transfer
        # lib/common/util.sh (prepare_transfer) (auto generated comment)
        prepare_transfer ${profile_file}
        '
}

#########################################
# Function to change metadata in GRIB files
# Arguments:
#   metadata_fields
#   metadata_fields should be a comma-separated list of key=value pairs
#########################################
function change_metadata() {
    local metadata_fields="$1"
    local input_file="$2"

    IFS=',' read -ra fields <<<"$metadata_fields"
    for pair in "${fields[@]}"; do
        local temp_file="${input_file}.tmp"
        grib_set -s "$pair" "$input_file" "$temp_file"
        mv "$temp_file" "$input_file"
    done
}

function rsync_datamover() {
    true
}

function export_env_transfer() {
    true
}

####################################
# Load additional modules required for performance monitoring
####################################
function load_additional_modules() {
    set +xuve
    module load cray-python/3.11.7
    set -xuve
}
