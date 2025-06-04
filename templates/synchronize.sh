#!/bin/bash
#
# This step is in charge of syncing the workflow project with the remote platform

set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
ROOTDIR=${2:-%ROOTDIR%}
HPCUSER=${3:-%HPCUSER%}
HPCHOST=${4:-%HPCHOST%}
PROJDEST=${5:-%PROJECT.PROJECT_DESTINATION%}
DEFAULT_HPCARCH=${6:-%DEFAULT_HPCARCH%}
SCRATCH_DIR=${7:-%SCRATCH_DIR%}
TRANSFER_USER=${8:-%PLATFORMS.MARENOSTRUM5-TRANSFER.USER%}
TRANSFER_HOST=${9:-%PLATFORMS.MARENOSTRUM5-TRANSFER.HOST%}
TRANSFER_SCRATCH=${10:-%PLATFORMS.MARENOSTRUM5-TRANSFER.SCRATCH_DIR%}
TRANSFER_PROJECT=${11:-%PLATFORMS.MARENOSTRUM5-TRANSFER.PROJECT%}
EXPID=${12:-%DEFAULT.EXPID%}

# END_HEADER

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
    echo "rsyncing the dir to the target platform"
    USR=$1
    HOST=$2
    SOURCE=$3
    DIR=$4

    rsync -avp "${SOURCE}" "${USR}"@"${HOST}":"${DIR}"/
}

# MAIN code

cd "${ROOTDIR}"/proj
. "${ROOTDIR}"/proj/${PROJDEST}/lib/${DEFAULT_HPCARCH}/config.sh

# If the tar was already sent, we assume that we can update only the changed files in the project
# The workflow will send the tarball again if the workflow starts over from LOCAL_SETUP
if [ ! -f flag_tarball_sent ]; then
    rsync_to_remote "${HPCUSER}" "${HPCHOST}" "${PROJDEST}".tar.gz "${HPCROOTDIR}"
    rm "${PROJDEST}".tar.gz
    touch flag_tarball_sent
else
    rsync_to_remote "${HPCUSER}" "${HPCHOST}" "${PROJDEST}" "${HPCROOTDIR}"
fi

# lib/LUMI/config.sh (rsync_datamover) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (rsync_datamover) (auto generated comment)
rsync_datamover ${TRANSFER_USER} ${TRANSFER_HOST} ${PROJDEST} ${TRANSFER_SCRATCH} ${TRANSFER_PROJECT} ${EXPID}
