#!/bin/bash
#
# Configuration for BSC platform

#####################################################
# Set the enviroment for generating the ICON Makefile
# Globals:
#    HPCROOTDIR
#    PROJDEST
# Arguments:
#  
######################################################
function load_compile_env_icon() {

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
# Deletes ICON restarts, preliminary  solution as 
# restart logic hasn't been fully decided yet
# Globals:
#    HPCROOTDIR
# Arguments:
#  
#####################################################
function rm_restarts_icon() {
   # Delete restarts for clean new run 
   if [ -d "${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim/experiments ]; then
         rm -rf "${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim/experiments
   else
        echo "Restart files don't exist"
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
function load_sim_env_icon() {
    #OpenMPI Enviroment vars
    export OMP_NUM_THREADS=$((4*1))
    export ICON_THREADS=$((4*1))
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
}


#####################################################
# Set the enviroment for compiling IFS
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
function load_model_dir(){
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

#####################################################
# Checks out know working branch and submodules of 
#    ICON on MN4
# Globals:
#    ROOTDIR
#    PROJDEST
# Arguments:
#
#####################################################
function pre-configuration-icon(){
    
    cd "${ROOTDIR}"/proj/"${PROJDEST}"/icon-mpim
    git checkout 3deba29a732941f2a300834595fa01736f9ed629
}
