#!/bin/bash
#
# This step runs one chunk of climate simulation

set -xuve

# Interface
HPCROOTDIR=${HPCROOTDIR:-%HPCROOTDIR%}
PROJDEST=${PROJDEST:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${CURRENT_ARCH:-%CURRENT_ARCH%}
MODEL_NAME=${MODEL_NAME:-%MODEL.NAME%}
MODEL_VERSION=${MODEL_VERSION:-%MODEL.VERSION%}
CHUNKSIZE=${CHUNKSIZE:-%EXPERIMENT.CHUNKSIZE%}
CHUNKSIZEUNIT=${CHUNKSIZEUNIT:-%EXPERIMENT.CHUNKSIZEUNIT%}
CHUNK_FIRST=${CHUNK_FIRST:-%CHUNK_FIRST%}
RUN_DAYS=${RUN_DAYS:-%RUN_DAYS%}
R_RUNSCRIPT_P=${RUNSCRIPT:-%SIMULATION.RUNSCRIPT%}
HPCARCH=${HPCARCH:-%HPCARCH%}
SCRATCH_DIR=${SCRATCH_DIR:-%SCRATCH_DIR%}
PRODUCTION=${PRODUCTION:-%RUN.PRODUCTION%}
FDB_PROD=${FDB_PROD:-%CURRENT_FDB_PROD%}
FDB_DIR=${FDB_DIR:-%CURRENT_FDB_DIR%}
EXPID=${EXPID:-%DEFAULT.EXPID%}
SIM_NAME=${SIM_NAME:-%SIMULATION.NAME%}

ENVIRONMENT=%RUN.ENVIRONMENT%
PU=%RUN.PROCESSOR_UNIT%

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh

export MODEL_VERSION
export ENVIRONMENT
export HPCARCH

load_model_dir
load_inproot_precomp_path

# Main code

# Directory definition
if [ -z "${MODEL_VERSION}" ]; then
    export MODEL_DIR="${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim
else
    export MODEL_DIR=${PRECOMP_MODEL_PATH}
fi

# directories with absolute paths
export thisdir="${MODEL_DIR}"/run
export basedir="${MODEL_DIR}"
export icon_data_rootFolder="${INPROOT}"

# Switch binaries for ocean and atmosphere when using hetjobs
if [ "${PU}" = "gpu_gpu" ]; then
    export MODEL_C="${MODEL_DIR}"/build/icon_cpu/bin/icon
    export MODEL_G="${MODEL_DIR}"/build/icon_gpu/bin/icon
elif [ "${PU}" = "cpu" ]; then
    export MODEL="${MODEL_DIR}"/build/icon_cpu/bin/icon
else
    echo "Unsupported processing unit"
    exit 1
fi

# Set output task to write to the FDB through the modified coupler
export OUTPUT_TASK="${basedir}"/build/yaco_cpu/yaco

# Set FDB path and schema for diferent types of runs
if [ ${PRODUCTION,,} = "true" ]; then
    export FDB_HOME="${FDB_PROD}"
else
    export FDB_HOME="${FDB_DIR}/${EXPID}/fdb/HEALPIX_grids"
fi

set | grep SLURM

export job_name=$SLURM_JOB_NAME

#####################################################
# Translates ISO8601 time duration format to its
# equivalent in seconds.
# Globals:
# Arguments:
#  iso8601 time duration
######################################################
iso8601_to_seconds() {
    duration=$1
    seconds=0

    # Check if "M" (months) and/or "Y" (years) unit is present
    if [[ $"${duration%%T*}" =~ ('Y'|'M') ]]; then
        echo "Error: Yearly and/or monthly durations are not supported. Exiting."
        return 1
    fi

    # Extracting components (days, hours, minutes, seconds)
    for unit in D H M S; do
        value=$(echo $duration | grep -oP "\d+$unit" | sed "s/$unit//")
        if [ -n "$value" ]; then
            case $unit in
            D) ((seconds += value * 86400)) ;;
            H) ((seconds += value * 3600)) ;;
            M) ((seconds += value * 60)) ;;
            S) ((seconds += value)) ;;
            esac
        fi
    done

    echo $seconds
}

