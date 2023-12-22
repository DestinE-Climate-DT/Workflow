#!/bin/bash
#

# This step runs the Ona PASS algorithm, after the data notifier is finished
set -xuve 

# Interface
HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL=${3:-%MODEL.MODEL_NAME%}
MODEL_SOURCE=${4:-%MODEL.SOURCE%}
MODEL_BRANCH=${5:-%MODEL.BRANCH%}
CURRENT_ARCH=${6:-%CURRENT_ARCH%}
PRECOMP_MODEL_PATH=${7:-%MODEL.PRECOMP_MODEL_PATH%}
APP=${8:-%RUN.APP%}
EXPID=${9:-%DEFAULT.EXPID%}
DATELIST=${10:-%EXPERIMENT.DATELIST%}
MEMBERS=${11:-%EXPERIMENT.MEMBERS%}
CHUNK=${12:-%CHUNK%}
CHUNK_START_DATE=${18:-%CHUNK_START_DATE%}
SPLIT=${13:-%SPLIT%}
JOBNAME=${14:-%JOBNAME%}
OUTDIR=${15:-%APP.OUTPATH%}
READ_EXPID=${16:-%RUN.READ_EXPID%}

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$( echo ${CURRENT_ARCH} | cut -d- -f1 )

#####################
# get current app date
# GLOBALS:
#       CHUNK_START_DATE
#       SPLIT
#####################
get_current_date() {
    # Assuming $CHUNK_START_DATE is in the format YYYYMMDD
    # and $SPLIT is a number you want to add to it
    increment=$((SPLIT-1))
    CURRENT_DATE=$(date -d "$CHUNK_START_DATE + $increment days" "+%Y%m%d")
    export CURRENT_DATE
}


#####################
# run OPA
# INPUT
#    request file
#    output directory
#####################
function run_OPA() {
    if [ ! -d "$2" ]; then
        mkdir -p "$2"
        echo "Directory created: $2"
    else
        echo "Directory already exists: $2"
    fi
    python ${LIBDIR}/runscript/run_opa.py -request $1
}

#TODO: needed if already loaded in remote setup?
# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh

#load env
load_dirs
load_environment_gsv $HPC_PROJECT $READ_EXPID
load_environment_opa #(currently it is the same as gsv interface invirnment but we keep it for formality)

get_current_date

# declare opaname
OPA_NAME=${JOBNAME#*OPA_}

#declare filenames for opa and gsv requests
REQUEST_PATTERN=${HPCROOTDIR}/git_project/lib/runscript/request_${CURRENT_DATE}_0000_*${OPA_NAME,,}.yml

# Get the oldest file matching the pattern
REQUEST_FILE=$(ls -tr $REQUEST_PATTERN 2>/dev/null | head -1)

#run opa
run_OPA ${REQUEST_FILE} ${OUTDIR}

#change name so next opa instances dont get it

cp ${REQUEST_FILE} ${REQUEST_FILE}_used # tmp, for testing purposes
