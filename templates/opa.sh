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
SCRATCH_DIR=${18:-%CURRENT_SCRATCH_DIR%}
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
ENERGY_INDICATORS_IN_DATA_VERSION=${30:-%ENERGY_INDICATORS.IN_DATA_VERSION%}
ENERGY_OFFSHORE_IN_DATA_VERSION=${31:-%ENERGY_OFFSHORE.IN_DATA_VERSION%}
HYDROMET_IN_DATA_VERSION=${32:-%HYDROMET.IN_DATA_VERSION%}
HYDROLAND_IN_DATA_VERSION=${33:-%HYDROLAND.IN_DATA_VERSION%}
WILDFIRES_WISE_IN_DATA_VERSION=${34:-%WILDFIRES_WISE.IN_DATA_VERSION%}
WILDFIRES_FWI_IN_DATA_VERSION=${35:-%WILDFIRES_FWI.IN_DATA_VERSION%}
OBSALL_IN_DATA_VERSION=${36:-%OBSALL.IN_DATA_VERSION%}
DATA_IN_DATA_VERSION=${37:-%DATA.IN_DATA_VERSION%}
APP_AUX_IN_DATA_DIR=${38:-%APP_AUX_IN_DATA_DIR%}
OPERATIONAL_PROJECT_SCRATCH=${39:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${40:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}
HPC_PROJECT_ROOT=${41:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${42:-%CURRENT_LOCAL_DIR%}
MEMBER_LIST=${43:-%EXPERIMENT.MEMBERS%}
MEMBER=${44:-%MEMBER%}

# END_HEADER

READ_FROM_DATABRIDGE=${READ_FROM_DATABRIDGE:-"False"}

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture
LOGDIR=${HPCROOTDIR}/LOG_${EXPID}

#####################
# run OPA
# INPUT
#    request directory
#    chunk
#    split
#    expid
#    app_name
#    run_type
#    realization
#    datelist
#    request_number
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
        --bind "${APP_AUX_IN_DATA_DIR}" \
        --bind "${DEVELOPMENT_PROJECT_SCRATCH}" \
        --bind "${OPERATIONAL_PROJECT_SCRATCH}" \
        --env request_dir="$1" \
        --env chunk="$2" \
        --env split="$3" \
        --env expid="$4" \
        --env app_name="$5" \
        --env run_type="$6" \
        --env member="$7" \
        --env datelist="$8" \
        --env request_number="$9" \
        --env outpath="${OPA_OUTPATH}" \
        --env PYTHONPATH="${PYTHONPATH}" \
        --env FDB_HOME="${FDB_HOME}" \
        --env SCRIPTDIR="${SCRIPTDIR}" \
        --env READ_FROM_DATABRIDGE="${READ_FROM_DATABRIDGE}" \
        --env PYTHONNOUSERSITE="1" \
        --env GSV_WEIGHTS_PATH="${GSV_WEIGHTS_PATH}" \
        $HPC_CONTAINER_DIR/one_pass/one_pass_${OPA_VERSION}.sif bash -c \
        '
        python3 "${SCRIPTDIR}"/opa/run_opa.py \
            --request_dir "${request_dir}" \
            --chunk ${chunk} \
            --split ${split} \
            --expid ${expid} \
            --app_names ${app_name} \
            --member ${member} \
            --datelist ${datelist} \
            --request_number ${request_number} \
            --read_from_databridge "${READ_FROM_DATABRIDGE}" \
            --outpath "${outpath}"
        '
}

#TODO: needed if already loaded in remote setup?
# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

# lib/common/util.sh (get_member_number) (auto generated comment)
get_member_number "${MEMBER_LIST}" ${MEMBER}

REALIZATION="${MEMBER_NUMBER}"

export FDB_HOME=${FDB_HOME}

if [ "${READ_FROM_DATABRIDGE,,}" == "true" ]; then
    export FDB_HOME=${DATABRIDGE_FDB_HOME}
fi

# Declare OPA_NAME:
# Remove the shortest prefix from the JOBNAME variable up to
# and including the first occurrence of "OPA_"
OPA_NAME=${JOBNAME#*OPA_}

# TODO see if it is safe to do APP_NAME=OPA_NAME everywhere
APP_NAME=${OPA_NAME}

# Get data version.
# First resolve the variable name from the APP_NAME.
IN_DATA_VERSION_VARIABLE_NAME="${APP_NAME}_IN_DATA_VERSION"

# Then, if the variable is set, use it. Otherwise, exit with an error.
if [[ -n ${!IN_DATA_VERSION_VARIABLE_NAME} ]]; then
    DATA_VERSION="${!IN_DATA_VERSION_VARIABLE_NAME}"
else
    echo "Error: Variable ${IN_DATA_VERSION_VARIABLE_NAME} is not set!"
    exit 1
fi

# Apply lowercase to the DATA_VERSION.
DATA_VERSION="v${DATA_VERSION,,}"

# Apply lowercase to the APP_NAME.
APP_NAME=${APP_NAME,,}

# Declare filenames for GSV and OPA requests
REQUEST_PATTERN="${LOGDIR}/request_${APP_NAME,,}_${DATELIST}_${MEMBER}_${CHUNK}_${SPLIT}_OPA_${APP_NAME^^}"

# Count the number of request files. Intermediate step to continue
# calling run_OPA N times (one for each request file).
# TODO: Call run_opa runscript once, then have that runscript look at this request file,
# organize the data needed, then call concurrently individual routines (or child runscripts)
# concurrently as many times as needed.
#
# The block below extracts the highest numeric subkey under any top-level YAML key
# from the file ${REQUEST_PATTERN}.
#
# The YAML is assumed to have a structure like:
#
#   TOP_LEVEL_KEY:
#     1:
#       ...
#     2:
#       ...
#
# This awk script does the following:
# 1. `/^[^[:space:]]+:/`
#    Detects top-level keys (lines with no indentation followed by a colon, e.g., "TITLE:").
#    When found, it sets a flag (`in_block = 1`) to start tracking subkeys.
#
# 2. `/^[[:space:]]+[0-9]+:/ && in_block`
#    Matches indented numeric subkeys (e.g., "  42:") only if we're inside a top-level block.
#    It strips the colon from the field, converts it to a number, and compares it to the current maximum.
#
# 3. `max = $1`
#    Keeps track of the largest number seen under any top-level key.
#
# 4. `END { print max }`
#    At the end of the file, prints the maximum number found.

NUM_REQUESTS=$(awk '
/^[^[:space:]]+:/ { in_block = 1; next }
/^[[:space:]]+[0-9]+:/ && in_block {
    gsub(":", "", $1);
    if ($1 > max) max = $1
}
END { print max }
' "${REQUEST_PATTERN}")

# Declare the variable name for the OPA output path.
OPA_OUTPATH_VARIABLE_NAME="OUT_${APP_NAME^^}"

# Ensure APP_OUTPATH is set. This is used for the default OPA output path.
if [[ -z "${APP_OUTPATH}" ]]; then
    echo "Variable APP_OUTPATH is not set. "
    echo "Please, define APP.OUTPATH in the OPA configuration file: "
    echo "templates/conf/applications/opa/opa.yml"
    exit 1
fi

# Declare the default OPA output path.
OPA_OUTPATH_DEFAULT="${APP_OUTPATH}/${APP_NAME}/opa/"

# OPA output path.
# If the variable name is not set, use the default.
OPA_OUTPATH="${!OPA_OUTPATH_VARIABLE_NAME:-${OPA_OUTPATH_DEFAULT}}"

# Ensure OPA_OUTPATH is set.
if [[ -z "${OPA_OUTPATH}" ]]; then
    echo "Variable OPA_OUTPATH could not be resolved. "
    echo "Either set a variable 'OUT_<APPNAME>' in templates/conf/opa.yml, "
    echo "or verify the default value of OPA_OUTPATH in the OPA template.."
    exit 1
fi

echo "OPA_OUTPATH: ${OPA_OUTPATH}"

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
for i in $(seq 1 "$NUM_REQUESTS"); do
    run_with_limit run_OPA "${LOGDIR}" "${CHUNK}" "${SPLIT}" "${EXPID}" "${APP_NAME}" \
        "${RUN_TYPE}" "${MEMBER}" "${DATELIST}" "${i}"
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
