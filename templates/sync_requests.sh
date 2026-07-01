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

#####################################################
# Synchronizes file or directory *from* remote
# Globals:
# Arguments:
#   Remote user
#   Target host
#   Remote file or directory
#   Local directory
#####################################################
function rsync_from_remote() {
    USR=$1
    HOST=$2
    REMOTE=$3
    LOCAL=$4

    rsync -avp "${USR}"@"${HOST}":"${REMOTE}" "${LOCAL}"/
}

#####################################################
# Synchronizes file or directory to remote
# Globals:
# Arguments:
#   Remote user
#   Target host
#   Source file or directory
#   Target directory
#####################################################
function rsync_to_remote() {
    USR=$1
    HOST=$2
    SOURCE=$3
    DIR=$4

    rsync -avp "${SOURCE}" "${USR}"@"${HOST}":"${DIR}"/
}

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
    USR=$1
    HOST=$2
    REMOTE_DIR=$3
    LOCAL_DIR=$4
    ssh "${USR}"@"${HOST}" "rm -rf ${REMOTE_DIR}/*"
    rm -rf "${LOCAL_DIR}"/*
}

# MAIN code

cd "${ROOTDIR}"/proj
. "${ROOTDIR}"/proj/${PROJDEST}/lib/${DEFAULT_HPCARCH}/config.sh

LOCAL_REQUESTS_DIR="${ROOTDIR}/requests"
DATAMOVER_REQUESTS_DIR=${TRANSFER_SCRATCH}/${TRANSFER_PROJECT}/${TRANSFER_USER}/${EXPID}/requests

# Clean previous requests
clean_previous_requests "${HPCUSER}" "${HPCHOST}" "${DATAMOVER_REQUESTS_DIR}" "${LOCAL_REQUESTS_DIR}"

mkdir -p "${LOCAL_REQUESTS_DIR}"

echo "Downloading results from Marenostrum5"
rsync_from_remote "${HPCUSER}" "${HPCHOST}" "${REQUESTS_DIR}" "${LOCAL_REQUESTS_DIR}"

echo "Syncing the results to the datamover"
# lib/MARENOSTRUM5/config.sh (rsync_datamover) (auto generated comment)
# lib/LUMI/config.sh (rsync_datamover) (auto generated comment)
rsync_datamover ${TRANSFER_USER} ${TRANSFER_HOST} "${LOCAL_REQUESTS_DIR}" ${TRANSFER_SCRATCH} ${TRANSFER_PROJECT} ${EXPID}
