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
DEFAULT_HPCARCH=${6:-%DEFAULT.HPCARCH%}
SCRATCH_DIR=${7:-%SCRATCH_DIR%}
TRANSFER_USER=${8:-%PLATFORMS.MARENOSTRUM5-TRANSFER.USER%}
TRANSFER_HOST=${9:-%PLATFORMS.MARENOSTRUM5-TRANSFER.HOST%}
TRANSFER_SCRATCH=${10:-%PLATFORMS.MARENOSTRUM5-TRANSFER.SCRATCH_DIR%}
TRANSFER_PROJECT=${11:-%PLATFORMS.MARENOSTRUM5-TRANSFER.PROJECT%}
EXPID=${12:-%DEFAULT.EXPID%}
SYNC_DATAMOVER=${13:-%HPCSYNC_DATAMOVER%}
AQUA_ON=${14:-%CONFIGURATION.ADDITIONAL_JOBS.AQUA%}

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
    USR=$1
    HOST=$2
    SOURCE=$3
    DIR=$4

    rsync -avp "${SOURCE}" "${USR}"@"${HOST}":"${DIR}"/
}

# MAIN code

cd "${ROOTDIR}"/proj
. "${ROOTDIR}"/proj/${PROJDEST}/lib/${DEFAULT_HPCARCH}/config.sh

flag_tarball_path="${ROOTDIR}"/flag_tarball_sent

# If the tar was already sent, we assume that we can update only the changed files in the project
# The workflow will send the tarball again if the workflow starts over from LOCAL_SETUP
if [ ! -f ${flag_tarball_path} ]; then
    # First time, send the tarballs (project and catalog)
    echo "Sending the tarball to the remote platform"
    rsync_to_remote "${HPCUSER}" "${HPCHOST}" "${ROOTDIR}/proj/${PROJDEST}.tar.gz" "${HPCROOTDIR}"
    rm "${ROOTDIR}/proj/${PROJDEST}.tar.gz"
    if [ "${AQUA_ON,,}" == "true" ]; then
        rsync_to_remote "${HPCUSER}" "${HPCHOST}" "${ROOTDIR}/tmp/catalog.tar.gz" "${HPCROOTDIR}"
        rm "${ROOTDIR}/tmp/catalog.tar.gz"
    fi
    touch ${flag_tarball_path}
else
    echo "The tarball was already sent, skipping tarball sending step. Only rsyncing the project directory"
    # If the tarball was already sent, we can just rsync the project and catalog directories
    rsync_to_remote "${HPCUSER}" "${HPCHOST}" "${ROOTDIR}/proj/${PROJDEST}" "${HPCROOTDIR}"
    if [ "${AQUA_ON,,}" == "true" ]; then
        rsync_to_remote "${HPCUSER}" "${HPCHOST}" "${ROOTDIR}/tmp/catalog" "${HPCROOTDIR}"
    fi
fi

if [ "${SYNC_DATAMOVER,,}" == "true" ]; then
    echo "Syncing the project to the remote platform"
    # lib/LUMI/config.sh (rsync_datamover) (auto generated comment)
    # lib/MARENOSTRUM5/config.sh (rsync_datamover) (auto generated comment)
    rsync_datamover ${TRANSFER_USER} ${TRANSFER_HOST} ${PROJDEST} ${TRANSFER_SCRATCH} ${TRANSFER_PROJECT} ${EXPID}

else
    echo "Transfer is disabled, skipping synchronize step"
fi
