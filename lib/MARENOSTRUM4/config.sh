#!/bin/bash
#
# Configuration for BSC platform

#####################################################
# Loads and sets, most SIM variables needed by the
# ICON run-script. Some settings will be included
# custom confs
# Globals:
#    HPCROOTDIR
#    PROJDEST
#    INPROOT
# Arguments:
#
######################################################
function load_compile_env_icon_cpu() {

    local ICON_PATH=${HPCROOTDIR}/${PROJDEST}/icon-mpim

    # Load enviroment and create Makefile
    cd "${ICON_PATH}"

    # Check if Makefile already exists
    if [ ! -f Makefile ]; then
        ./config/bsc/marenostrum.intel.openmpi-4.0.2
    else
        echo "An old version of Makefile exists"
    fi
}

#####################################################
# Loads and sets, most SIM variables needed by the
# ICON run-script. Some settings will be included
# custom confs
# Globals:
#    HPCROOTDIR
#    PROJDEST
#    INPROOT
# Arguments:
#
######################################################
function load_SIM_env_icon_cpu() {
    #OpenMPI Enviroment vars
    export OMP_NUM_THREADS=$((4 * 1))
    export ICON_THREADS=$((4 * 1))
    export OMP_SCHEDULE="guided"
    export OMP_DYNAMIC="false"
    export OMP_STACKSIZE=1G
    export HDF5_USE_FILE_LOCKING=FALSE
    export FI_CXI_OPTIMIZED_MRS="false"

    # LD MN4 dependant enviroment vars
    module purge
    module load intel/2019.5
    module load openmpi/4.0.2
    module load hdf5/1.8.19

    # directories with absolute paths
    export MODEL_DIR="${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim
    export thisdir="${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim/run
    export basedir="${MODEL_DIR}"
    export icon_data_rootFolder="${INPROOT}"

    export MODEL="${basedir}"/bin/icon
    set | grep SLURM

    # how to submit the next job
    # --------------------------
    export job_name=$SLURM_JOB_NAME
}

#####################################################
# Set environment to be able to run gsv interface in mn4
# Globals:
#    HPCROOTDIR
# Arguments:
#
#####################################################
function load_environment_gsv() {
    set +xuve
    # Load modules
    set +xuve
    module purge
    module load mkl gcc/8.1.0 openmpi/4.0.2 python/3.10.2 hdf5/1.10.1-ts netcdf/4.6.1 eccodes/2.22.1-gcc-openmpi cmake/3.23.2 lapack/3.8.0 ecbuild/3.7.0 openblas/0.3.6 eckit/1.20.2 metkit/1.9.2 fdb/5.11.17 multio
    module load intel udunits
    module load CDO
    set -xuve

    export FDB5_CONFIG_FILE=$1/experiments/$2/config.yaml

    # GSV Config
    export GSV_WEIGHTS_PATH=/gpfs/scratch/dese28/dese28006/gsv_weights
    export GSV_TEST_FILES=/gpfs/scratch/dese28/dese28006/gsv_test_files
    export GRID_DEFINITION_PATH=/gpfs/scratch/dese28/dese28006/grid_definitions

    # Load interface src
    export PYTHONPATH=${HPCROOTDIR}/${PROJDEST}/gsv_interface:$PYTHONPATH
    set -xuve
}

#####################################################
# Set the enviroment for compiling IFS
# Set environment to be able to install/run opa
# Globals:
# Arguments:
#
######################################################
function load_compile_env_ifs_cpu() {
    # Variables
    module load git
    export NUMPROC=48
    export ARCH="arch/bsc/mn4/default"
    export OTHERS=""
}

#####################################################
# Set the enviroment for running IFS
# Globals:
#
# Arguments:
#
#####################################################
function load_SIM_env_ifs_cpu() {
    # Variables
    export host=mn4
    export bin_hpc_name=mn4
    export compiler="intel"
    module load impi/2017.4 intel/2017.4 mkl/2017.4 python/2.7.16 CMOR/3.5.0 CDO/1.8.2 gsl/2.4 nco/4.6.7 git eccodes/2.8.0
}

#####################################################
# Deletes IFS restarts
# Globals:
#    HPCROOTDIR
# Arguments:
#
#####################################################
function rm_restarts_ifs() {
    rm -rf "$HPCROOTDIR"/restarts
}

#####################################################
# Loads pre-compiled model directory
# Globals:
#    MODEL_NAME
# Arguments:
#
#####################################################
function load_model_dir() {
    export HPC_MODEL_DIR=/gpfs/projects/dese28/models/${MODEL_NAME}
}

