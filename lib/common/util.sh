#!/bin/bash

#####################################################
# In platforms where internet connection is not
# available, we need to download raps dependencies
# in the local setup
# This function will be overwritten in platforms
# without internet access.
# Globals:
# Arguments:
#
#####################################################

function pre-configuration-ifs() {
    true
}

#####################################################
# Function used as a default. Overloaded
# by platform dependent functions in lib/HPCARCH
# Globals:
# Arguments:
#
#####################################################
function pre-configuration-icon() {
    true
}

#####################################################
# Passes the SLURM variables onto variables used
# in hres for IFS-based models.
function load_variables_ifs() {
    export nodes=${SLURM_JOB_NUM_NODES}
    export mpi=${SLURM_NPROCS}
    export omp=${SLURM_CPUS_PER_TASK}

    export jobid=${SLURM_JOB_ID}
    export jobname=${SLURM_JOB_NAME}
}

#####################################################
# Default paths for the INPROOT and the PRECOMP_MODEL_PATH
# for all the models.
#
# Globals: HPC_MODEL_DIR, MODEL_VERSION, HPCARCH, ENVIRONMENT
# Arguments:
#
#####################################################
function load_inproot_precomp_path() {
    # If pre-compiled version used load specific input files and binaries
    # Otherwise load default input data
    if [ -z "${INPUTS:-""}" ]; then
        # don't take inputs from dvc
        if [ -z "${MODEL_VERSION}" ]; then
            echo "Model version is not defined. Compiles in the worfklow. Default inidata"
            export INPROOT=${HPC_MODEL_DIR}/inidata
        else
            echo "Model version is defined. Use the inputs from the model"
            export INPROOT=${HPC_MODEL_DIR}/${MODEL_VERSION}/inidata
            export PRECOMP_MODEL_PATH=${HPC_MODEL_DIR}/${MODEL_VERSION}/make/${HPCARCH,,}-${ENVIRONMENT}
        fi
    else
        echo "Taking inputs from dvc"
        export INPROOT=${HPCROOTDIR}/${PROJDEST}/dvc-cache-de340

        if [ -z "${MODEL_VERSION}" ]; then
            echo "Model version is not defined. Compiles in the workflow."
        else
            echo "Model version is defined."
            export PRECOMP_MODEL_PATH=${HPC_MODEL_DIR}/${MODEL_VERSION}/make/${HPCARCH,,}-${ENVIRONMENT}
        fi
    fi
}

#####################################################
# Loads MULTIO variables:
# MULTIO_ACTIVITY and MULTIO_EXPERIMENT
# To use them in the requests
# Globals:
#
# Arguments:
#    EXPERIMENT
#####################################################
function export_MULTIO_variables() {
    # Logic from IFS HRES script
    if [[ "$1" = "hist" ]]; then
        MULTIO_ACTIVITY="CMIP6"
        MULTIO_EXPERIMENT="hist"
    elif [[ "$1" = "control" ]]; then
        MULTIO_ACTIVITY="HighResMIP"
        MULTIO_EXPERIMENT="cont"
    elif [[ "$1" =~ ^SSP* ]]; then
        MULTIO_ACTIVITY="ScenarioMIP"
        if [[ "$1" = "SSP370" ]]; then
            MULTIO_EXPERIMENT="SSP3-7.0"
        elif [[ "$1" = "SSP585" ]]; then
            MULTIO_EXPERIMENT="SSP5-8.5"
        elif [[ "$1" = "SSP245" ]]; then
            MULTIO_EXPERIMENT="SSP2-4.5"
        elif [[ "$1" = "SSP126" ]]; then
            MULTIO_EXPERIMENT="SSP1-2.6"
        elif [[ "$1" = "SSP119" ]]; then
            MULTIO_EXPERIMENT="SSP1-1.9"
        else
            echo "Unsupported scenario experiment type."
            exit 1
        fi
    elif [[ "$1" = "cycle3" ]]; then
        MULTIO_ACTIVITY="HighResMIP"
        MULTIO_EXPERIMENT="cont"
    else
        echo "Unsupported experiment type."
        exit 1
    fi

    export MULTIO_ACTIVITY
    export MULTIO_EXPERIMENT
}

#####################################################
# Deletes IFS rundir in the INI step for a clean run
# Globals:
#    HPCROOTDIR
# Arguments:
#
#####################################################
function rm_rundir_ifs() {
    rm -rf "$HPCROOTDIR"/rundir
}

#####################################################
# Deletes ICON rundir in the INI step for a clean run
# Globals:
#    HPCROOTDIR
# Arguments:
#
#####################################################
function rm_rundir_icon() {
    true
}

#####################################################
# Computes the member number, taking the list from
# %EXPERIMENT.MEMBERS% and %MEMBER%
# Globals:
# Arguments:
# MEMBERS_LIST
# MEMBER
#
#####################################################
function get_member_number() {
    MEMBERS_LIST=$1
    MEMBER=$2

    # Split MEMBERS_LIST into an array
    read -r -a MEMBERS_ARRAY <<<"$MEMBERS_LIST"

    # Find the index of the MEMBER in MEMBERS_ARRAY
    MEMBER_NUMBER=0
    for i in "${!MEMBERS_ARRAY[@]}"; do
        if [ "${MEMBERS_ARRAY[$i]}" == "$MEMBER" ]; then
            MEMBER_NUMBER=$((i + 1))
            break
        fi
    done

    # Print or use the computed MEMBER_NUMBER as needed
    if [ "$MEMBER_NUMBER" -ne 0 ]; then
        echo "Member number: $MEMBER_NUMBER"
    else
        echo "Member not found in the list."
        exit 1
    fi
}

#####################################################
# Function to set data governance parameters based on the provided key.
# Parameters:
#   - KEY: The key to determine the data governance parameters.
#         Possible values are "PRODUCTION", "RESEARCH", "PRE-PRODUCTION", and "TEST".
#         If an unsupported key is provided, the function will exit with an error.
# Returns:
#   - None
#####################################################

function set_data_gov() {
    KEY=${1^^}

    PRODUCTION_EXPID="0001"

    if [[ "$KEY" = "PRODUCTION" ]]; then
        CLASS="d1"
        EXPVER=${PRODUCTION_EXPID}
        FDB_TYPE="PROD"
        echo "Production run."
    elif [[ "$KEY" = "RESEARCH" ]]; then
        CLASS="d1"
        EXPVER=${EXPID}
        FDB_TYPE="PROD"
        echo "Research run."
    elif [[ "$KEY" = "PRE-PRODUCTION" ]]; then
        CLASS="d2"
        EXPVER=${PRODUCTION_EXPID}
        FDB_TYPE="LOCAL"
        echo "Pre-production run."
    elif [[ "$KEY" = "TEST" ]]; then
        CLASS="d2"
        EXPVER=${EXPID}
        FDB_TYPE="LOCAL"
        echo "Test run."
    else
        echo "Unsupported key."
        exit 1
    fi

    echo "The experiment id in the FDB will be ${EXPVER}. The class will be d1. d2 class is work in progress"

    export CLASS
    export EXPVER
    export FDB_TYPE

}
