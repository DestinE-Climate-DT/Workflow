#!/bin/bash
#
# This step loads the necessary enviroment and then compiles the diferent models
set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${3:-%CURRENT_ARCH%}
APP=${4:-%APP.NAMES%}
EXPID=${5:-%DEFAULT.EXPID%}
DATELIST=${6:-%EXPERIMENT.DATELIST%}
MEMBERS=${7:-%EXPERIMENT.MEMBERS%}
CHUNK=${8:-%CHUNK%}
INI_DAY=${9:-%CHUNK_START_DAY%}
INI_MONTH=${10:-%CHUNK_START_MONTH%}
INI_YEAR=${11:-%CHUNK_START_YEAR%}
OPA_OUT=${12:-%OPAREQUEST.1.out_filepath%}
CHUNK_START_DATE=${13:-%CHUNK_START_DATE%}
MEMBER=${14:-%MEMBER%}
END_DAY=${15:-%CHUNK_SECOND_TO_LAST_DAY%}
END_MONTH=${16:-%CHUNK_SECOND_TO_LAST_MONTH%}
END_YEAR=${17:-%CHUNK_SECOND_TO_LAST_YEAR%}
JOBNAME=${18:-%JOBNAME%}
SPLIT=${19:-%SPLIT%}
APP_OUTPATH=${20:-%APP.OUTPATH%}
WORKFLOW=${21:-%RUN.WORKFLOW%}
RUN_TYPE=${22:-%RUN.TYPE%}
HPC_PROJECT=${23:-%CONFIGURATION.HPC_PROJECT_DIR%}
HPC_SCRATCH=${24:-%CURRENT_PROJECT_SCRATCH%}
HPC_CONTAINER_DIR=${25:-%CURRENT_CONTAINER_DIR%}
EXPVER=${26:-%REQUEST.EXPVER%}
CLASS=${27:-%REQUEST.CLASS%}
GSV_WEIGHTS_PATH=${28:-%GSV.WEIGHTS_PATH%}
LIBDIR=${29:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${30:-%CONFIGURATION.SCRIPTDIR%}
ENERGY_INDICATORS_VERSION=${31:-%ENERGY_INDICATORS.VERSION%}
GSV_VERSION=${32:-%GSV.VERSION%}
AQUA_VERSION=${33:-%AQUA.VERSION%}
HYDROLAND_VERSION=${34:-%HYDROLAND.VERSION%}
WILDFIRES_WISE_VERSION=${35:-%AQUA.VERSION%}
WILDFIRES_FWI_VERSION=${36:-%WILDFIRES_FWI.VERSION%}
HYDROMET_VERSION=${37:-%HYDROMET.VERSION%}
HPC_CONTAINER_DIR=${38:-%CURRENT_CONTAINER_DIR%}
SPLIT_INI_DAY=${39:-%SPLIT_START_DAY%}
SPLIT_INI_MONTH=${40:-%SPLIT_START_MONTH%}
SPLIT_INI_YEAR=${41:-%SPLIT_START_YEAR%}
SPLIT_END_DAY=${42:-%SPLIT_END_DAY%}
SPLIT_END_MONTH=${43:-%SPLIT_END_MONTH%}
SPLIT_END_YEAR=${44:-%SPLIT_END_YEAR%}
PROJECT=${45:-%CURRENT_PROJECT%}
SPLITS=${46:-%SPLITS%}
FDB_HOME=${47:-%REQUEST.FDB_HOME%} # francesc: needed for Obsall

# END_HEADER

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture

#####################
# run ENERGY_INDICATORS
# GLOBALS:
#       LIBDIR
#####################
function postproc_ENERGY_INDICATORS() {
    echo "energy onshore postproc is none"
}

#####################
# run HYDROMET
# GLOBALS:
#       LIBDIR
#####################
function postproc_HYDROMET() {
    echo "hydromet postproc is none"
}

#####################################################
# Run Hydroland application
######################################################
# defining needed Hydroland variables
function postproc_HYDROLAND() {
    echo "hydroland postproc is none"
}

#####################
# run WILDFIRES_WISE
#####################
function postproc_WILDFIRES_WISE() {
    echo "wise postproc is none"
}

#####################
# run WILDFIRES_FWI
# GLOBALS:
#####################
function postproc_WILDFIRES_FWI() {
    echo "FWI postproc is none"
}

#####################
# run OBSALL
# GLOBALS:
#####################
function postproc_OBSALL() {
    echo "OBSALL postproc is none"
}

APP="${JOBNAME#*POSTPROC_}"

# run postprocessing
postproc_"${APP^^}"