#####################################################
# Downloads RAPS dependencies in the local setup
# Globals:
#    ROOTDIR, PROJDEST, MODEL_NAME
# Arguments:
#
#####################################################
function pre-configuration-ifs() {
    if [ -z "${MODEL_VERSION}" ]; then
        cd "${ROOTDIR}"/proj/"${PROJDEST}"/"${MODEL_NAME}"/
        ./ifs-bundle create
    fi
}
function load_environment_opa() {
    # Load modules
    #module purge
    #module load intel
    #module load mkl
    #module load python/3.10.2
    export PYTHONPATH=${HPCROOTDIR}/${PROJDEST}/one_pass:$PYTHONPATH
    set +xuve
    module load singularity
    set -xuve
}

################################################################
#################################################################

#####################################################
# Set environment to be able to run AQUA application
# Globals:
# Arguments:
#
######################################################
function load_environment_AQUA() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load python/3.10.2
    set -xuve

}

#####################################################
# Loads containers directory
# Globals:
#    MODEL_NAME
# Arguments:
#
#####################################################
function load_dirs() {
    module load singularity
    export HPC_CONTAINER_DIR=/gpfs/projects/dese28/containers
    export HPC_SCRATCH=/gpfs/scratch/dese28/
    export HPC_PROJECT=/gpfs/projects/dese28/
}

#####################################################
# Loads containers directory
# Globals:
#    MODEL_NAME
# Arguments:
#
#####################################################
function load_dirs() {
    set +xuve
    module load singularity
    set -xuve
    export HPC_CONTAINER_DIR=/gpfs/projects/dese28/containers
    export HPC_SCRATCH=/gpfs/scratch/dese28/
    export HPC_PROJECT=/gpfs/projects/dese28/
}

#####################################################
# Set environment to be able to run ENERGY_ONSHORE application
# Globals:
# Arguments:
#
######################################################
function load_environment_ENERGY_ONSHORE() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load python/3.10.2
    set -xuve
}

#####################################################
# Set environment to be able to run ENERGY_OFFSHORE application
# Globals:
# Arguments:
#
######################################################
function load_environment_ENERGY_OFFSHORE() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load python/3.10.2
    set -xuve
}

#####################################################
# Set environment to be able to run URBAN application
# Globals:
# Arguments:
#
######################################################
function load_environment_URBAN() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load python/3.10.2
    set -xuve
}

#####################################################
# Set environment to be able to run HYDROMET application
# Globals:
# Arguments:
#
######################################################
function load_environment_HYDROMET() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load python/3.10.2
    set -xuve
}

#####################################################
# Set environment to be able to run MHM application
# Globals:
# Arguments:
#
######################################################
function load_environment_MHM() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load python/3.10.2
    set -xuve
}

#####################################################
# Set environment to be able to run WILDFIRES_WISE application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_WISE() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load python/3.10.2
    set -xuve
}

#####################################################
# Set environment to be able to run WILDFIRES_SPITFIRE application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_SPITFIRE() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load python/3.10.2
    set -xuve
}

#####################################################
# Set environment to be able to run WILDFIRES_FWI application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_FWI() {

    # Load env modules
    module purge
    module load intel
    module load mkl
    module load python/3.10.2
}

#####################################################
# Set environment to be able to run WILDFIRES_FWI application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_FWI() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load python/3.10.2
    set -xuve
}

#####################################################
# Set environment to be able to run OBS application
# Globals:
# Arguments:
#
######################################################
function load_environment_OBS() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load python/3.10.2
    set -xuve
}

#####################################################
# installs opa
# Globals:
#       HPCROOTDIR
#       PROJDEST
# Arguments:
######################################################
function install_OPA() {
    # Currently packages for MN4 are loaded to PYTHONPATH in load_env
    echo "nothing is installed here"
}

#####################################################
# installs gsv interface
# Globals:
#       HPCROOTDIR
#       PROJDEST
# Arguments:
######################################################
function install_GSV_INTERFACE() {
    # Currently package sfor MN4 are loaded to PYTHONPATH in load_env
    echo "nothing is insalled here"
}

#####################################################
# Loads containers directory
# Globals:
#    MODEL_NAME
# Arguments:
#
#####################################################
function load_dirs() {
    export HPC_CONTAINER_DIR=/gpfs/projects/dese28/containers
    export HPC_SCRATCH=/gpfs/scratch/dese28/
    export HPC_PROJECT=/gpfs/projects/dese28/
}

#####################################################
# Set environment to be able to run opa in mn4
# Globals:
# Arguments:
#
######################################################
function load_environment_opa() {
    # Load modules
    #module purge
    #module load intel
    #module load mkl
    #module load python/3.10.2
    export PYTHONPATH=${HPCROOTDIR}/${PROJDEST}/one_pass:$PYTHONPATH
}
function rm_restarts_ifs() {
    rm -rf $HPCROOTDIR/restarts
}
