#!/bin/bash
#
# This step runs one chunk of climate simulation

set -xuve

# HEADER
HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${3:-%CURRENT_ARCH%}
MODEL_NAME=${4:-%MODEL.NAME%}
MODEL_VERSION=${5:-%MODEL.VERSION%}

# Simulation parameters
CHUNK=${6:-%CHUNK%}
CHUNKSIZE=${7:-%EXPERIMENT.CHUNKSIZE%}
CHUNKSIZEUNIT=${8:-%EXPERIMENT.CHUNKSIZEUNIT%}
CHUNK_FIRST=${9:-%CHUNK_FIRST%}
CHUNK_START_DATE=${10:-%Chunk_START_DATE%}
CHUNK_END_DATE=${11:-%Chunk_END_DATE%}
RUN_DAYS=${12:-%RUN_DAYS%}
FAIL_COUNT=${13:-%FAIL_COUNT%}

MEMBER=${14:-%MEMBER%}
MEMBER_LIST=${15:-%EXPERIMENT.MEMBERS%}
RUNDIR=${16:-%CONFIGURATION.RUNDIR_PATH%}
PRE_RESTART_DIR=${17:-%CONFIGURATION.PRE_RESTART_DIR%}
RESTART_DIR=${18:-%CONFIGURATION.RESTART_DIR%}
RESTARTED_RUN=${19:-%RUN.RESTARTED_RUN%}

