#!/bin/bash
#
# This step runs one chunk of climate simulation

set -xuve

# HEADER
HPCROOTDIR=%HPCROOTDIR%
PROJDEST=%PROJECT.PROJECT_DESTINATION%
CURRENT_ARCH=${3:-%CURRENT_ARCH%}
MODEL_NAME=${4:-%MODEL.NAME%}
MODEL_VERSION=${5:-%MODEL.VERSION%}
CHUNKSIZE=${6:-%EXPERIMENT.CHUNKSIZE%}
CHUNKSIZEUNIT=${7:-%EXPERIMENT.CHUNKSIZEUNIT%}
CHUNK_FIRST=${8:-%CHUNK_FIRST%}
CHUNK_START_DATE=${9:-%Chunk_START_DATE%}
CHUNK_END_DATE=${10:-%Chunk_END_DATE%}
RUN_DAYS=${11:-%RUN_DAYS%}
TIMEFORMAT=${12:-%SIMULATION.TIMEFORMAT%}
RUNSCRIPT=${13:-%SIMULATION.RUNSCRIPT%}
HPCARCH=${14:-%HPCARCH%}
SCRATCH_DIR=${15:-%SCRATCH_DIR%}
RUN_TYPE=${16:-%RUN.TYPE%}
FDB_HOME=${17:-%REQUEST.FDB_HOME%}
EXPID=${18:-%DEFAULT.EXPID%}
EXPVER=${19:-%REQUEST.EXPVER%}
SIM_NAME=${20:-%SIMULATION.NAME%}
LIBDIR=${21:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${22:-%CONFIGURATION.SCRIPTDIR%}
ENVIRONMENT=${23:-%RUN.ENVIRONMENT%}
PU=${24:-%RUN.PROCESSOR_UNIT%}
MODEL_PATH=${25:-%MODEL.PATH%}
MODEL_INPUTS=${26:-%MODEL.INPUTS%}

# END_HEADER

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh

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
export YACO_DIR="${MODEL_PATH}"/yaco
export YACO="${YACO_DIR}"/build/current/yaco

# Check if MODEL_G and MODEL_C and YACO exist
if [ ! -f "${MODEL_G}" ] || [ ! -f "${MODEL_C}" ] || [ ! -f "${YACO}" ]; then
    echo "One or more required binaries not found:"
    [ ! -f "${MODEL_G}" ] && echo "Model GPU binary not found: ${MODEL_G}"
    [ ! -f "${MODEL_C}" ] && echo "Model CPU binary not found: ${MODEL_C}"
    [ ! -f "${YACO}" ] && echo "YACO binary not found: ${YACO}"
    exit 1
fi

# Loads HPC/Slurm (nodes,mpi,OpenMP) settings
# Loads necessary packages (module load ...)
# Exports necessary paths (input, output, restarts ...)
load_SIM_env_"${MODEL_NAME%%-*}"_"${PU}"

# If first run, set lrestart to ".FALSE."
if [ ${CHUNK_FIRST} == "TRUE" ]; then
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
export atmos_time_step_in_sec=$(iso8601_to_seconds "$atmTimeStep")
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
export EXPVER
export activity="%REQUEST.ACTIVITY%"
export experiment="%REQUEST.EXPERIMENT%"
export generation="%REQUEST.GENERATION%"
export realization="%REQUEST.REALIZATION%"
export resolution="%REQUEST.RESOLUTION%"

# Experiment name/id-definition
export EXPNAME="${EXPVER}_${SIM_NAME}"
export experiments_dir="${HPCROOTDIR}"/rundir
export EXPDIR="${experiments_dir}"/run_${CHUNK_START_DATE}-${CHUNK_END_DATE}

# Remove rundir if it already exists
if [[ -d $EXPDIR ]]; then
    echo "$(date): removing run dir '$EXPDIR'"
    rm -fvr $EXPDIR
fi

# Create chunk directory
mkdir -vp $EXPDIR && cd $EXPDIR

# Copy simulation runscript for run
cp "${SCRIPTDIR}/${RUNSCRIPT}" "${EXPNAME}".run

# Submission of ICON bash runscript
START_TIME=$(date +%s)
bash "${EXPNAME}".run
END_TIME=$(date +%s)

# Calculate runtime
RUNTIME=$((END_TIME - START_TIME))

# Format the runtime
RUNTIME_FORMATTED=$(date -u -d @${RUNTIME} +"%H:%M:%S")

echo -e "\n\n------------------------------------------------------"

# Check if the ICON chunk run has been sucessful
if [ -f finish.status ] && grep -q -e "OK" -e "RESTART" finish.status; then
    echo -e " - SUCCESSFUL run of chunk ${CHUNK_START_DATE}-${CHUNK_END_DATE}\n"
    echo " - Total runtime: ${RUNTIME_FORMATTED} (hh:mm:ss)"
    echo -e "------------------------------------------------------\n\n"
else
    echo " - UNSUCCESSFUL run of chunk ${CHUNK_START_DATE}-${CHUNK_END_DATE}"
    echo -e " - Check the .err .out at the Autosubmit LOGS folder\n"
    echo " - Total runtime: ${RUNTIME_FORMATTED} (hh:mm:ss)"
    echo -e "------------------------------------------------------\n\n"
    exit 1
fi
