#!/bin/bash

set -xuve

# Interface
HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL=${3:-%MODEL.NAME%}
CURRENT_ARCH=${4:-%CURRENT_ARCH%}
EXPID=${5:-%DEFAULT.EXPID%}
DATELIST=${6:-%EXPERIMENT.DATELIST%}
MEMBERS=${7:-%EXPERIMENT.MEMBERS%}
CHUNK=${8:-%CHUNK%}
START_DATE=${9:-%SDATE%}
CHUNK_START_DATE=${10:-%CHUNK_START_DATE%}
CHUNK_END_DATE=${11:-%CHUNK_END_DATE%}
CHUNK_SECOND_TO_LAST_DATE=${12:-%CHUNK_SECOND_TO_LAST_DATE%}
FDB_DIR=${13:-%CURRENT_FDB_DIR%}
RAPS_EXPERIMENT=${14:-%CONFIGURATION.RAPS_EXPERIMENT%}
PRODUCTION=${15:-%RUN.PRODUCTION%}
FDB_PROD=${16:-%CURRENT_FDB_PROD%}
DQC_PROFILE=${17:-%CONFIGURATION.DQC_PROFILE%}
MEMBER=${21:-%MEMBER%}
MEMBER_LIST=${22:-%EXPERIMENT.MEMBERS%}

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$(echo ${CURRENT_ARCH} | cut -d- -f1)

function run_DQC() {
    # Run DQC script
    cd ${LIBDIR}/runscript
    python run_dqc.py -expver "$1" -date "$2" -model "$3" -profile_path "$4" -experiment "$5" -activity "$6" -realization "$7"
}

# Source libraries
source "${LIBDIR}"/"${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

# Load GSV
load_environment_gsv "$FDB_DIR" "$EXPID" # $DATELIST $MEMBS Not used

get_member_number "${MEMBER_LIST}" ${MEMBER}

# Update FDB5_CONFIG_FILE for production FDB
if [[ ${PRODUCTION,,} = "true" ]]; then
    unset FDB5_CONFIG_FILE
    export FDB_HOME="${FDB_PROD}"
    EXPID="0001" # Official EXPVER for production runs
fi

# Compute Date key
DATE="${CHUNK_START_DATE}/to/${CHUNK_SECOND_TO_LAST_DATE}"

# Get DQC profiles path
DQC_PROFILE_PATH="${HPCROOTDIR}"/"${PROJDEST}"/gsv_interface/gsv/dqc/profiles/${DQC_PROFILE}/"${MODEL,,}"
# This should be changed to take specific profiles for each configurations

# Check model being used and load DGOV keys
if [ ${MODEL} == "icon" ]; then
    # Get ICON workflow configuration
    export EXPERIMENT="%SIMULATION.DATA_GOV.EXPERIMENT%"
    export ACTIVITY="%SIMULATION.DATA_GOV.ACTIVITY%"
elif [ ${MODEL%%-*} == "ifs" ]; then
    # Get RAPS configuration
    export_MULTIO_variables "${RAPS_EXPERIMENT}"
    export EXPERIMENT="${MULTIO_EXPERIMENT}"
    export ACTIVITY="${MULTIO_ACTIVITY}"
else
    echo "Error: Incorrect model name"
    exit 1
fi

# Get new DGOV keys
export_MULTIO_variables ${RAPS_EXPERIMENT}
REALIZATION=${MEMBER}

# Run DQC
run_DQC "${EXPID}" "${DATE}" "${MODEL^^}" "${DQC_PROFILE_PATH}" "${EXPERIMENT}" "${ACTIVITY}" "${REALIZATION}"
