#!/bin/bash
#
# This step loads the necessary environment and then compiles the different models
set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
MODEL_NAME=${2:-%MODEL.NAME%}
CURRENT_ARCH=${3:-%CURRENT_ARCH%}
MODEL_VERSION=${4:-%MODEL.VERSION%}
ATM_GRID=${5:-%MODEL.GRID_ATM%}
IFS_EXPVER=${6:-%CONFIGURATION.IFS.EXPVER%}
IFS_LABEL=${7:-%CONFIGURATION.IFS.LABEL%}
ICMCL=${8:-%MODEL.ICMCL_PATTERN%}
MODEL_PATH=${9:-%MODEL.PATH%}
MODEL_INPUTS=${10:-%MODEL.INPUTS%}
COMPILE=${11:-%MODEL.COMPILE%}
LIBDIR=${12:-%CONFIGURATION.LIBDIR%}
START_DATE=${13:-%SDATE%}
PROJDEST=${14:-%PROJECT.PROJECT_DESTINATION%}
INPROOT_CHECKER=${15:-%CONFIGURATION.INPROOT_CHECKER%}

# Load ICON grid identifiers
ATM_GID=${16:-%CONFIGURATION.ICON.ATM_GID%}
OCE_GID=${17:-%CONFIGURATION.ICON.OCE_GID%}

# Load ICON grid res
ATM_GRID_REF=${18:-%CONFIGURATION.ICON.ATM_REF%}
OCE_GRID_REF=${19:-%CONFIGURATION.ICON.OCE_REF%}

# END_HEADER

YEAR=${START_DATE::4}
ICMCL=${ICMCL:-ICMCL_%CONFIGURATION.IFS.RESOL%_${YEAR}_extra}

export MODEL_VERSION
export HPCROOTDIR

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture
cd "$HPCROOTDIR"

# If tarfile exists in remote filesystem it's uncompressed
# Untar
if [ -f "${PROJDEST}".tar.gz ]; then
    tar xf "${PROJDEST}".tar.gz
fi

# Source libraries
. "${LIBDIR}"/common/checkers.sh

# Checker
# lib/common/checkers.sh (checker_precompiled_model) (auto generated comment)
checker_precompiled_model

if [ "${INPROOT_CHECKER,,}" == "true" ]; then
    # lib/common/checkers.sh (manually generated comment)
    checker_inproot_"${MODEL_NAME}"
fi
