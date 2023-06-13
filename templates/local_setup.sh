#!/bin/bash
#
# This workflow step is in charge of performing basic checks as well as compressing the workflow project in order to be sent through the network

set -xuve

# Interface
ROOTDIR=${1:-%ROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL=${3:-%MODEL.MODEL_NAME%}
MODEL_SOURCE=${4:-%MODEL.SOURCE%}
MODEL_BRANCH=${5:-%MODEL.BRANCH%}
PRECOMP_MODEL_PATH=${6:-%MODEL.PRECOMP_MODEL_PATH%}

LIBDIR="${ROOTDIR}"/proj/"${PROJDEST}"/lib

# Source libraries
. "${LIBDIR}"/common/util.sh

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

# MAIN code

cd "${ROOTDIR}"/proj
tar_project "${PROJDEST}"

# Remove the sent tarball flag
rm -f flag_tarball_sent 
