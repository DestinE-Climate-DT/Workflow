#!/bin/bash
#
# This workflow step is in charge of performing basic checks as well as compressing the workflow project in order to be sent through the network

set -xuve

# Interface
ROOTDIR=${1:-%ROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL_NAME=${3:-%RUN.MODEL%}
HPCARCH=${4:-%HPCARCH%}
MODEL_VERSION=${5:-%RUN.MODEL_VERSION%}
ENVIRONMENT=${6:-%RUN.ENVIRONMENT%}
MODEL=${3:-%MODEL.MODEL_NAME%}
MODEL_SOURCE=${4:-%MODEL.SOURCE%}
MODEL_BRANCH=${5:-%MODEL.BRANCH%}
APP=${7:-%RUN.APP%}

LIBDIR="${ROOTDIR}"/proj/"${PROJDEST}"/lib

export ROOTDIR
export MODEL_NAME
export PROJDEST

export MODEL_VERSION
ATM_MODEL=${MODEL_NAME%%-*}

# Source libraries
. "${LIBDIR}"/common/util.sh
. "${LIBDIR}"/"${HPCARCH}"/config.sh

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

	IFS_PROCESSORS=$(($(($NODES-$IO_NODES))*$TASKS))

	if [ ! -z $NEMO_XPROC ] && [ ! -z $NEMO_YPROC ]; then
        	TOTAL_NEMO_PROCS=$(($NEMO_XPROC*$NEMO_YPROC))
	fi

	if [ $IFS_PROCESSORS = $TOTAL_NEMO_PROCS ]; then
        	echo "IFS processors match the total number of nemo processors (XPROC*YPROC)"
	elif [ -z $NEMO_XPROC ] && [ -z $NEMO_YPROC ]; then
        	echo "NEMO XPROC and NEMO YPROC will be automatically calculated"
	else
        	echo "Invalid xproc and yproc decomposition. Check NODES, IO_NODES, XPROC and YPROC variables."
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
	if [ ${MODEL_VERSION} == "None" ]; then
		echo "Bad definition of MODEL_VERSION." 
		echo "Insert a string if you want to use an existing precompiled binary (MODEL_VERSION: 'string')"
		echo "Or leave empty if you want the model to be automatically compiled (MODEL_VERSION: '')"
		echo "For more information, please see https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/wikis/Readme-for-advanced-users#how-to-use-your-own-input-data-and-model-installation"
		exit 1
	fi
}

# MAIN code

load_model_dir
load_inproot_precomp_path

# Download RAPS dependencies when needed  / Check out and update sources and submodules 
pre-configuration-${ATM_MODEL}

# configuration checker
checker_model_version
checker_${MODEL_NAME}

# Tar project 

cd "${ROOTDIR}"/proj
tar_project "${PROJDEST}"

# Remove the sent tarball flag
rm -f flag_tarball_sent 
