#!/bin/bash
#
# This step prepares any necessary initial data for the climate model runs 
set -xuve

# Interface
HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL_NAME=${3:-%MODEL.NAME%}
CURRENT_ARCH=${5:-%CURRENT_ARCH%}

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$( echo "${CURRENT_ARCH}" | cut -d- -f1 )

ATM_MODEL=${MODEL_NAME%%-*}
OCEAN_MODEL=${MODEL_NAME##*-}

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh

# Main code

# Eliminates simulation restarts for clean new run
rm_restarts_"${ATM_MODEL}"