TIMEFORMAT=${20:-%SIMULATION.TIMEFORMAT%}
RUNSCRIPT=${21:-%SIMULATION.RUNSCRIPT%}
HPCARCH=${22:-%HPCARCH%}
SCRATCH_DIR=${23:-%SCRATCH_DIR%}
RUN_TYPE=${24:-%RUN.TYPE%}
FDB_HOME=${25:-%REQUEST.FDB_HOME%}
EXPID=${26:-%DEFAULT.EXPID%}
EXPVER=${27:-%REQUEST.EXPVER%}
SIM_NAME=${28:-%SIMULATION.NAME%}
LIBDIR=${29:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${30:-%CONFIGURATION.SCRIPTDIR%}
ENVIRONMENT=${31:-%RUN.ENVIRONMENT%}
PU=${32:-%RUN.PROCESSOR_UNIT%}
MODEL_PATH=${33:-%MODEL.PATH%}
MODEL_INPUTS=${34:-%MODEL.INPUTS%}

# Platform-dependent variables
HDF5_USE_FILE_LOCKING=${35:-%CURRENT_HDF5_USE_FILE_LOCKING%}
FI_CXI_OPTIMIZED_MRS=${36:-%CURRENT_FI_CXI_OPTIMIZED_MRS%}
FI_CXI_RX_MATCH_MODE=${37:-%CURRENT_FI_CXI_RX_MATCH_MODE%}
FI_MR_CACHE_MONITOR=${38:-%CURRENT_FI_MR_CACHE_MONITOR%}
MPICH_ALLREDUCE_NO_SMP=${39:-%CURRENT_MPICH_ALLREDUCE_NO_SMP%}
MPICH_COLL_OPT_OFF=${40:-%CURRENT_MPICH_COLL_OPT_OFF%}
PMI_SIGNAL_STARTUP_COMPLETION=${41:-%CURRENT_PMI_SIGNAL_STARTUP_COMPLETION%}
MPICH_SMP_SINGLE_COPY_MODE=${42:-%CURRENT_MPICH_SMP_SINGLE_COPY_MODE%}

# END_HEADER

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

# Load HPC and utility functions
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh
. "${LIBDIR}"/common/utils/sim_utils.sh

export MODEL_VERSION
export ENVIRONMENT
export HPCARCH

# Main code

# Model directory definition
if [ -z "${MODEL_VERSION}" ]; then
    export MODEL_DIR="${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim
else
    export MODEL_DIR="${MODEL_PATH}"
fi

# directories with absolute paths
export thisdir="${MODEL_PATH}"/run
export icon_data_rootFolder="${MODEL_INPUTS}"

# Switch binaries for ocean and atmosphere when using hetjobs
if [ "${PU}" = "gpu" ]; then
    export MODEL_C="${MODEL_PATH}"/build/icon_cpu/bin/icon
    export MODEL_G="${MODEL_PATH}"/build/icon_gpu/bin/icon
elif [ "${PU}" = "cpu" ]; then
    export MODEL="${MODEL_PATH}"/build/icon_cpu/bin/icon
else
    echo "Unsupported processing unit"
    exit 1
fi

# Set output task to write to the FDB through the modified coupler
export yaco_rootFolder="${MODEL_PATH}"/yaco
export YACO="${yaco_rootFolder}"/build/current/yaco

# Check if MODEL_G and MODEL_C and YACO exist
if [ ! -f "${MODEL_G}" ] || [ ! -f "${MODEL_C}" ] || [ ! -f "${YACO}" ]; then
    echo "One or more required binaries not found:"
    [ ! -f "${MODEL_G}" ] && echo "Model GPU binary not found: ${MODEL_G}"
    [ ! -f "${MODEL_C}" ] && echo "Model CPU binary not found: ${MODEL_C}"
    [ ! -f "${YACO}" ] && echo "YACO binary not found: ${YACO}"
    exit 1
fi

# If first run, set lrestart to ".FALSE."
if [ "${CHUNK_FIRST}" = "TRUE" ] && [ "${RESTARTED_RUN,,}" != "true" ]; then
    export lrestart=".false."
    export restart_jsbach=".false."
    export initialize_fromrestart=".true."
    export read_initial_reservoirs=".true."
else
    export lrestart=".true."
    export restart_jsbach=".true."
    export initialize_fromrestart=".false."
    export read_initial_reservoirs=".false."
fi

# Loads necessary packages (module load ...)
# Exports necessary paths (input, output, restarts ...)
load_SIM_env_"${MODEL_NAME%%-*}"_"${PU}"

# Grid Configuration
export atmos_gridID="%CONFIGURATION.ICON.ATM_GID%"
export atmos_refinement="%CONFIGURATION.ICON.ATM_REF%"

export ocean_gridID="%CONFIGURATION.ICON.OCE_GID%"
export ocean_refinement="%CONFIGURATION.ICON.OCE_REF%"

# Time stepping configuration
export radTimeStep="%SIMULATION.RAD_TSTEP%"
export atmTimeStep="%SIMULATION.ATM_TSTEP%"
export oceTimeStep="%SIMULATION.OCE_TSTEP%"
export couplingTimeStep="%SIMULATION.COUPLING_TSTEP%"
# lib/common/utils/sim_utils.sh (iso8601_to_seconds) (auto generated comment)
export atmos_time_step_in_sec=$(iso8601_to_seconds "$atmTimeStep")
# lib/common/utils/sim_utils.sh (iso8601_to_seconds) (auto generated comment)
export ocean_time_step_in_sec=$(iso8601_to_seconds "$oceTimeStep")

# YACO output process timestep
export yacoTimeStep="%SIMULATION.YACO_TSTEP%"

# Internal YAC timestepping
export atm_lag="%SIMULATION.ATM_LAG%"
export oce_lag="%SIMULATION.OCE_LAG%"
export yaco_lag="%SIMULATION.YACO_LAG%"

# Ocean and Atmosphere level configuration
export atm_levels="%CONFIGURATION.ICON.ATM_LEVELS%"
export atm_halflevels="%CONFIGURATION.ICON.ATM_HALFLEVELS%"
export oce_levels="%CONFIGURATION.ICON.OCE_LEVELS%"
export oce_halflevels="%CONFIGURATION.ICON.OCE_HALFLEVELS%"

# End/Start dates
export start_date=$(date -u --date=$CHUNK_START_DATE $TIMEFORMAT)
export end_date=$(date -u --date=$CHUNK_END_DATE $TIMEFORMAT)

# Restart interval (uses mtime)
# Stops run - Generates restart files
export restart_interval="P${RUN_DAYS}D"
export checkpoint_interval="%SIMULATION.CHECKPOINT_INTERVAL%"

# Export FDB_HOME to load schema, FDB paths
export FDB_HOME

# Define Data Governance

# lib/common/util.sh (get_member_number) (auto generated comment)
realization=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

export EXPVER
export activity="%REQUEST.ACTIVITY%"
export experiment="%REQUEST.EXPERIMENT%"
export realization
export generation="%REQUEST.GENERATION%"
export resolution="%REQUEST.RESOLUTION%"

# Experiment name/id-definition
export EXPNAME="${EXPVER}_${SIM_NAME}"
export EXPDIR="${RUNDIR}"/run_"${CHUNK_START_DATE}"-"${CHUNK_END_DATE}"
export CHUNK_RESTART="${PRE_RESTART_DIR}"/"${CHUNK}"
export CURRENT_RESTART="${RESTART_DIR}"

# Remove rundir and restarts if it already exists
if [[ -d $EXPDIR ]] && [ $FAIL_COUNT -gt 0 ]; then
    echo "$(date): previous failed run detected, removing run dir '$EXPDIR' and restart dir '$CHUNK_RESTART' before starting new chunk run"
    rm -fvr "$EXPDIR" "$CHUNK_RESTART"
fi

# Create chunk and restart directory (or link if restarted)
if [[ "${CHUNK_FIRST,,}" == "true" && "${RESTARTED_RUN,,}" == "true" ]]; then
    # Rename restart files inside CHUNK_RESTART preserving the original
    # lib/common/utils/sim_utils.sh (rename_chunk_restarts) (auto generated comment)
    rename_chunk_restarts
    ln -snf "$CHUNK_RESTART" "$CURRENT_RESTART"
else
    mkdir -vp "$CHUNK_RESTART"
fi
mkdir -vp $EXPDIR && cd $EXPDIR

# Copy simulation runscript for run
cp "${SCRIPTDIR}/${RUNSCRIPT}" "${EXPNAME}".run

# Submission of ICON bash runscript
START_TIME=$(date +%s)
bash "${EXPNAME}".run
END_TIME=$(date +%s)

# Re-link restart directory to current
ln -snf $CHUNK_RESTART $CURRENT_RESTART

# Calculate runtime
RUNTIME=$((END_TIME - START_TIME))

# Format the runtime
RUNTIME_FORMATTED=$(date -u -d @${RUNTIME} +"%H:%M:%S")

echo -e "\n\n------------------------------------------------------"

# Check if the ICON chunk run has been sucessful
if [ -f finish.status ] && grep -q -e "OK" -e "RESTART" finish.status; then
    echo -e " - SUCCESSFUL run of chunk ${CHUNK_START_DATE}-${CHUNK_END_DATE} member ${MEMBER}\n"
    echo " - Total runtime: ${RUNTIME_FORMATTED} (hh:mm:ss)"
    echo -e "------------------------------------------------------\n\n"
else
    echo " - UNSUCCESSFUL run of chunk ${CHUNK_START_DATE}-${CHUNK_END_DATE} member ${MEMBER}"
    echo -e " - Check the .err .out at the Autosubmit LOGS folder\n"
    echo " - Total runtime: ${RUNTIME_FORMATTED} (hh:mm:ss)"
    echo -e "------------------------------------------------------\n\n"
    exit 1
fi
