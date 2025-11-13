#!/bin/bash

# This step generates the profiles, if needed.

# HEADER

LIBDIR=${1:-%CONFIGURATION.LIBDIR%}
CURRENT_ARCH=${2:-%CURRENT_ARCH%}
MODEL_NAME=${3:-%MODEL.NAME%}
GENERATE_PROFILES=${4:-%CONFIGURATION.GENERATE_PROFILES%}

# load_singularity variables
SCRATCH_DIR=${5:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${6:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${7:-%CURRENT_LOCAL_DIR%}

# generate_profiles variables
CURRENT_ROOTDIR=${8:-%CURRENT_ROOTDIR%}
PROJDEST=${9:-%PROJECT.PROJECT_DESTINATION%}
DQC_PROFILE_ROOT=${10:-%CONFIGURATION.DQC_PROFILE_ROOT%}
CONTAINER_COMMAND=${11:-%CURRENT_CONTAINER_COMMAND%}
DATA_PORTFOLIO=${12:-%CONFIGURATION.DATA_PORTFOLIO%}
DQC_PROFILE=${13:-%CONFIGURATION.DQC_PROFILE%}
HPC_CONTAINER_DIR=${14:-%CONFIGURATION.CONTAINER_DIR%}
GSV_VERSION=${15:-%GSV.VERSION%}

# END_HEADER

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh

if [ "${MODEL_NAME,,}" != "nemo" ]; then
    # lib/LUMI/config.sh (load_singularity) (auto generated comment)
    # lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
    load_singularity
    # lib/common/util.sh (generate_profiles) (auto generated comment)
    generate_profiles
fi
