#!/bin/bash
#
# This step is in charge of downloading workflow results from Marenostrum5
# and syncing them to the datamover

set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
ROOTDIR=${2:-%ROOTDIR%}
HPCUSER=${3:-%HPCUSER%}
HPCHOST=${4:-%HPCHOST%}
PROJDEST=${5:-%PROJECT.PROJECT_DESTINATION%}
DEFAULT_HPCARCH=${6:-%DEFAULT.HPCARCH%}
SCRATCH_DIR=${7:-%SCRATCH_DIR%}
TRANSFER_USER=${8:-%PLATFORMS.MARENOSTRUM5-TRANSFER.USER%}
TRANSFER_HOST=${9:-%PLATFORMS.MARENOSTRUM5-TRANSFER.HOST%}
TRANSFER_SCRATCH=${10:-%PLATFORMS.MARENOSTRUM5-TRANSFER.SCRATCH_DIR%}
TRANSFER_PROJECT=${11:-%PLATFORMS.MARENOSTRUM5-TRANSFER.PROJECT%}
EXPID=${12:-%DEFAULT.EXPID%}
REQUESTS_DIR=${13:-%CONFIGURATION.DATAFLOW.REQUESTS_DIR%}

# END_HEADER

####################################################
# Clean previous requests, both from local and remote
# Globals:
# Arguments:
#   Remote user
#   Target host
#   Remote requests directory
#   Local requests directory
#####################################################
function clean_previous_requests() {
    local USR="$1"
    local HOST="$2"
    local REMOTE_DIR="$3"
    local LOCAL_DIR="$4"

    if [[ -n "$REMOTE_DIR" && "$REMOTE_DIR" != "/" ]]; then
        ssh "${USR}@${HOST}" "rm -rf \"${REMOTE_DIR}\"/*"
    else
        echo "Skipping remote cleanup: invalid REMOTE_DIR"
    fi

    if [[ -n "$LOCAL_DIR" && "$LOCAL_DIR" != "/" ]]; then
        rm -rf "${LOCAL_DIR}"/*
    else
        echo "Skipping local cleanup: invalid LOCAL_DIR"
    fi
}

# MAIN code

cd "${ROOTDIR}"/proj
. "${ROOTDIR}"/proj/${PROJDEST}/lib/${DEFAULT_HPCARCH}/config.sh

LOCAL_REQUESTS_DIR="${ROOTDIR}/requests"
DATAMOVER_REQUESTS_DIR=${TRANSFER_SCRATCH}/${TRANSFER_PROJECT}/${TRANSFER_USER}/${EXPID}/requests

# Clean previous requests
clean_previous_requests "${HPCUSER}" "${HPCHOST}" "${DATAMOVER_REQUESTS_DIR}" "${LOCAL_REQUESTS_DIR}"
