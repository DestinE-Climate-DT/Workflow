#!/bin/bash

# Utils functions for clean_restarts.sh

#####################################################
# If any restarts can be deleted, deletes them.
# Globals:
#   CHUNK
#   KEEP_EVERY
#   KEEP_LAST
#   RESTART_DIR
# Arguments:
#####################################################
function delete_restarts() {

    chunk_dirs=($(find "${RESTART_DIR}" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort -n))

    for dir in "${chunk_dirs[@]}"; do
        if (($dir == 1)); then
            continue
        elif ((($dir - 1) % KEEP_EVERY == 0)); then
            continue
        fi

        # if it doesn't meet any of the keep conditions, delete it
        echo "Deleting restart $dir."
        rm -rf "$RESTART_DIR/$dir"
    done
}
