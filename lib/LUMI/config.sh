#!/bin/bash
#
# Configuration for LUMI platform

#####################################################
# Set the enviroment for compiling IFS
# Globals:
# Arguments:
#
######################################################
function load_compile_env_ifs() {
    # Variables
    export NUMPROC=128
    export IFS_COMPILING_SCRIPT=config.cce.lumi
}

#####################################################
# Set the enviroment for running IFS
# Globals:
#    HPCROOTDIR
# Arguments:
#
#####################################################
function load_SIM_env_ifs() {
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
        export HPC_MODEL_DIR=/NOPATH/${MODEL_NAME}
}
