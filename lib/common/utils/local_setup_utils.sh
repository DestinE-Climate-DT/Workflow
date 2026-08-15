#!/bin/bash

# Utils functions for local_setup.sh

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
# Function used as a default. Overloaded
# by platform dependent functions in lib/HPCARCH
# Globals:
# Arguments:
#
#####################################################
function pre-configuration-nemo() {
    true
}

#####################################################
# Function used as a default. Overloaded
# by platform dependent functions in lib/HPCARCH
# Globals:
#   COMPILE
# Arguments:
#
#####################################################
function checker_nemo() {
    if [ "${COMPILE,,}" == "true" ]; then
        # compilation is currently not working for NEMO
        echo "Please set COMPILE to False and use a pre-compiled version for NEMO."
        exit 1
    else
        true
    fi
}

#####################################################
# Clone catalog
#    git@github.com:DestinE-Climate-DT/Climate-DT-catalog.git
# in path
#    $ROOTDIR/tmp/catalog
# at a given revision. If the repository exists,
# remove it first.
# Globals:
#   ROOTDIR
# Arguments:
#   catalog_ref
#####################################################
function clone_catalog() {
    catalog_ref=$1

    local catalog_dir="${ROOTDIR}/tmp/catalog"
    local catalog_repo="git@github.com:DestinE-Climate-DT/Climate-DT-catalog.git"

    if [ -z "${catalog_ref}" ]; then
        echo "Error: CATALOG_REF input for this function is missing. Define it under AQUA.CATALOG_REF in the experiment configuration, and make sure you are passing it as an input to this function."
        exit 1
    fi

    if [ -d "${catalog_dir}" ]; then
        echo "Removing existing catalog at ${catalog_dir}"
        rm -rf "${catalog_dir}"
    fi

    echo "Cloning Climate-DT-catalog into ${catalog_dir} at revision ${catalog_ref}"
    git clone "${catalog_repo}" "${catalog_dir}"
    git -C "${catalog_dir}" checkout "${catalog_ref}"
}

#####################################################
# Compresses specified directory using tar command
# Globals:
# Arguments:
#   Parent directory containing the target
#   Target directory name (relative to the parent)
#####################################################
function tar_directory() {
    work_dir=$1
    target=$2

    echo "Compressing ${work_dir}/${target}"
    tar -czvf "${work_dir}/${target}.tar.gz" -C "${work_dir}" "${target}"
}

#####################################################
# Checker for xproc and yproc variables in ifs-nemo.
# Globals:
#   IFS_IO_PPN
#   NEMO_IO_PPN
#   NODES
#   IO_NODES
#   TASKS
#   NEMO_XPROC
#   NEMO_YPROC
#   NEMO_IO_TASKS
#   NEMO_IO_NODES
#   IFS_IO_TASKS
#   IFS_IO_NODES
#####################################################
function checker_ifs-nemo() {

    IFS_IO_PPN=${IFS_IO_PPN:-0}
    NEMO_IO_PPN=${NEMO_IO_PPN:-0}

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
        echo 'Error: No resources selected for IFS or NEMO servers. Add IFS.IO_NODES and NEMO.IO_NODES or IFS.IO_TASKS and NEMO.IO_TASKS to the CONFIGURATION variables.'
        exit 1
    fi

}

function checker_icon() {
    true
}

function checker_ifs-fesom() {
    true
}

#####################################################
# Checks out the inputs from the DVC repository.
# Globals:
#   DVC_INPUTS_BRANCH
#   ROOTDIR
#   PROJDEST
# Arguments:
#####################################################
function inputs_checkout_ifs-nemo() {
    if [ -n "${DVC_INPUTS_BRANCH}" ]; then
        cd "${ROOTDIR}"/proj/"${PROJDEST}"/dvc-cache-de340/
        git checkout "${DVC_INPUTS_BRANCH}"
    fi
}

#####################################################
# Checks out the inputs from the DVC repository.
# Globals:
#   DVC_INPUTS_BRANCH
#   ROOTDIR
#   PROJDEST
# Arguments:
#####################################################
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
