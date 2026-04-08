#!/bin/bash

# This step installs AQUA

set -xuve

# HEADER

CURRENT_ARCH=${1:-%CURRENT_ARCH%}
LIBDIR=${2:-%CONFIGURATION.LIBDIR%}
AQUA_ON=${3:-%CONFIGURATION.ADDITIONAL_JOBS.AQUA%}
HPC_CONTAINER_DIR=${4:-%CURRENT_CONTAINER_DIR%}
CONTAINER_VERSION=${5:-%AQUA.CONTAINER_VERSION%}

# load_singularity variables
SCRATCH_DIR=${6:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${7:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${8:-%CURRENT_LOCAL_DIR%}

# install_aqua variables
HPCROOTDIR=${9:-%HPCROOTDIR%}
AQUA_REGENCAT=${10:-%AQUA.REGENERATE_CATALOGS%}
HPCARCH_short=${11:-%CURRENT_HPCARCH_SHORT%}
PROJDEST=${12:-%PROJECT.PROJECT_DESTINATION%}
CATALOG_NAME=${13:-%HPCCATALOG_NAME%}
EXPID=${14:-%DEFAULT.EXPID%}
EXPVER=${15:-%REQUEST.EXPVER%}
MODEL=${16:-%REQUEST.MODEL%}
DATA_PORTFOLIO=${17:-%CONFIGURATION.DATA_PORTFOLIO%}
SIM_START_DATE=${18:-%SDATE%}
USER=${19:-%CURRENT_USER%}
AQUA_CONFIG=${20:-%AQUA.INSTALL_DIR%}
AQUA_START_DATE=${21:-%AQUA.START_DATE%}
GRID_BUILD_ENABLED=${22:-%CONFIGURATION.ADDITIONAL_JOBS.AQUA_GRID_BUILD%}
AQUA_GRID_ATM=${23:-%AQUA.GRID_ATM%}
MODEL_NAME_LOWER=${24:-%MODEL.NAME%}
DQC_PROFILE=${25:-%CONFIGURATION.DQC_PROFILE%}
GRID_OCE=${26:-%AQUA.GRID_OCE%}

# END_HEADER

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/utils/remote_setup_utils.sh

if [ "${AQUA_ON,,}" == "true" ]; then
    AQUA="/app/AQUA"
    AQUA_CONTAINER="${HPC_CONTAINER_DIR}/aqua/aqua_${CONTAINER_VERSION}.sif"
    # lib/LUMI/config.sh (load_singularity) (auto generated comment)
    # lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
    load_singularity
    # lib/common/utils/remote_setup_utils.sh (install_aqua) (auto generated comment)
    install_aqua ${AQUA_CONFIG} ${GRID_BUILD_ENABLED} ${AQUA_GRID_ATM} ${MODEL_NAME_LOWER} ${DQC_PROFILE} ${GRID_OCE}
fi
