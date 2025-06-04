#!/bin/bash
# Configuration for LUMI platform

#####################################################
# Loads and sets, most SIM variables needed by the
# ICON run-script. Some settings will be included
# custom confs
# Globals:
# Arguments:
#
######################################################
function load_SIM_env_icon_gpu() {

    # OpenMP environment variables
    # ----------------------------
    export SLURM_GPUS_ON_NODE=8

    export OMP_SCHEDULE="guided"
    export OMP_DYNAMIC="false"

    export HDF5_USE_FILE_LOCKING=FALSE

    export FI_MR_CACHE_MONITOR="memhooks"

    export FI_CXI_OPTIMIZED_MRS="false"
    export FI_CXI_RX_MATCH_MODE="hybrid"
    export FI_CXI_OFLOW_BUF_COUNT=6
    export FI_CXI_RDZV_PROTO="sw_read_rdzv"

    export MPICH_ALLREDUCE_NO_SMP=1
    export MPICH_COLL_OPT_OFF=1               # maybe only needed when running on LUMI-G and LUMI-C
    export MPICH_OFI_SKIP_NIC_SYMMETRY_TEST=1 # only needed when running on LUMI-G and LUMI-C

    export SBATCH_NO_REQUEUE=1 # to avoid automatic resubmission after node failure

    export PMI_SIGNAL_STARTUP_COMPLETION=1
}

#####################################################
# Set environment to be able to run OBSALL application
# Globals:
# Arguments:
#
######################################################
function load_environment_OBSALL() {
    # Function removed to avoid exposing sensitive information
    true
}

###################################################
## Loads environment for backup job
###################################################
function load_backup_env() {
    module load LUMI/23.03
    module load parallel
}

function load_compile_env_nemo_cpu() {
    true
}

function load_singularity() {
    echo "Singularity is already loaded"
}

#####################################################
# Purges duplicate data then retrieves and creates the
# requests for the FDB transfer.
# Globals:
#   CONTAINER_COMMAND
#   FDB_HOME
#   EXPVER
#   START_DATE
#   CHUNK
#   SECOND_TO_LAST_DATE
#   EXPERIMENT
#   MODEL_NAME
#   ACTIVITY
#   REALIZATION
#   GENERATION
#   LIBDIR
#   GRIB_FILE_NAME
#   SCRIPTDIR
#   BASE_NAME
#   CHUNK_SECOND_TO_LAST_DATE
#   TRANSFER_REQUESTS_PATH
#   TRANSFER_MONTHLY
#   SCRATCH_DIR
#   HPC
#   MARS_BINARY
# Arguments:
#   profile_file
######################################################
function fdb_transfer() {

    profile_file=$1

    purge_duplicated_data ${profile_file}
    retrieve_and_create_requests ${profile_file}
}

function rsync_datamover() {
    true
}
