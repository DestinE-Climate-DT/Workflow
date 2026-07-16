#!/bin/bash

# Utils functions for clean_restarts.sh

#####################################################
# Validates inputs required for restart deletion.
# Exits with an error if any argument is not safely set.
# Arguments:
#   1 - restart_dir: path to the restart directory
#   2 - keep_every:  positive integer, keep every N-th restart
#   3 - keep_last:   positive integer, always keep the last N restarts
#####################################################
function validate_clean_restarts_inputs() {
    local restart_dir="$1"
    local keep_every="$2"
    local keep_last="$3"

    if [ -z "${restart_dir}" ]; then
        echo "ERROR: RESTART_DIR is not set." >&2
        exit 1
    fi

    # Neither relative paths nor "/" are acceptable restart_dirs.
    # This check must run on the raw input, before realpath -m, which would
    # otherwise turn a relative path into an absolute one and bypass this guard.
    if [[ -z ${restart_dir} ||
        ! ${restart_dir} =~ ^/ ||
        ${restart_dir} == "/" ]]; then
        echo "ERROR: Unsafe RESTART_DIR: '${restart_dir}'" >&2
        exit 1
    fi

    restart_dir=$(realpath -m -- "${restart_dir}")

    if [ ! -d "${restart_dir}" ]; then
        echo "WARNING: RESTART_DIR '${restart_dir}' does not exist. Nothing to do."
        return 1
    fi

    if [ -z "${keep_every}" ]; then
        echo "ERROR: KEEP_EVERY is not set." >&2
        exit 1
    fi

    if ! [[ "${keep_every}" =~ ^[0-9]+$ ]] || [ "${keep_every}" -eq 0 ]; then
        echo "ERROR: KEEP_EVERY must be a positive integer, got '${keep_every}'. Keeping all restarts." >&2
        exit 1
    fi

    if [ -z "${keep_last}" ]; then
        echo "ERROR: KEEP_LAST is not set." >&2
        exit 1
    fi

    if ! [[ "${keep_last}" =~ ^[0-9]+$ ]] || [ "${keep_last}" -eq 0 ]; then
        echo "ERROR: KEEP_LAST must be a positive integer, got '${keep_last}'. Keeping all restarts." >&2
        exit 1
    fi
}

#####################################################
# If any restarts can be deleted, deletes them.
# Validates inputs before any deletion. Keeps restarts
# by default; only deletes when explicitly safe.
# Arguments:
#   1 - restart_dir: path to the restart directory
#   2 - keep_every:  positive integer, keep every N-th restart
#   3 - keep_last:   positive integer, always keep the last N restarts
#####################################################
function delete_restarts() {
    local restart_dir="$1"
    local keep_every="$2"
    local keep_last="$3"

    validate_clean_restarts_inputs "${restart_dir}" "${keep_every}" "${keep_last}" || return 0

    chunk_dirs=($(find "${restart_dir}" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort -n))

    local total=${#chunk_dirs[@]}
    local dirs_to_remove=()

    for i in "${!chunk_dirs[@]}"; do
        dir="${chunk_dirs[$i]}"

        # Always keep the first restart
        if (($dir == 1)); then
            continue
        # Keep restarts at keep_every interval
        elif ((($dir - 1) % keep_every == 0)); then
            continue
        # Keep the last N restarts
        elif ((total - i <= keep_last)); then
            continue
        fi

        # Explicitly mark for removal
        dirs_to_remove+=("$dir")
    done

    for dir in "${dirs_to_remove[@]}"; do
        if [ -d "${restart_dir}/${dir}" ]; then
            echo "Deleting restart ${restart_dir}/$dir."
            rm -rf "${restart_dir}/${dir}"
        else
            echo "WARNING: expected restart dir '${restart_dir}/${dir}' not found, skipping."
        fi
    done
}
