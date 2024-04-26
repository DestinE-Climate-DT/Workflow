#!/bin/bash
#

# This step runs the Ona PASS algorithm, after the data notifier is finished
set -xuve

# Interface
HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${3:-%CURRENT_ARCH%}
APP=${4:-%APP.NAMES%}
EXPID=${5:-%DEFAULT.EXPID%}
DATELIST=${6:-%EXPERIMENT.DATELIST%}
MEMBERS=${7:-%EXPERIMENT.MEMBERS%}
CHUNK=${8:-%CHUNK%}
CHUNK_START_DATE=${9:-%CHUNK_START_DATE%}
SPLIT=${10:-%SPLIT%}
JOBNAME=${11:-%JOBNAME%}
OUTDIR=${12:-%APP.OUTPATH%}
READ_EXPID=${13:-%APP.READ_EXPID%}
FDB_DIR=${14:-%CURRENT_FDB_DIR%}
PRODUCTION=${15:-%RUN.PRODUCTION%}
WORKFLOW=${16:-%RUN.WORKFLOW%}
HPC_FDB_HOME=${17:-%CURRENT_FDB_PROD%}
SPLITS=${18:-%JOBS.DN.SPLITS%}
READ_FROM_DATABRIDGE=${16:-%APP.READ_FROM_DATABRIDGE%}
READ_FROM_DATABRIDGE=${READ_FROM_DATABRIDGE:-"False"}
DATABRIDGE_FDB_HOME=${17:-%CURRENT_DATABRIDGE_FDB_HOME%}

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$(echo ${CURRENT_ARCH} | cut -d- -f1)

if [ "${PRODUCTION,,}" == "true" ]; then
    READ_EXPID="0001"
elif [ "${WORKFLOW}" == "end-to-end" ]; then
    READ_EXPID="$EXPID"
fi

#####################
# get current app date
# GLOBALS:
#       CHUNK_START_DATE
#       SPLIT
#####################
get_current_date() {
    # Assuming $CHUNK_START_DATE is in the format YYYYMMDD
    # and $SPLIT is a number you want to add to it
    increment=$((SPLIT - 1))
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
    python "${LIBDIR}"/runscript/run_opa.py -request "$1" -read_from_databridge "${READ_FROM_DATABRIDGE}"
}

#TODO: needed if already loaded in remote setup?
# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh

#load env
load_dirs
load_environment_gsv "${FDB_DIR}" "${READ_EXPID}"
load_environment_opa #(currently it is the same as gsv interface invirnment but we keep it for formality)

if [ "${PRODUCTION,,}" = "true" ]; then
    unset FDB5_CONFIG_FILE
    export FDB_HOME=${HPC_FDB_HOME}
fi

if [ "${READ_FROM_DATABRIDGE,,}" == "true" ]; then
    unset FDB5_CONFIG_FILE
    export PATH=/users/lrb_465000454_fdb/mars/versions/6.99.1.3/bin:$PATH
    export LD_LIBRARY_PATH=/users/lrb_465000454_fdb/mars/versions/6.99.1.3/lib64:$LD_LIBRARY_PATH
    export FDB_HOME=${DATABRIDGE_FDB_HOME}
fi

get_current_date

# declare opaname
OPA_NAME=${JOBNAME#*OPA_}

#declare filenames for opa and gsv requests
REQUEST_PATTERN="${HPCROOTDIR}"/git_project/lib/runscript/request_"${CURRENT_DATE}"_"${CHUNK}"_*"${OPA_NAME^^}".yml

# Get the oldest file matching the pattern
REQUEST_FILE=$(ls -tr ${REQUEST_PATTERN} 2>/dev/null | head -1)

#run opa
run_OPA "${REQUEST_FILE}" "${OUTDIR}"

if [ "${SPLIT}" = "${SPLITS}" ]; then # put hti dynamic to the number of splits in the job
    touch "${OUTDIR}/green_flag_${OPA_NAME}"
fi

#change name so next opa instances dont get it

cp "${REQUEST_FILE}" "${REQUEST_FILE}"_used # tmp, for testing purposes
