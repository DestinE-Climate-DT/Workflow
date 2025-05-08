#!/bin/bash
#
# This workflow step is in charge of performing basic checks as well as compressing the workflow project in order to be sent through the network

set -xuve

# HEADER

ROOTDIR=${1:-%ROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL_NAME=${3:-%MODEL.NAME%}
HPCARCH=${4:-%HPCARCH%}
MODEL_VERSION=${5:-%MODEL.VERSION%}
ENVIRONMENT=${6:-%RUN.ENVIRONMENT%}
DVC_INPUTS_BRANCH=${7:-%MODEL.DVC_INPUTS_BRANCH%}
APP=${8:-%APP.NAMES%}
WORKFLOW=${9:-%RUN.WORKFLOW%}
INSTALL=${10:-%CONFIGURATION.INSTALL%}
RUN_TYPE=${11:-%RUN.TYPE%}
COMPILE=${12:-%MODEL.COMPILE%}
USE_FIXED_DVC_COMMIT=${13:-%MODEL.USE_FIXED_DVC_COMMIT%}
AQUA_ON=${14:-%CONFIGURATION.ADDITIONAL_JOBS.AQUA%}

# END_HEADER

LIBDIR="${ROOTDIR}"/proj/"${PROJDEST}"/lib

export ROOTDIR
export MODEL_NAME
export PROJDEST
export INSTALL

export MODEL_VERSION
ATM_MODEL=${MODEL_NAME%%-*}

# Source libraries
. "${LIBDIR}"/common/util.sh
. "${LIBDIR}"/"${HPCARCH}"/config.sh
. "${LIBDIR}"/common/checkers.sh

#####################################################
# Compresses specified directory using tar command
# Globals:
# Arguments:
#   Project directory
#####################################################
function tar_project() {
    echo "Compressing project"
    PROJ=$1
    tar -czvf "${PROJ}".tar.gz "${PROJ}"

}

#####################################################
# Checker for xproc and yproc variables in ifs-nemo.
#####################################################
function checker_ifs-nemo() {
    NEMO_XPROC=%CONFIGURATION.IFS.NEMO_XPROC%
    NEMO_YPROC=%CONFIGURATION.IFS.NEMO_YPROC%

    TOTAL_NEMO_PROCS=-1

    IO_NODES=%CONFIGURATION.IFS.IO_NODES%

    # Put this into a lib function?
    NODES=%PLATFORMS.LUMI.NODES%
    TASKS=%PLATFORMS.LUMI.TASKS%

    IFS_IO_PPN=%CONFIGURATION.IFS.IO_PPN%
    IFS_IO_PPN=${IFS_IO_PPN:-0}
    NEMO_IO_PPN=%CONFIGURATION.NEMO.IO_PPN%
    NEMO_IO_PPN=${NEMO_IO_PPN:-0}
    IFS_IO_NODES=%CONFIGURATION.IFS.IO_NODES%
    NEMO_IO_NODES=%CONFIGURATION.NEMO.IO_NODES%
    IFS_IO_TASKS=%CONFIGURATION.IFS.IO_TASKS%
    NEMO_IO_TASKS=%CONFIGURATION.NEMO.IO_TASKS%

    IFS_PROCESSORS=$(($(($NODES - $IO_NODES)) * $TASKS))

    if [ ! -z $NEMO_XPROC ] && [ ! -z $NEMO_YPROC ]; then
        TOTAL_NEMO_PROCS=$(($NEMO_XPROC * $NEMO_YPROC))
    fi

    if [ $IFS_PROCESSORS = $TOTAL_NEMO_PROCS ]; then
        echo "IFS processors match the total number of nemo processors (XPROC*YPROC)"
    elif [ -z $NEMO_XPROC ] && [ -z $NEMO_YPROC ]; then
        echo "NEMO XPROC and NEMO YPROC will be automatically calculated"
    else
        echo "Invalid xproc and yproc decomposition. Check NODES, IO_NODES, XPROC and YPROC variables."
        exit 1
    fi

    # Undefined IO for NEMO, default configuration. Uses half of the IO resources for IFS and half for NEMO.
    if [ -z "${NEMO_IO_TASKS}" ] && [ -z "${NEMO_IO_NODES}" ] && [ -n "${IFS_IO_NODES}" ]; then
        echo "Same tasks for IFS and NEMO"
        echo "The io_flags used will be --io-tasks=(calculated in SIM) --nemo-multio-server-num=(calculated in SIM)"
    # Check for IFS and NEMO server resources
    elif [ -n "${IFS_IO_TASKS}" ] && [ -n "${NEMO_IO_TASKS}" ]; then
        echo "The io_flags used will be --io-tasks=${IFS_IO_TASKS} --nemo-multio-server-num=${NEMO_IO_TASKS}"
    elif [ -n "${IFS_IO_NODES}" ] && [ -n "${NEMO_IO_NODES}" ]; then
        echo "The io_flags used will be --io-nodes=${IFS_IO_NODES} --io-ppn=${IFS_IO_PPN} --nemo-multio-server-nodes=${NEMO_IO_NODES} --nemo-multio-server-ppn=${NEMO_IO_PPN}"
    else
        echo 'Error: No resources selected for IFS or NEMO servers. Add IFS_IO_NODES and NEMO_IO_NODES or IFS_IO_TASKS and NEMO_IO_TASKS variables.'
        exit 1
    fi

}

function checker_icon() {
    true
}

function checker_ifs-fesom() {
    true
}

function checker_model_version() {
    if [ "${MODEL_VERSION}" == "None" ]; then
        echo "Bad definition of MODEL_VERSION."
        echo "Insert a string if you want to use an existing precompiled binary (MODEL_VERSION: 'string')"
        echo "Or leave empty if you want the model to be automatically compiled (MODEL_VERSION: '')"
        echo "For more information, please see https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/wikis/Readme-for-advanced-users#how-to-use-your-own-input-data-and-model-installation"
        exit 1
    fi
}

# CHECKS OUT THE INPUTS FROM THE DVC REPOSITORY
function inputs_checkout_ifs-nemo() {
    if [ -n "${DVC_INPUTS_BRANCH}" ]; then
        cd "${ROOTDIR}"/proj/"${PROJDEST}"/dvc-cache-de340/
        git checkout "${DVC_INPUTS_BRANCH}"
    fi
}

function inputs_checkout_nemo() {
    if [ -n "${DVC_INPUTS_BRANCH}" ]; then
        cd "${ROOTDIR}"/proj/"${PROJDEST}"/dvc-cache-de340/
        git checkout "${DVC_INPUTS_BRANCH}"
    fi
}

function inputs_checkout_icon() {
    true
}

function inputs_checkout_ifs-fesom() {
    true
}

# MAIN code

# Run checks to see if submodules cloned correctly
# lib/common/checkers.sh (checker_submodules) (auto generated comment)
checker_submodules

# Download RAPS dependencies when needed  / Check out and update sources and submodules
if [ "${WORKFLOW,,}" == "model" ] || [ "${WORKFLOW,,}" == "end-to-end" ]; then
    if [ "${COMPILE}" == "True" ]; then
        pre-configuration-"${ATM_MODEL}"
    fi

    # configuration checker
    checker_model_version
    checker_"${MODEL_NAME}"
    if [ "${USE_FIXED_DVC_COMMIT,,}" == "false" ]; then
        inputs_checkout_"${MODEL_NAME}"
    fi
fi

# Check if RUN.TYPE is defined and is correct
# lib/common/checkers.sh (checker_run_type) (auto generated comment)
checker_run_type ${RUN_TYPE}

# Tar project

cd "${ROOTDIR}"/proj
tar_project "${PROJDEST}"

# Remove the sent tarball flag
rm -f flag_tarball_sent
