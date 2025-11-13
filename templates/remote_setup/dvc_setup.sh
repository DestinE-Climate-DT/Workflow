#!/bin/bash

# This step checks out the DVC inputs, if needed.

# HEADER

CURRENT_ARCH=${1:-%CURRENT_ARCH%}
LIBDIR=${2:-%CONFIGURATION.LIBDIR%}
DVC_INPUTS_BRANCH=${3:-%MODEL.DVC_INPUTS_BRANCH%}
DVC_INPUTS_CACHE=${4:-%CURRENT_DVC_INPUTS_CACHE%}

# load_singularity variables
SCRATCH_DIR=${5:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${6:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${7:-%CURRENT_LOCAL_DIR%}

# inputs_dvc_checkout variables
HPCROOTDIR=${8:-%HPCROOTDIR%}
PROJDEST=${9:-%PROJECT.PROJECT_DESTINATION%}
HPC_CONTAINER_DIR=${10:-%CONFIGURATION.CONTAINER_DIR%}
DVC_VERSION=${11:-%DVC.VERSION%}

USE_DVC=${12:-%MODEL.USE_DVC%}

# END_HEADER

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/utils/remote_setup_utils.sh

# the job is always on by default but it's possible for the user to override it in the main.yml
if [ "${USE_DVC,,}" == "true" ]; then
    if [ -n "${DVC_INPUTS_BRANCH}" ]; then
        # lib/LUMI/config.sh (load_singularity) (auto generated comment)
        # lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
        load_singularity
        # lib/common/utils/remote_setup_utils.sh (inputs_dvc_checkout) (auto generated comment)
        inputs_dvc_checkout ${DVC_INPUTS_CACHE}
    fi
fi
