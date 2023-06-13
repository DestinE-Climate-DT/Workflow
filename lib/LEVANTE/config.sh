#!/bin/bash
#
# Configuration for LEVANTE platform

#####################################################
# Set the enviroment for compiling IFS
# Globals:
# Arguments:
#
######################################################
function load_compile_env_ifs() {
    # Enables modules in Levante
    source /sw/etc/profile.levante

    # Variables
    export NUMPROC=16
    export IFS_COMPILING_SCRIPT=config.intel.levante
}

#####################################################
# Set the enviroment for running IFS
# Globals:
#    HPCROOTDIR
# Arguments:
#
#####################################################
function load_SIM_env_ifs() {
    # Enables modules in Levante
    source /sw/etc/profile.levante

    # Variables
    export host=lum # should be lev, but that is not yet in the RAPS script
}

#####################################################
# Deletes IFS restarts
# Globals:
#    HPCROOTDIR
# Arguments:
#
#####################################################
function rm_restarts_ifs() {
    rm -rf $HPCROOTDIR/restarts
}

#####################################################
# Loads pre-compiled model directory
# Globals:
#    MODEL_NAME
# Arguments:
#
#####################################################
function load_model_dir(){
        export HPC_MODEL_DIR=/work/ab0995/DE340/models/${MODEL_NAME}
}
