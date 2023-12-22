#!/bin/bash
#
# This step runs one chunk of climate simulation 

set -xuve

# Interface
HPCROOTDIR=${HPCROOTDIR:-%HPCROOTDIR%}
PROJDEST=${PROJDEST:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${CURRENT_ARCH:-%CURRENT_ARCH%}
MODEL_NAME=${MODEL_NAME:-%RUN.MODEL%}
MODEL_VERSION=${MODEL_VERSION:-%RUN.MODEL_VERSION%}
CHUNKSIZE=${CHUNKSIZE:-%EXPERIMENT.CHUNKSIZE%}
CHUNKSIZEUNIT=${CHUNKSIZEUNIT:-%EXPERIMENT.CHUNKSIZEUNIT%}
CHUNK_FIRST=${CHUNK_FIRST:-%CHUNK_FIRST%}
R_RUNSCRIPT_P=${RUNSCRIPT:-%SIMULATION.RUNSCRIPT%}
HPCARCH=${HPCARCH:-%HPCARCH%}
HETJOB=${HETJOB:-%SIMULATION.HETJOB%}

ENVIRONMENT=%RUN.ENVIRONMENT%
PU=%RUN.PROCESSOR_UNIT%

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$( echo "${CURRENT_ARCH}" | cut -d- -f1 )

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
    export MODEL_C="${basedir}"/build/16.0.1.1_rocm-5.4.1_cpu/bin/icon
    export MODEL_G="${basedir}"/build/16.0.1.1_rocm-5.4.1_gpu/bin/icon
elif [ "${PU}" = "cpu" ]; then
    export MODEL="${basedir}"/build/16.0.1.1_rocm-5.4.1_cpu/bin/icon
else
    echo "Unsupported processing unit"
    exit 1
fi

# Set output task to write to the FDB through the modified coupler
export OUTPUT_TASK="${basedir}"/build/yaco_16.0.1.1_rocm-5.4.1/yaco

# Set common test FDB path for diferent test runs
export FDB_PATH=/projappl/project_465000454/models/icon/outdata/fdb.test
export FDB_SCHEMA=/projappl/project_465000454/models/icon/outdata/schema

set | grep SLURM

export job_name=$SLURM_JOB_NAME


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
function load_experiment_icon(){

    # Experiment name/id-definition
    SIM_NAME="%SIMULATION.NAME%"
    EXPID="%DEFAULT.EXPID%"
    export EXPNAME="${EXPID}_${SIM_NAME}"
    
    export experiments_dir="${MODEL_DIR}"/experiments/rundir
    
    # If first run, set lrestart to ".FALSE."
    if [ ${CHUNK_FIRST} == "TRUE" ]; then
       export lrestart=".false."
       export restart_jsbach=".false."
       export initialize_fromrestart=".true."
       export read_initial_reservoirs=".true."
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

    # YACO output process timestep
    export outTimeStep="%SIMULATION.OUT_TSTEP%"

    # Internal YAC timestepping
    export atm_lag="%SIMULATION.ATM_LAG%"
    export oce_lag="%SIMULATION.OCE_LAG%"
    export out_lag="%SIMULATION.OUT_LAG%"
    
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
    export restart_interval="%SIMULATION.RESTART_INTERVAL%"    
    export checkpoint_interval="%SIMULATION.CHECKPOINT_INTERVAL%"
    
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
function run_experiment_icon(){
    # Define experiment output dir
    local EXP_OUTDIR=${experiments_dir}/${EXPNAME}
    # Enter runscript dir
    cd "${thisdir}"

    local R_RUNSCRIPT=$(basename "${R_RUNSCRIPT_P}")

    ./${R_RUNSCRIPT} 

    if [ -f finish.status ] && grep -q -e "OK" -e "RESTART" finish.status; then
        echo "Successful run of the chunk"
        export lrestart=".true."
        export restart_jsbach=".true."
        export initialize_fromrestart=".false."
        export read_initial_reservoirs=".false."
    else
        echo "Unsuccessful run"
        exit 1
    fi
}

# Loads HPC/Slurm (nodes,mpi,OpenMP) settings 
# Loads necessary packages (module load ...) 
# Exports necessary paths (input, output, restarts ...)
load_sim_env_"${MODEL_NAME%%-*}"_"${PU}"

# Defines simulation specifics
# Type of simulation
# Levels, startdates, chunksizes, etc...
load_experiment_"${MODEL_NAME%%-*}"

# Submits the actual experiment/simulations to the HPC
run_experiment_"${MODEL_NAME%%-*}"

