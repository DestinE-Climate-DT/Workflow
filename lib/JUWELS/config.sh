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
