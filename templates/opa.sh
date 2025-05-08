#!/bin/bash
#

# This step runs the Ona PASS algorithm, after the data notifier is finished
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
CHUNK_START_DATE=${9:-%CHUNK_START_DATE%}
SPLIT=${10:-%SPLIT%}
JOBNAME=${11:-%JOBNAME%}
APP_OUTPATH=${12:-%APP.OUTPATH%}
RUN_TYPE=${13:-%RUN.TYPE%}
WORKFLOW=${14:-%RUN.WORKFLOW%}
SPLITS=${15:-%JOBS.DN.SPLITS%}
READ_FROM_DATABRIDGE=${16:-%APP.READ_FROM_DATABRIDGE%}
DATABRIDGE_FDB_HOME=${17:-%CURRENT_DATABRIDGE_FDB_HOME%}
SCRATCH=${18:-%CURRENT_SCRATCH_DIR%}
PROJECT=${19:-%CURRENT_PROJECT%}
HPC_PROJECT=${20:-%CONFIGURATION.HPC_PROJECT_DIR%}
HPC_SCRATCH=${21:-%CONFIGURATION.PROJECT_SCRATCH%}
HPC_CONTAINER_DIR=${22:-%CONFIGURATION.CONTAINER_DIR%}
FDB_HOME=${23:-%REQUEST.FDB_HOME%}
EXPVER=${24:-%REQUEST.EXPVER%}
LIBDIR=${25:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${26:-%CONFIGURATION.SCRIPTDIR%}
GSV_WEIGHTS_PATH=${27:-%GSV.WEIGHTS_PATH%}
OPA_VERSION=${28:-%OPA.VERSION%}
OPA_MAX_PROC=${29:-%CURRENT_OPA_MAX_PROC%}
ENERGY_ONSHORE_IN_DATA_VERSION=${30:-%ENERGY_ONSHORE.IN_DATA_VERSION%}
ENERGY_OFFSHORE_IN_DATA_VERSION=${31:-%ENERGY_OFFSHORE.IN_DATA_VERSION%}
HYDROMET_IN_DATA_VERSION=${32:-%HYDROMET.IN_DATA_VERSION%}
HYDROLAND_IN_DATA_VERSION=${33:-%HYDROLAND.IN_DATA_VERSION%}
WILDFIRES_WISE_IN_DATA_VERSION=${34:-%WILDFIRES_WISE.IN_DATA_VERSION%}
WILDFIRES_FWI_IN_DATA_VERSION=${35:-%WILDFIRES_FWI.IN_DATA_VERSION%}
OBSALL_IN_DATA_VERSION=${36:-%OBSALL_IN_DATA_VERSION%}
DATA_IN_DATA_VERSION=${37:-%DATA_IN_DATA_VERSION%}
APP_AUX_IN_DATA_DIR=${38:-%APP_AUX_IN_DATA_DIR%}
OPERATIONAL_PROJECT_SCRATCH=${39:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${40:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}

# END_HEADER

READ_FROM_DATABRIDGE=${READ_FROM_DATABRIDGE:-"False"}

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture
LOGDIR=${HPCROOTDIR}/LOG_${EXPID}

#####################
# run OPA
# INPUT
#    request file
#    output directory
#####################
function run_OPA() {

    if [ ! -d "${OPA_OUTPATH}" ]; then
        mkdir -p "${OPA_OUTPATH}"
        echo "Directory created: ${OPA_OUTPATH}"
    else
        echo "Directory already exists: ${OPA_OUTPATH}"
    fi

    SRC_DIR=${HPCROOTDIR}/${PROJDEST}/one_pass/ #This step allows using dev versions of the application from the submodule
    # If the submodule does not exist, set PYTHONPATH to SCRIPTDIR (does not need to be SCRIPTDIR though)
    if [ -d "$SRC_DIR" ]; then
        export PYTHONPATH="${SRC_DIR}"
    else
        export PYTHONPATH="${SCRIPTDIR}"
    fi

    if [ -d "${BA_AUX}" ]; then
        echo "The directory ${BA_AUX} and therefore the bias adjustment will not be applied."
        BA_AUX="$SCRIPTDIR" #Shfmt does not like having it empty
    fi

    # move parsed data request
    cd "${SCRIPTDIR}/opa/" || exit
    singularity exec \
        --cleanenv \
        --no-home \
        --bind "${SCRIPTDIR}/opa/" \
        --bind "${FDB_HOME}" \
        --bind "${LOGDIR}" \
        --bind "${OPA_OUTPATH}" \
        --bind "${PYTHONPATH}" \
        --bind "${BA_AUX}" \
        --env REQUEST="$1" \
        --bind "${APP_AUX_IN_DATA_DIR}" \
        --bind "${DEVELOPMENT_PROJECT_SCRATCH}" \
        --bind "${OPERATIONAL_PROJECT_SCRATCH}" \
        --env PYTHONPATH="${PYTHONPATH}" \
        --env FDB_HOME="${FDB_HOME}" \
        --env SCRIPTDIR="${SCRIPTDIR}" \
        --env READ_FROM_DATABRIDGE="${READ_FROM_DATABRIDGE}" \
        --env PYTHONNOUSERSITE="1" \
        --env GSV_WEIGHTS_PATH="${GSV_WEIGHTS_PATH}" \
        $HPC_CONTAINER_DIR/one_pass/one_pass_${OPA_VERSION}.sif bash -c \
        '
    python3 "${SCRIPTDIR}"/opa/run_opa.py --request "${REQUEST}" --read_from_databridge "${READ_FROM_DATABRIDGE}"
    '
}

#TODO: needed if already loaded in remote setup?
# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

export FDB_HOME=${FDB_HOME}

if [ "${READ_FROM_DATABRIDGE,,}" == "true" ]; then
    export FDB_HOME=${DATABRIDGE_FDB_HOME}
fi

# declare opaname
OPA_NAME=${JOBNAME#*OPA_}

# Extract the part concerning the APP name only # TODO see if it is safe to do APP_NAME=OPA_NAME everywhere
APP_NAME=${OPA_NAME} # Removes everything after the last underscore

# get data version
VAR_NAME="${APP_NAME}_IN_DATA_VERSION"

if [[ -n ${!VAR_NAME} ]]; then
    DATA_VERSION="${!VAR_NAME}"
else
    echo "Error: Variable $VAR_NAME is not set!"
    exit 1
fi

DATA_VERSION="v${DATA_VERSION,,}"

#apply lowercase
APP_NAME=${APP_NAME,,}

#declare filenames for opa and gsv requests
REQUEST_PATTERN="${LOGDIR}"/request_"${DATELIST}"_"${CHUNK}"_"${SPLIT}"_OPA_"${APP_NAME^^}"*.yml

# Create an array of all files matching the pattern
REQUEST_FILES=($(ls ${REQUEST_PATTERN} 2>/dev/null))

# OPA output path. uilt with APP name, and must match
# some variable "OUT_<APPNAME>" in templates/conf/opa.yml
OPA_OUTPATH="${APP_OUTPATH}/${APP_NAME}/opa/"

# AUX_DATA PATH for bias adjustment
BA_AUX="${APP_AUX_IN_DATA_DIR}/${APP_NAME}_${DATA_VERSION}"

# load singularity
# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

# Number of parallel processes to allow
FAIL=0
PIDS=""

# Function to control parallel execution
run_with_limit() {
    # Start the job and track its PID
    "$@" &
    PIDS="$PIDS $!"

    # Count the number of background jobs
    while [ "$(jobs -rp | wc -l)" -ge "$OPA_MAX_PROC" ]; do
        # Wait for any job to finish before starting a new one
        wait -n
    done
}

# Iterate over request files and run jobs with limited parallelism
for REQUEST_FILE in "${REQUEST_FILES[@]}"; do
    run_with_limit run_OPA "$REQUEST_FILE"
done

# Wait for all background jobs and check their exit status
for job in $PIDS; do
    wait $job || let "FAIL+=1"
done

# Exit with nonzero status if any job failed
if [ "$FAIL" -ne 0 ]; then
    echo "Some processes failed ($FAIL). Exiting with status 1."
    exit 1
else
    echo "All processes completed successfully."
fi

# Wait for all remaining background jobs to finish
wait

#change name so next opa instances dont get it

cp "${REQUEST_FILES}" "${REQUEST_FILES}"_used
cp "${REQUEST_FILES}" "${APP_OUTPATH}"/"${APP_NAME}"/request_metadata.yml