#####################################################
# Sets experiment dependent variables for the ICON
# simulation runscripts
# Globals:
#    HPCROOTDIR
#    PROJDEST
#    thisdir
# Arguments:
#
######################################################
function load_experiment_icon() {

    # Experiment name/id-definition
    export EXPNAME="${EXPID}_${SIM_NAME}"
    export experiments_dir="${HPCROOTDIR}"/rundir

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

    export nproma_atm="%CONFIGURATION.ICON.ATM_NPROMA%"
    export nproma_oce="%CONFIGURATION.ICON.OCE_NPROMA%"

    # Time stepping configuration
    export radTimeStep="%SIMULATION.RAD_TSTEP%"
    export atmTimeStep="%SIMULATION.ATM_TSTEP%"
    export oceTimeStep="%SIMULATION.OCE_TSTEP%"
    export couplingTimeStep="%SIMULATION.COUPLING_TSTEP%"
    export atmos_time_step_in_sec=$(iso8601_to_seconds "$atmTimeStep")
    export ocean_time_step_in_sec=$(iso8601_to_seconds "$oceTimeStep")

    # YACO output process timestep
    export yacoTimeStep="%SIMULATION.YACO_TSTEP%"
    export yaco_PT1H_CouplingTimeStep="%SIMULATION.YACO_PT1H_COUP_TSTEP%"
    export yaco_PT6H_CouplingTimeStep="%SIMULATION.YACO_PT6H_COUP_TSTEP%"
    export yaco_P1D_CouplingTimeStep="%SIMULATION.YACO_P1D_COUP_TSTEP%"

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
    start_date=$(date -u --date=%Chunk_START_DATE% %SIMULATION.TIMEFORMAT%)
    end_date=$(date -u --date=%Chunk_END_DATE% %SIMULATION.TIMEFORMAT%)
    next_date=$(date -u --date="$end_date -60 seconds" %SIMULATION.TIMEFORMAT%)

    export start_date
    export end_date
    export next_date

    # Restart interval (uses mtime)
    # Stops run - Generates restart files
    export restart_interval="P${RUN_DAYS}D"
    export checkpoint_interval="%SIMULATION.CHECKPOINT_INTERVAL%"

    # Define Data Governance
    if [ ${PRODUCTION,,} = "true" ]; then
        export EXPVER="0001"
    else
        export EXPVER="${EXPID}"
    fi
    export activity="%SIMULATION.DATA_GOV.ACTIVITY%"
    export experiment="%SIMULATION.DATA_GOV.EXPERIMENT%"
    export generation="%SIMULATION.DATA_GOV.GENERATION%"
    export realization="%SIMULATION.DATA_GOV.REALIZATION%"
    export resolution="%SIMULATION.DATA_GOV.RESOLUTION%"

    # LN script in rundir
    cd "${thisdir}"
    ln -sf "${HPCROOTDIR}"/"${PROJDEST}"/lib/runscript/"${R_RUNSCRIPT_P}" .
}

#####################################################
# Submits the SIM runscript
# Globals:
#    thisdir
#    RUNSCRIPT
# Arguments:
#
######################################################
function run_experiment_icon() {
    # Enter runscript dir
    cd "${thisdir}"

    local R_RUNSCRIPT=$(basename "${R_RUNSCRIPT_P}")
    ./${R_RUNSCRIPT}

    if [ -f finish.status ] && grep -q -e "OK" -e "RESTART" finish.status; then
        echo "Successful run"
    else
        echo "Unsuccessful run"
        exit 1
    fi
}

# Loads HPC/Slurm (nodes,mpi,OpenMP) settings
# Loads necessary packages (module load ...)
# Exports necessary paths (input, output, restarts ...)
load_SIM_env_"${MODEL_NAME%%-*}"_"${PU}"

# Defines simulation specifics
# Type of simulation
# Levels, startdates, chunksizes, etc...
load_experiment_"${MODEL_NAME%%-*}"

# Submits the actual experiment/simulations to the HPC
run_experiment_"${MODEL_NAME%%-*}"
