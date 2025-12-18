#!/bin/bash

# Utils functions for opa.sh

#####################
# Runs OPA runscript (with GSV Interface and One_Pass in it)
#    Note: No support for multiple startdates as of now.
#          Therefore, datelist equates to startdate, i.e. a string with a single value.
# INPUT
#    1. mpi_num_procs
#    2. request directory
#    3. chunk
#    4. split
#    5. expid
#    6. app_name
#    7. run_type
#    8. realization
#    9. datelist (or startdate)
#    10. request_number
#    11. restart_dir
#####################
function run_OPA() {

    mpi_num_procs=$1
    request_dir="${2}"
    restart_dir="${11}"

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

    if [ -d "${BA_AUX}" ]; then
        echo "The directory ${BA_AUX} does not contain any BA file and therefore the bias adjustment will not be applied."
        BA_AUX="$SCRIPTDIR" #Shfmt does not like having it empty
    fi

    if [[ -n "${mpi_num_procs}" && "${mpi_num_procs}" -gt 1 ]]; then
        mpirun_args=(mpirun --np "${mpi_num_procs}")
    else
        mpirun_args=()
    fi
    bind_args=(
        --bind "${SCRIPTDIR}/opa/"
        --bind "${FDB_HOME}"
        --bind "${LOGDIR}"
        --bind "${OPA_OUTPATH}"
        --bind "${PYTHONPATH}"
        --bind "${BA_AUX}"
        --bind "${APP_AUX_IN_DATA_DIR}"
        --bind "${DEVELOPMENT_PROJECT_SCRATCH}"
        --bind "${OPERATIONAL_PROJECT_SCRATCH}"
        --bind "${request_dir}"
        --bind "${restart_dir}"
    )
    env_args=(
        --env "request_dir=${request_dir}"
        --env "restart_dir=${restart_dir}"
        --env "chunk=$3"
        --env "split=$4"
        --env "expid=$5"
        --env "app_name=$6"
        --env "run_type=$7"
        --env "member=$8"
        --env "startdate=$9"
        --env "request_number=${10}"
        --env "outpath=${OPA_OUTPATH}"
        --env "realization=${REALIZATION}"
        --env "PYTHONPATH=${PYTHONPATH}"
        --env "FDB_HOME=${FDB_HOME}"
        --env "SCRIPTDIR=${SCRIPTDIR}"
        --env "READ_FROM_DATABRIDGE=${READ_FROM_DATABRIDGE}"
        --env "PYTHONNOUSERSITE=1"
        --env "GSV_WEIGHTS_PATH=${GSV_WEIGHTS_PATH}"
        --env mask_file="${MASK_FILE}"
    )
    runscript_args=(
        --request_dir "${request_dir}"
        --chunk "${3}"
        --split "${4}"
        --expid "${5}"
        --app_name "${6}"
        --member "${8}"
        --realization "${REALIZATION}"
        --startdate "${9}"
        --request_number "${10}"
        --read_from_databridge "${READ_FROM_DATABRIDGE}"
        --restart_dir "${restart_dir}"
        --outpath "${OPA_OUTPATH}"
        --mask_file "${MASK_FILE}"
        --log_level "${OPA_LOG_LEVEL}"
    )
    container="${HPC_CONTAINER_DIR}/one_pass/one_pass_${OPA_VERSION}.sif"

    cd "${SCRIPTDIR}/opa/" || exit

    # Build the execution command inside the container
    if [[ ${#mpirun_args[@]} -gt 0 ]]; then
        exec_cmd=("${mpirun_args[@]}" python3 "${SCRIPTDIR}/opa/run_opa.py" "${runscript_args[@]}")
    else
        exec_cmd=(python3 "${SCRIPTDIR}/opa/run_opa.py" "${runscript_args[@]}")
    fi

    # Command and arguments
    cmd=(
        singularity exec
        --cleanenv
        --no-home
        "${bind_args[@]}"
        "${env_args[@]}"
        "${container}"
        "${exec_cmd[@]}"
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
# detect_mpi_proc
# GLOBALS
#   OPA_MPI_PROC
#   OPA_MPI_STATS (as an array of strings)
# INPUT
#   yamlfile
#   appname
#   reqnum
#####################
function detect_mpi_proc() {

    yamlfile="${1}"
    appname="${2}"
    reqnum="${3}"

    # Extract the value manually using awk (no yq)
    stat_value=$(
        awk -v app="$appname" -v req="$reqnum" '
      /^[^[:space:]]/ {            # level 0 key (like APP_1:)
        gsub(":$", "", $1)
        app_found = ($1 == app)
        req_found = 0
        next
      }
      /^[[:space:]]{2}[^[:space:]]/ && app_found {   # level 1 key (like "  1:")
        key=$1
        gsub(":", "", key)
        req_found = (key == req)
        opa_found = 0
        next
      }
      /^[[:space:]]{4}OPAREQUEST:/ && app_found && req_found {  # level 2 key
        opa_found = 1
        next
      }
      /^[[:space:]]{6}stat:/ && app_found && req_found && opa_found {
        # extract the value after 'stat:'
        sub(/^[[:space:]]*stat:[[:space:]]*/, "")
        gsub(/"/, "", $0)
        print $0
        exit
      }
    ' "${yamlfile}"
    )

    if [[ -z "$stat_value" ]]; then
        echo "Warning:" >&2
        echo "When reading from" >&2
        echo "    $yamlfile," >&2
        echo "to identify number of OPA MPI processes," >&2
        echo "could not find stat value at" >&2
        echo "    $appname.$reqnum.OPAREQUEST.stat" >&2
        # Output 1 to indicate a single MPI process
        echo 1
        return
    fi

    # Check if stat_value is in TARGET_STATS
    found=false
    for s in "${OPA_MPI_STATS[@]}"; do
        if [[ "$s" == "$stat_value" ]]; then
            found=true
            break
        fi
    done

    if [[ "$found" == true ]]; then
        echo "${OPA_MPI_PROC}"
    else
        echo 1
    fi

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
