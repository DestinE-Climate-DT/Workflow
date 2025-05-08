#!/bin/bash
# Configuration for LUMI platform

#####################################################
# Set environment to be able to run DUMMY application
# Globals:
# Arguments:
#
######################################################
function load_environment_DUMMY() {

    # Load env modules
    module load LUMI/23.09
    module load partition/C
    module load PrgEnv-gnu
    module load GObject-Introspection/1.72.0-cpeGNU-23.09-cray-python3.9

}

#####################################################
# Set environment to be able to run opa in lumi
# Globals:
# Arguments:
#
######################################################
function load_environment_opa() {
    # Load modules
    set +xuve
    true
    set -xuve
}

#####################################################
# Set environment to be able to run AQUA application
# Globals:
# Arguments:
#
######################################################
function load_environment_AQUA() {
    set +xuve
    #module purge
    set -xuve
}

#####################################################
# Set environment to be able to run ENERGY_ONSHORE application
# Globals:
# Arguments:
#
######################################################
function load_environment_ENERGY_ONSHORE() {
    set +xuve
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C

    # Load modules
    ml ecCodes/2.33.0-cpeCray-23.03
    ml fdb/5.11.94-cpeCray-23.03
    ml metkit/1.11.0-cpeCray-23.03
    ml eckit/1.25.0-cpeCray-23.03
    ml python-climatedt/3.11.7-cpeCray-23.03
    set -xuve
}

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
# Loads pre-compiled model directory
# TODO: check the headers

# Set environment to be able to run ENERGY_OFFSHORE application
# Globals:
# Arguments:
#
######################################################
function load_environment_ENERGY_OFFSHORE() {
    set +xuve
    # Load env modules
    module load LUMI/23.09
    module load partition/C
    module load PrgEnv-gnu
    module load GObject-Introspection/1.72.0-cpeGNU-23.09-cray-python3.9
    set -xuve
}

#####################################################
# Set environment to be able to run URBAN application
# Globals:
# Arguments:
#
######################################################
function load_environment_URBAN() {
    set +xuve
    # Load env modules
    module load LUMI/23.09
    module load partition/C
    module load PrgEnv-gnu
    module load GObject-Introspection/1.72.0-cpeGNU-23.09-cray-python3.9
    set -xuve
}

#####################################################
# Set environment to be able to run HYDROMET application
# Globals:
# Arguments:
#
######################################################
function load_environment_HYDROMET() {
    set +xuve
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C

    # Load modules
    ml ecCodes/2.33.0-cpeCray-23.03
    ml fdb/5.11.94-cpeCray-23.03
    ml metkit/1.11.0-cpeCray-23.03
    ml eckit/1.25.0-cpeCray-23.03
    ml python-climatedt/3.11.7-cpeCray-23.03
    set -xuve
}

#####################################################
# Set environment to be able to run WILDFIRES_WISE application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_WISE() {
    set +xuve
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C

    # Load modules
    ml ecCodes/2.33.0-cpeCray-23.03
    ml fdb/5.11.94-cpeCray-23.03
    ml metkit/1.11.0-cpeCray-23.03
    ml eckit/1.25.0-cpeCray-23.03
    ml python-climatedt/3.11.7-cpeCray-23.03
    set -xuve
}

#####################################################
# Set environment to be able to run WILDFIRES_SPITFIRE application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_SPITFIRE() {
    set +xuve
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C

    # Load modules
    ml ecCodes/2.33.0-cpeCray-23.03
    ml fdb/5.11.94-cpeCray-23.03
    ml metkit/1.11.0-cpeCray-23.03
    ml eckit/1.25.0-cpeCray-23.03
    ml python-climatedt/3.11.7-cpeCray-23.03 # Load env modules
    set -xuve
}

#####################################################
# Set environment to be able to run WILDFIRES_FWI application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_FWI() {

    set +xuve
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C

    # Load modules
    ml ecCodes/2.33.0-cpeCray-23.03
    ml fdb/5.11.94-cpeCray-23.03
    ml metkit/1.11.0-cpeCray-23.03
    ml eckit/1.25.0-cpeCray-23.03
    ml python-climatedt/3.11.7-cpeCray-23.03
    set -xuve
}

#####################################################
# Set environment to be able to run OBSALL application
# Globals:
# Arguments:
#
######################################################
function load_environment_OBSALL() {
    set +xuve
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C
    # Load modules
    # required by SYNOP, RADSOUND (TEMP), SATELLITE (AMSU-A) Parts of OBSALL Apps
    module load LUMI/23.03
    module load partition/C
    module load PrgEnv-gnu
    module load ecCodes/2.32.0-cpeCray-23.03.lua
    module load odb_api/0.18.1-cpeCray-23.03.lua
    module load python-climatedt/3.11.3-cpeCray-23.03.lua
    module load pyfdb/0.0.2-cpeCray-23.03.lua
    module load cray-hdf5/1.12.2.3
    module load cray-netcdf/4.9.0.3
    module load rttov/13.2
    module load radsim/3.2
    module load fdb/5.11.94-cpeCray-23.03.lua
    module load eckit/1.25.0-cpeCray-23.03.lua
    module load metkit/1.11.0-cpeCray-23.03.lua
    set -xuve
}

###################################################
## Loads environment for backup job
###################################################
function load_backup_env() {
    module load LUMI/23.03
    module load parallel
}

#####################################################
# installs ENERGY_OFFSHORE application
# Globals:
# Arguments:
######################################################
function install_ENERGY_OFFSHORE() {
    pip install EnergyOffshore
}

function load_compile_env_nemo_cpu() {
    true

}

function load_singularity() {
    echo "Singularity is already loaded"
}
