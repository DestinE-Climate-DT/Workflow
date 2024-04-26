#!/bin/bash
#
# Configuration for JUWELS platform

#####################################################
# Set the enviroment for compiling IFS
# Globals:
# Arguments:
#
######################################################
function load_compile_env_ifs() {
    # Variables
    export NUMPROC=48
    export IFS_COMPILING_SCRIPT=config.intel.juwels
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
    export host=blq
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
    export HPC_MODEL_DIR=/NOPATH/${MODEL_NAME}
}
