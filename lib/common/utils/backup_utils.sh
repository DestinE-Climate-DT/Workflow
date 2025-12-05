#!/bin/bash

# Utils functions for backup.sh

#####################################################
# Determines whether to back up a restart directory.
# Globals:
#   CHUNK
#   KEEP_EVERY
#####################################################
function determine_should_backup() {
    if ((CHUNK == 1)); then
        echo "true"
    elif [ -z "${KEEP_EVERY}" ]; then
        echo "false"
    elif (((CHUNK - 1) % KEEP_EVERY == 0)); then
        echo "true"
    else
        echo "false"
    fi
}
