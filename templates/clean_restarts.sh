#!/bin/bash

# This script is used to delete restart files for a specific job chunk in a workflow.

# HEADER

HPC_PROJECT=${1:-%CONFIGURATION.HPC_PROJECT_DIR%}
HPCROOTDIR=${2:-%HPCROOTDIR%}
EXPID=${3:-%DEFAULT.EXPID%}
CURRENT_ARCH=${4:-%CURRENT_ARCH%}
CHUNK=${5:-%CHUNK%}
KEEP_EVERY=${6:-%CONFIGURATION.RESTARTS.KEEP_EVERY%}
KEEP_LAST=${7:-%CONFIGURATION.RESTARTS.KEEP_LAST%}
START_DATE=${8:-%SDATE%}
MEMBER=${9:-%MEMBER%}
LIBDIR=${10:-%CONFIGURATION.LIBDIR%}
ARCHIVE_RESTARTS=${11:-%CONFIGURATION.RESTARTS.ARCHIVE%}
RESTART_BACKUP_PATH=${12:-%CURRENT_RESTARTS_BACKUP_PATH%}
EXPVER=${13:-%REQUEST.EXPVER%}

# END_HEADER

set -xuve

. "${LIBDIR}"/common/utils/clean_restarts_utils.sh

HPC=$(echo ${CURRENT_ARCH} | cut -d- -f1)
RESTART_DIR=${HPCROOTDIR}/restarts/${START_DATE}/${MEMBER}
CHUNK_DIR=${RESTART_DIR}/$((CHUNK + 1))

# lib/common/utils/clean_restarts_utils.sh (delete_restarts) (auto generated comment)
delete_restarts "${RESTART_DIR}" "${KEEP_EVERY}" "${KEEP_LAST}"
