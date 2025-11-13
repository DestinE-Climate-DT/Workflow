#!/bin/bash

# This step creates the FDB info file, if needed.

# HEADER

CURRENT_ARCH=${1:-%CURRENT_ARCH%}
CREATE_FDB_INFO_FILE=${2:-%CONFIGURATION.CREATE_FDB_INFO_FILE%}
LIBDIR=${3:-%CONFIGURATION.LIBDIR%}

# load_singularity variables
SCRATCH_DIR=${4:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${5:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${6:-%CURRENT_LOCAL_DIR%}

# generate_fdb_info_file variables
EXPVER=${7:-%REQUEST.EXPVER%}
FDB_INFO_FILE_NAME=${8:-%REQUEST.INFO_FILE_NAME%}
AQUA_START_DATE=${9:-%AQUA.START_DATE%}
CONTAINER_COMMAND=${10:-%CURRENT_CONTAINER_COMMAND%}
SIM_START_DATE=${11:-%SDATE%}
SCRIPTDIR=${12:-%CONFIGURATION.SCRIPTDIR%}
CURRENT_ROOTDIR=${13:-%CURRENT_ROOTDIR%}
MODEL=${14:-%REQUEST.MODEL%}
HPC_CONTAINER_DIR=${15:-%CONFIGURATION.CONTAINER_DIR%}
GSV_VERSION=${16:-%GSV.VERSION%}

# END_HEADER

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh

# lib/common/util.sh (generate_fdb_info_file) (auto generated comment)
generate_fdb_info_file ${EXPVER}
