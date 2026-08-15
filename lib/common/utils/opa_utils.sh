#!/bin/bash

# Utils functions for opa.sh

#####################
# Runs OPA runscript (with GSV Interface and One_Pass in it)
# Note: No support for multiple startdates as of now.
#       Therefore, datelist equates to startdate, i.e. a string with a single value.
#
# GLOBALS USED
# ============
#    - OPA_REQUEST_DIR: Directory where requests are stored
#    - OPA_RESTART_DIR: Directory where restarts are stored
#    - OPA_OUTPATH: Output path for OPA results
#    - OPA_APP_BA_AUX: Auxiliary data path for bias adjustment (may be empty)
#    - OPA_APP_MASK_FILE: Mask file to use for OPA (may be empty)
#    - CHUNK: Chunk to use for OPA
#    - SPLIT: Split to use for OPA
#    - EXPID: Experiment ID to use for OPA
#    - APP_NAME: Name of the application to use for OPA
#    - RUN_TYPE: Run type to use for OPA
#    - MEMBER: Member to use for OPA
#    - DATELIST: Start date to use for OPA
#    - OPA_LOG_LEVEL: Log level to use for OPA
#    - OPA_VERSION: Version of OPA to use (selects the OPA container version)
#    - OPA_MP_PROC: Number of MP processes to use for OPA
#
# Note: This function expects the following environment variables to be set:
#
# INPUTS
# ======
#    - request_number: Request number to use for OPA
#####################
function run_OPA() {

    request_number="${1}"

    if [ ! -d "${OPA_OUTPATH}" ]; then
        mkdir -p "${OPA_OUTPATH}"
        echo "Directory created: ${OPA_OUTPATH}"
    else
        echo "Directory already exists: ${OPA_OUTPATH}"
    fi

    SRC_DIR=${HPCROOTDIR}/${PROJDEST}/one_pass/ #This step allows using dev versions of the application from the submodule
    # If the submodule does not exist, set PYTHONPATH to SCRIPTDIR (does not need to be SCRIPTDIR though)
    if [ -d "$SRC_DIR" ]; then
        export PYTHONPATH="${SRC_DIR}"
    else
        export PYTHONPATH="${SCRIPTDIR}"
    fi

    if [ -d "${OPA_APP_BA_AUX}" ]; then
        echo "The directory ${OPA_APP_BA_AUX} does not contain any BA file and therefore the bias adjustment will not be applied."
        OPA_APP_BA_AUX="$SCRIPTDIR" #Shfmt does not like having it empty
    fi

    bind_args=(
        --bind "${SCRIPTDIR}/opa/"
        --bind "${FDB_HOME}"
        --bind "${LOGDIR}"
        --bind "${OPA_OUTPATH}"
        --bind "${PYTHONPATH}"
        --bind "${OPA_APP_BA_AUX}"
        --bind "${APP_AUX_IN_DATA_DIR}"
        --bind "${DEVELOPMENT_PROJECT_SCRATCH}"
        --bind "${OPERATIONAL_PROJECT_SCRATCH}"
        --bind "${OPA_REQUEST_DIR}"
        --bind "${OPA_RESTART_DIR}"
    )
    env_args=(
        --env "request_dir=${OPA_REQUEST_DIR}"
        --env "restart_dir=${OPA_RESTART_DIR}"
        --env "chunk=${CHUNK}"
        --env "split=${SPLIT}"
        --env "expid=${EXPID}"
        --env "app_name=${APP_NAME}"
        --env "run_type=${RUN_TYPE}"
        --env "member=${MEMBER}"
        --env "startdate=${DATELIST}"
        --env "request_number=${request_number}"
        --env "outpath=${OPA_OUTPATH}"
        --env "realization=${REALIZATION}"
        --env "PYTHONPATH=${PYTHONPATH}"
        --env "FDB_HOME=${FDB_HOME}"
        --env "SCRIPTDIR=${SCRIPTDIR}"
        --env "READ_FROM_DATABRIDGE=${READ_FROM_DATABRIDGE}"
        --env "PYTHONNOUSERSITE=1"
        --env "MPLCONFIGDIR=/tmp/matplotlib"
        --env "GSV_WEIGHTS_PATH=${GSV_WEIGHTS_PATH}"
        --env "mask_file=${OPA_APP_MASK_FILE}"
    )
    runscript_args=(
        --request_dir "${OPA_REQUEST_DIR}"
        --chunk "${CHUNK}"
        --split "${SPLIT}"
        --expid "${EXPID}"
        --app_name "${APP_NAME}"
        --member "${MEMBER}"
        --realization "${REALIZATION}"
        --startdate "${DATELIST}"
        --request_number "${request_number}"
        --read_from_databridge "${READ_FROM_DATABRIDGE}"
        --restart_dir "${OPA_RESTART_DIR}"
        --outpath "${OPA_OUTPATH}"
        --mask_file "${OPA_APP_MASK_FILE}"
        --log_level "${OPA_LOG_LEVEL}"
        --mp_proc "${OPA_MP_PROC}"
    )
    container="${HPC_CONTAINER_DIR}/one_pass/one_pass_${OPA_VERSION}.sif"

    cd "${SCRIPTDIR}/opa/" || exit

    echo "Starting OPA job with PID: $$"

    # Command and arguments
    cmd=(
        singularity
        exec
        --cleanenv
        --no-home
        "${bind_args[@]}"
        "${env_args[@]}"
        "${container}"
        python3
        "${SCRIPTDIR}/opa/run_opa.py"
        "${runscript_args[@]}"
    )

    # Execute command
    "${cmd[@]}" || return 1
}

