#!/bin/bash

# This step loads the FDB config file, if needed.

# HEADER

LIBDIR=${1:-%CONFIGURATION.LIBDIR%}
RUN_TYPE=${2:-%RUN.TYPE%}
LOAD_FDB=${3:-%CONFIGURATION.LOAD_FDB%}
MODEL_NAME=${4:-%MODEL.NAME%}

# load_fdb_"${ATM_MODEL}" variables
MODEL_VERSION=${5:-%MODEL.VERSION%}
HPCROOTDIR=${6:-%HPCROOTDIR%}
PROJDEST=${7:-%PROJECT.PROJECT_DESTINATION%}
MODEL_PATH=${8:-%MODEL.PATH%}
FDB_HOME=${9:-%REQUEST.FDB_HOME%}
EXPID=${10:-%DEFAULT.EXPID%}
SIM_START_DATE=${11:-%SDATE%}
SCRIPTDIR=${12:-%CONFIGURATION.SCRIPTDIR%}

# END_HEADER

# Source libraries
. "${LIBDIR}"/common/utils/remote_setup_utils.sh

# Creates fake production fdb if not in production, research or operational
if [[ ! ${RUN_TYPE,,} =~ ^(production|research|operational|operational-read)$ ]]; then
    if [[ ${LOAD_FDB,,} == "true" ]]; then
        ATM_MODEL=${MODEL_NAME%%-*}
        load_fdb_"${ATM_MODEL}"
    fi
fi
