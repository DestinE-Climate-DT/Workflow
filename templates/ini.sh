#!/bin/bash
#
# This step prepares any necessary initial data for the climate model runs 
set -xuve

# Interface
HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL_NAME=${3:-%RUN.MODEL%}
CURRENT_ARCH=${4:-%CURRENT_ARCH%}
expver=${5:-%CONFIGURATION.IFS.EXPVER%}
label=${6:-%CONFIGURATION.IFS.LABEL%}
SDATE=${7:-%SDATE%00}
ATM_GRID=${8:-%RUN.GRID_ATM%}
OCEAN_GRID=${9:-%RUN.GRID_OCEAN%}
CLEAN_RUN=${10:-%RUN.CLEAN_RUN%}

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$( echo "${CURRENT_ARCH}" | cut -d- -f1 )

ATM_MODEL=${MODEL_NAME%%-*}
OCEAN_MODEL=${MODEL_NAME##*-}


# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh

# Main code

# Eliminates simulation restarts for clean new run

if [ "$CLEAN_RUN" = "true" ]; then
	rm_restarts_"${ATM_MODEL}"
fi