# Function to control parallel execution
function run_with_limit() {
    # Wait if we're already at max capacity before starting a new job
    while [ "$(jobs -rp | wc -l)" -ge "$OPA_MAX_PROC" ]; do
        echo "At max capacity ($OPA_MAX_PROC). Waiting for jobs to finish before starting next job..."
        # Wait for any job to finish before starting a new one
        wait -n
    done

    # Start the job and track its PID
    "$@" &
    local pid=$!
    PIDS="$PIDS $pid"

    local current_jobs=$(jobs -rp | wc -l)
    echo "Started job with PID: $pid (total running jobs: $current_jobs)"
}

#####################
# get_num_requests
# INPUT
#   yamlfile
#####################
# Count the number of request files. Intermediate step to continue
# calling run_OPA N times (one for each request file).
# TODO: Call run_opa runscript once, then have that runscript look at this request file,
# organize the data needed, then call concurrently individual routines (or child runscripts)
# concurrently as many times as needed.
#
# The block below extracts the highest numeric subkey under any top-level YAML key
# from the file ${REQUEST_PATTERN}.
#
# The YAML is assumed to have a structure like:
#
#   TOP_LEVEL_KEY:
#     1:
#       ...
#     2:
#       ...
#
# This awk script does the following:
# 1. `/^[^[:space:]]+:/`
#    Detects top-level keys (lines with no indentation followed by a colon, e.g., "TITLE:").
#    When found, it sets a flag (`in_block = 1`) to start tracking subkeys.
#
# 2. `/^[[:space:]]+[0-9]+:/ && in_block`
#    Matches indented numeric subkeys (e.g., "  42:") only if we're inside a top-level block.
#    It strips the colon from the field, converts it to a number, and compares it to the current maximum.
#
# 3. `max = $1`
#    Keeps track of the largest number seen under any top-level key.
#
# 4. `END { print max }`
#    At the end of the file, prints the maximum number found.
#####################
function get_num_requests() {
    local yamlfile="$1"
    local num_requests

    num_requests=$(awk '
    /^[^[:space:]]+:/ { in_block = 1; next }
    /^[[:space:]]+[0-9]+:/ && in_block {
        gsub(":", "", $1)
        num = $1 + 0
        if (num > max) max = num
    }
    END { print max+0 }  # +0 ensures numeric output even if max is empty
    ' "$yamlfile")

    echo "$num_requests"
}

#####################
# Manages checkpoints for OPA runs
# INPUT
#    $1: source checkpoint dir
#    $2: space-separated target checkpoint dirs (as passed in opa.sh)
#####################
function copy_checkpoints() {
    local source_dir="$1"
    local checkpoint_list="$2"
    # Always declare as local array to avoid unbound errors under set -u
    local -a target_dirs=()

    # Expect exactly two args as used in templates/opa.sh
    if [ -z "$checkpoint_list" ]; then
        echo "Target checkpoint directories list is missing" >&2
        exit 1
    fi

    # Split space-separated list into array (robust with set -u)
    if [ -n "$checkpoint_list" ]; then
        read -r -a target_dirs <<<"$checkpoint_list" || true
    fi

    # If still empty, nothing to do
    if [ ${#target_dirs[@]} -eq 0 ]; then
        echo "No target checkpoints provided; skipping copy."
        return 0
    fi

    # If source directory does not exist, exit
    if [ ! -d "${source_dir}" ]; then
        echo "Source directory ${source_dir} does not exist" >&2
        exit 1
    fi

    # Create target directories if they don't already exist
    for target_dir in "${target_dirs[@]}"; do
        if [ ! -d "${target_dir}" ]; then
            mkdir -p "${target_dir}"
            echo "Created checkpoint directory: ${target_dir}"
        fi
    done

    # Remove all files from the last target directory
    local last_index=$((${#target_dirs[@]} - 1))
    if [ "$last_index" -ge 0 ]; then
        rm -f "${target_dirs[$last_index]}"/* 2>/dev/null || true
    fi

    # Shift files down through the checkpoint directories (from end-1 to front)
    local idx
    for ((idx = last_index; idx > 0; idx--)); do
        local src="${target_dirs[$((idx - 1))]}"
        local trg="${target_dirs[$idx]}"
        mv "${src}"/* "${trg}/" 2>/dev/null || true
    done

    # Copy from source_dir to the first target_dir
    cp "${source_dir}"/* "${target_dirs[0]}/" 2>/dev/null || true
}
