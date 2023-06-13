#!/bin/bash
#
# This step runs one chunk of climate simulation 

set -xuve

# Interface
HPCROOTDIR=${HPCROOTDIR:-%HPCROOTDIR%}
PROJDEST=${PROJDEST:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${CURRENT_ARCH:-%CURRENT_ARCH%}
MODEL_NAME=${MODEL_NAME:-%MODEL.NAME%}
MODEL_VERSION=${MODEL_VERSION:-%RUN.MODEL_VERSION%}
CHUNKSIZE=${CHUNKSIZE:-%SIMULATION.CHUNKSIZE%}
CHUNKSIZEUNIT=${CHUNKSIZEUNIT:-%SIMULATION.CHUNKSIZEUNIT%}
RUNSCRIPT=${RUNSCRIPT:-%CONFIGURATION.ICON.RUNSCRIPT%}
HPCARCH=${HPCARCH:-%HPCARCH%}

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
if [  ! -d "${PRECOMP_MODEL_PATH}" ]; then
    export MODEL_DIR="${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim
else
    export MODEL_DIR=${PRECOMP_MODEL_PATH}
fi

# directories with absolute paths
export thisdir="${MODEL_DIR}"/run
export basedir="${MODEL_DIR}"
export icon_data_rootFolder="${INPROOT}"

export MODEL="${basedir}"/bin/icon
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
    # Experiment name-definition
    export EXPNAME="%SIMULATION.NAME%"
    export experiments_dir="${MODEL_DIR}"/experiments/rundir
    
    if [ ! -d "$(experiments_dir)"/"$(EXPNAME)" ]; then
	export lrestart=".FALSE."
    fi 
    # Grid Configuration
    export atmos_gridID="%CONFIGURATION.ICON.ATM_GID%"
    export atmos_refinement="%CONFIGURATION.ICON.ATM_REF%"

    export ocean_gridID="%CONFIGURATION.ICON.OCE_GID%"
    export ocean_refinement="%CONFIGURATION.ICON.OCE_REF%"

    export nproma_atm="%CONFIGURATION.ICON.ATM_NPROMA%"
    export nproma_oce="%CONFIGURATION.ICON.OCE_NPROMA%"

    # End/Start dates
    start_date=$(date -u --date=%Chunk_START_DATE% %SIMULATION.TIMEFORMAT%)
    export start_date
    end_date=$(date -u --date=%Chunk_END_YEAR%%Chunk_END_MONTH%%Chunk_END_DAY% %SIMULATION.TIMEFORMAT%)
    export end_date

    # Restart interval (uses mtime)
    # Stops run - Generates restart files
    export restart_interval="%SIMULATION.RESTART_INTERVAL%"    
    export checkpoint_interval="%SIMULATION.CHECKPOINT_INTERVAL%"
    
    local PROJ_RUNSCRIPT_PATH="${HPCROOTDIR}"/"${PROJDEST}"/lib/runscript/exp.icon_r2b4_climateDT.run
    
    cd "${thisdir}"
    # Temporal LN of runscripts
    if [ ! -f exp.icon_r2b4_climateDT.run ]; then
    	ln -s "${PROJ_RUNSCRIPT_PATH}" .
    else
    	echo "Run-script already present"
    fi    
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
    # Submit experiment
    ./"${RUNSCRIPT}"

    cd "${EXP_OUTDIR}"
    if [ -f finish.status ] && grep -q -e "OK" -e "RESTART" finish.status; then
        echo "Succesful run of the chunk"
        export lrestart=".TRUE."
    else
        echo "Unsuccesful run"
        exit 1
    fi
}

# Loads HPC/Slurm (nodes,mpi,OpenMP) settings 
# Loads necessary packages (module load ...) 
# Exports necessary paths (input, output, restarts ...)
load_sim_env_"${MODEL_NAME%%-*}"

# Defines simulation specifics
# Type of simulation
# Levels, startdates, chunksizes, etc...
load_experiment_"${MODEL_NAME%%-*}"

# Submits the actual experiment/simulations to the HPC
run_experiment_"${MODEL_NAME%%-*}"

