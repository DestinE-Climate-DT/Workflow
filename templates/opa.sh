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
CHUNK_SECOND_TO_LAST_DATE=${10:-%CHUNK_SECOND_TO_LAST_DATE%}
SPLIT=${11:-%SPLIT%}
JOBNAME=${12:-%JOBNAME%}
RUN_TYPE=${13:-%RUN.TYPE%}
WORKFLOW=${14:-%RUN.WORKFLOW%}
SPLITS=${15:-%JOBS.DN.SPLITS%}
READ_FROM_DATABRIDGE=${16:-%APP.READ_FROM_DATABRIDGE%}
DATABRIDGE_FDB_HOME=${17:-%CURRENT_DATABRIDGE_FDB_HOME%}
SCRATCH_DIR=${18:-%CURRENT_SCRATCH_DIR%}
PROJECT=${19:-%CURRENT_PROJECT%}
HPC_PROJECT=${20:-%CONFIGURATION.HPC_PROJECT_DIR%}
HPC_SCRATCH=${21:-%CONFIGURATION.PROJECT_SCRATCH%}
HPC_CONTAINER_DIR=${22:-%CURRENT_CONTAINER_DIR%}
FDB_HOME=${23:-%REQUEST.FDB_HOME%}
EXPVER=${24:-%REQUEST.EXPVER%}
LIBDIR=${25:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${26:-%CONFIGURATION.SCRIPTDIR%}
GSV_WEIGHTS_PATH=${27:-%GSV.WEIGHTS_PATH%}
OPA_VERSION=${28:-%OPA.VERSION%}
OPA_MAX_PROC=${29:-%CURRENT_OPA_MAX_PROC%}
OPA_MPI_PROC=${30:-%CURRENT_OPA_MPI_PROC%}
OPA_MPI_STATS=${31:-%OPA_MPI_STATS%}
OPA_LOG_LEVEL=${32:-%OPA_LOG_LEVEL%}
ENERGY_INDICATORS_IN_DATA_VERSION=${33:-%ENERGY_INDICATORS.IN_DATA_VERSION%}
ENERGY_OFFSHORE_IN_DATA_VERSION=${34:-%ENERGY_OFFSHORE.IN_DATA_VERSION%}
HYDROMET_IN_DATA_VERSION=${35:-%HYDROMET.IN_DATA_VERSION%}
HYDROLAND_IN_DATA_VERSION=${36:-%HYDROLAND.IN_DATA_VERSION%}
WILDFIRES_WISE_IN_DATA_VERSION=${37:-%WILDFIRES_WISE.IN_DATA_VERSION%}
WILDFIRES_FWI_IN_DATA_VERSION=${38:-%WILDFIRES_FWI.IN_DATA_VERSION%}
OBSALL_IN_DATA_VERSION=${39:-%OBSALL.IN_DATA_VERSION%}
DATA_IN_DATA_VERSION=${40:-%DATA.IN_DATA_VERSION%}
APP_AUX_IN_DATA_DIR=${41:-%APP_AUX_IN_DATA_DIR%}
OPERATIONAL_PROJECT_SCRATCH=${42:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${43:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}
HPC_PROJECT_ROOT=${44:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${45:-%CURRENT_LOCAL_DIR%}
MEMBER=${46:-%MEMBER%}
REQUEST_REALIZATION=${47:-%REQUEST.REALIZATION%}
CHUNK_START_MONTH=${48:-%CHUNK_START_MONTH%}
SPLIT_SECOND_TO_LAST_DATE=${49:-%SPLIT_SECOND_TO_LAST_DATE%}
ENERGY_INDICATORS_MASK_FILE_5=${50:-%ENERGY_INDICATORS.MASK_FILE_5%}
ENERGY_INDICATORS_MASK_FILE_10=${51:-%ENERGY_INDICATORS.MASK_FILE_10%}
ENERGY_INDICATORS_MASK_FILE_25=${52:-%ENERGY_INDICATORS.MASK_FILE_25%}
ENERGY_INDICATORS_GRID=${53:-%ENERGY_INDICATORS.GRID%}

# END_HEADER

export OPA_LOG_LEVEL

# to do the trick on the energy indicator tdigest stats
ENERGYTDIG1_IN_DATA_VERSION=${ENERGY_INDICATORS_IN_DATA_VERSION}
ENERGYTDIG2_IN_DATA_VERSION=${ENERGY_INDICATORS_IN_DATA_VERSION}

# select mask file depending on grid
if [ "$ENERGY_INDICATORS_GRID" == "0.05/0.05" ]; then
    ENERGY_INDICATORS_MASK_FILE=$ENERGY_INDICATORS_MASK_FILE_5
elif [ "$ENERGY_INDICATORS_GRID" == "0.1/0.1" ]; then
    ENERGY_INDICATORS_MASK_FILE=$ENERGY_INDICATORS_MASK_FILE_10
elif [ "$ENERGY_INDICATORS_GRID" == "0.25/0.25" ]; then
    ENERGY_INDICATORS_MASK_FILE=$ENERGY_INDICATORS_MASK_FILE_25
else
    echo "No mask applied as grid is not 5, 10 or 25 km."
fi

READ_FROM_DATABRIDGE=${READ_FROM_DATABRIDGE:-"False"}

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture
LOGDIR=${HPCROOTDIR}/LOG_${EXPID}

# Convert OPA_MPI_STATS into array
read -ra OPA_MPI_STATS <<<"$OPA_MPI_STATS"

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

# lib/common/utils/opa_utils.sh (get_num_requests) (auto generated comment)
NUM_REQUESTS=$(get_num_requests "${REQUEST_PATTERN}")

# Declare the variable name for the OPA output path.
OPA_OUTPATH_VARIABLE_NAME="OUT_${APP_NAME^^}"

# Declare the OPA and APP output path, see issue #1187.
APP_OUTPATH="${HPCROOTDIR}/output/${APP_NAME}/${DATELIST}/member0${REALIZATION}/"
OPA_OUTPATH="${HPCROOTDIR}/opa/${APP_NAME}/${DATELIST}/member0${REALIZATION}/"

# Manage checkpoints at the end of the chunk
if [ "${CHUNK_SECOND_TO_LAST_DATE}" = "${SPLIT_SECOND_TO_LAST_DATE}" ]; then
    IS_END_OF_CHUNK=1
else
    IS_END_OF_CHUNK=0
fi

if [ "${CHUNK_START_MONTH}" -eq 12 ]; then
    IS_END_OF_YEAR=1
else
    IS_END_OF_YEAR=0
fi

# OPA Restarts
# State of the OPA stats at the end of the chunk
if [ "${IS_END_OF_CHUNK}" -eq 1 ] || [ "${IS_END_OF_YEAR}" -eq 1 ]; then
    OPA_CHECKPOINT="${HPCROOTDIR}/checkpoint/00/${APP_NAME}/${DATELIST}/member0${REALIZATION}/"
    if [ ! -d "${OPA_CHECKPOINT}" ]; then
        mkdir -p "${OPA_CHECKPOINT}"
    fi
else
    OPA_CHECKPOINT=""
fi

OPA_MONTHLY_CHECKPOINTS=()
for i in {1..3}; do
    checkpoint_dir=("${HPCROOTDIR}/checkpoint/$(printf "%02d" "$i")/${APP_NAME}/${DATELIST}/member0${REALIZATION}/")
    if [ ! -d "${checkpoint_dir}" ]; then
        mkdir -p "${checkpoint_dir}"
    fi
    OPA_MONTHLY_CHECKPOINTS+=("${checkpoint_dir}")
done

OPA_YEARLY_CHECKPOINTS=()
for i in 12 24; do
    checkpoint_dir=("${HPCROOTDIR}/checkpoint/${i}/${APP_NAME}/${DATELIST}/member0${REALIZATION}/")
    if [ ! -d "${checkpoint_dir}" ]; then
        mkdir -p "${checkpoint_dir}"
    fi
    OPA_YEARLY_CHECKPOINTS+=("${checkpoint_dir}")
done

# Create the OPA and APP output directories if they do not exist.
echo "OPA_OUTPATH: ${OPA_OUTPATH}"
echo "APP_OUTPATH: ${APP_OUTPATH}"

# AUX_DATA PATH for bias adjustment
# trick to deal with multiple opas for energy indicators.
if [[ "${APP_NAME^^}" == *"ENERGYTDIG"* ]]; then
    export BA_AUX="${APP_AUX_IN_DATA_DIR}/energy_indicators_${DATA_VERSION}"
    export MASK_FILE="${APP_AUX_IN_DATA_DIR}/energy_indicators_v${ENERGY_INDICATORS_IN_DATA_VERSION}/${ENERGY_INDICATORS_MASK_FILE}"
else
    export BA_AUX="${APP_AUX_IN_DATA_DIR}/${APP_NAME}_${DATA_VERSION}"
    export MASK_FILE="None"
fi

# load singularity
# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

if [ ! -d "${OPA_OUTPATH}" ]; then
    mkdir -p "${OPA_OUTPATH}"
    echo "Directory created: ${OPA_OUTPATH}"
else
    echo "Directory already exists: ${OPA_OUTPATH}"
fi

# SRC_DIR doesn't exist, check for installed one_pass package
if command -v python3 >/dev/null 2>&1; then
    ONE_PASS_VERSION=$(python3 -c "import one_pass; print(one_pass.__version__)" 2>/dev/null || true)
    echo "One_Pass version: ${ONE_PASS_VERSION}"
fi

# Number of parallel processes to allow
FAIL=0
PIDS=""

echo "OPA_OUTPATH: ${OPA_OUTPATH}"
echo "NUM_REQUESTS: ${NUM_REQUESTS}"
echo "OPA_MAX_PROC: ${OPA_MAX_PROC}"
echo "OPA_MPI_PROC: ${OPA_MPI_PROC}"
echo "OPA_MPI_STATS: ${OPA_MPI_STATS}"
echo "Starting OPA jobs with max parallelism of ${OPA_MAX_PROC}"

# Iterate over request files and run jobs with limited parallelism
for i in $(seq 1 "$NUM_REQUESTS"); do
    # lib/common/utils/opa_utils.sh (detect_mpi_proc) (auto generated comment)
    mpi_num_procs=$(detect_mpi_proc "${REQUEST_PATTERN}" "${APP_NAME^^}" "${i}")
    echo "Launching OPA request ${i} of ${NUM_REQUESTS} with ${mpi_num_procs} MPI processes."
    # lib/common/utils/opa_utils.sh (run_OPA) (auto generated comment)
    # lib/common/utils/opa_utils.sh (run_with_limit) (auto generated comment)
    run_with_limit run_OPA "${mpi_num_procs}" "${LOGDIR}" "${CHUNK}" "${SPLIT}" "${EXPID}" "${APP_NAME}" \
        "${RUN_TYPE}" "${MEMBER}" "${DATELIST}" "${i}" "${OPA_CHECKPOINT}" "${MASK_FILE}"
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

# Manage checkpoints at the end of the chunk
if [ "${IS_END_OF_CHUNK}" -eq 1 ]; then
    # lib/common/utils/opa_utils.sh (copy_checkpoints) (auto generated comment)
    copy_checkpoints ${OPA_CHECKPOINT} "${OPA_MONTHLY_CHECKPOINTS[*]}"
fi

# Manage checkpoints at the end of the year
if [ "${IS_END_OF_YEAR}" -eq 1 ]; then
    # lib/common/utils/opa_utils.sh (copy_checkpoints) (auto generated comment)
    copy_checkpoints ${OPA_CHECKPOINT} "${OPA_YEARLY_CHECKPOINTS[*]}"
fi
