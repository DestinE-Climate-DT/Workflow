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
MEMBER_LIST=${7:-%EXPERIMENT.MEMBERS%}
CHUNK=${8:-%CHUNK%}
CHUNK_START_DATE=${9:-%CHUNK_START_DATE%}
SPLIT=${10:-%SPLIT%}
JOBNAME=${11:-%JOBNAME%}
RUN_TYPE=${12:-%RUN.TYPE%}
WORKFLOW=${13:-%RUN.WORKFLOW%}
SPLITS=${14:-%JOBS.DN.SPLITS%}
READ_FROM_DATABRIDGE=${15:-%APP.READ_FROM_DATABRIDGE%}
DATABRIDGE_FDB_HOME=${16:-%CURRENT_DATABRIDGE_FDB_HOME%}
SCRATCH_DIR=${17:-%CURRENT_SCRATCH_DIR%}
PROJECT=${18:-%CURRENT_PROJECT%}
HPC_PROJECT=${19:-%CONFIGURATION.HPC_PROJECT_DIR%}
HPC_SCRATCH=${20:-%CONFIGURATION.PROJECT_SCRATCH%}
HPC_CONTAINER_DIR=${21:-%CONFIGURATION.CONTAINER_DIR%}
FDB_HOME=${22:-%REQUEST.FDB_HOME%}
EXPVER=${23:-%REQUEST.EXPVER%}
LIBDIR=${24:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${25:-%CONFIGURATION.SCRIPTDIR%}
GSV_WEIGHTS_PATH=${26:-%GSV.WEIGHTS_PATH%}
OPA_VERSION=${27:-%OPA.VERSION%}
OPA_MAX_PROC=${28:-%CURRENT_OPA_MAX_PROC%}
ENERGY_INDICATORS_IN_DATA_VERSION=${29:-%ENERGY_INDICATORS.IN_DATA_VERSION%}
ENERGY_OFFSHORE_IN_DATA_VERSION=${30:-%ENERGY_OFFSHORE.IN_DATA_VERSION%}
HYDROMET_IN_DATA_VERSION=${31:-%HYDROMET.IN_DATA_VERSION%}
HYDROLAND_IN_DATA_VERSION=${32:-%HYDROLAND.IN_DATA_VERSION%}
WILDFIRES_WISE_IN_DATA_VERSION=${33:-%WILDFIRES_WISE.IN_DATA_VERSION%}
WILDFIRES_FWI_IN_DATA_VERSION=${34:-%WILDFIRES_FWI.IN_DATA_VERSION%}
OBSALL_IN_DATA_VERSION=${35:-%OBSALL.IN_DATA_VERSION%}
DATA_IN_DATA_VERSION=${36:-%DATA.IN_DATA_VERSION%}
APP_AUX_IN_DATA_DIR=${37:-%APP_AUX_IN_DATA_DIR%}
OPERATIONAL_PROJECT_SCRATCH=${38:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${39:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}
HPC_PROJECT_ROOT=${40:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${41:-%CURRENT_LOCAL_DIR%}
MEMBER=${42:-%MEMBER%}
REQUEST_REALIZATION=${43:-%REQUEST.REALIZATION%}

# END_HEADER

# to do the trick on the energy indicator tdigest stats
ENERGYTDIG1_IN_DATA_VERSION=${ENERGY_INDICATORS_IN_DATA_VERSION}
ENERGYTDIG2_IN_DATA_VERSION=${ENERGY_INDICATORS_IN_DATA_VERSION}

READ_FROM_DATABRIDGE=${READ_FROM_DATABRIDGE:-"False"}

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture
LOGDIR=${HPCROOTDIR}/LOG_${EXPID}

#TODO: needed if already loaded in remote setup?
# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh
source "${LIBDIR}"/common/utils/opa_utils.sh

# lib/common/util.sh (get_member_number) (auto generated comment)
REALIZATION=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

# For apps workflows and a single request member,
# then read the REQUEST.REALIZATION variable
# Otherwise, REALIZATION is the current member number.
# See https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/issues/1191
read -r -a MEMBER_LIST <<<"$MEMBER_LIST"

if [[ ${WORKFLOW,,} == "apps" && "${#MEMBER_LIST[@]}" == 1 ]]; then
    REALIZATION=${REQUEST_REALIZATION}
fi

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
#APP_NAME_REQUEST=${OPA_NAME} #needed for getthing the correct request in energy indicators.

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
REQUEST_PATTERN="${LOGDIR}/request_${APP_NAME^^}_${DATELIST}_${MEMBER}_${CHUNK}_${SPLIT}_OPA_${APP_NAME^^}"

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

# Declare the OPA and APP output path, see issue #1187.
APP_OUTPATH="${HPCROOTDIR}/output/${APP_NAME}/${DATELIST}/member0${REALIZATION}/"
OPA_OUTPATH="${HPCROOTDIR}/opa/${APP_NAME}/${DATELIST}/member0${REALIZATION}/"

echo "OPA_OUTPATH: ${OPA_OUTPATH}"
echo "APP_OUTPATH: ${APP_OUTPATH}"

# AUX_DATA PATH for bias adjustment
# trick to deal with multiple opa for energy indicators.
if [[ "${APP_NAME^^}" == *"ENERGYTDIG"* ]]; then
    export BA_AUX="${APP_AUX_IN_DATA_DIR}/energy_indicators_${DATA_VERSION}"
else
    export BA_AUX="${APP_AUX_IN_DATA_DIR}/${APP_NAME}_${DATA_VERSION}"
fi

# load singularity
# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

# Number of parallel processes to allow
FAIL=0
PIDS=""

# Iterate over request files and run jobs with limited parallelism
for i in $(seq 1 "$NUM_REQUESTS"); do
    # lib/common/utils/opa_utils.sh (run_OPA) (auto generated comment)
    # lib/common/utils/opa_utils.sh (run_with_limit) (auto generated comment)
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
