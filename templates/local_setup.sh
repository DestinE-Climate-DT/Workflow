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
DOWNLOAD_ADDITIONAL_DEPENDENCIES=${15:-%CONFIGURATION.DOWNLOAD_ADDITIONAL_DEPENDENCIES%}
DATELIST=${16:-%EXPERIMENT.DATELIST%}
CLEAN_RESTARTS_ON=${17:-%CONFIGURATION.ADDITIONAL_JOBS.CLEAN_RESTARTS%}
BACKUP_ON=${18:-%CONFIGURATION.ADDITIONAL_JOBS.BACKUP%}

# END_HEADER

LIBDIR="${ROOTDIR}"/proj/"${PROJDEST}"/lib

export ROOTDIR
export MODEL_NAME
export PROJDEST
export INSTALL

export MODEL_VERSION
ATM_MODEL=${MODEL_NAME%%-*}

# Source libraries
. "${LIBDIR}"/common/utils/local_setup_utils.sh
. "${LIBDIR}"/"${HPCARCH}"/config.sh
. "${LIBDIR}"/common/checkers.sh

# lib/common/checkers.sh (checker_backup_on_if_clean_restarts) (auto generated comment)
checker_backup_on_if_clean_restarts

# MAIN code

# Run checks to see if submodules cloned correctly
# lib/common/checkers.sh (checker_submodules) (auto generated comment)
checker_submodules

# Download RAPS dependencies when needed  / Check out and update sources and submodules
if [ "${DOWNLOAD_ADDITIONAL_DEPENDENCIES,,}" == "true" ]; then
    if [ "${COMPILE}" == "True" ]; then
        # lib/common/utils/local_setup_utils.sh (manually generated comment)
        # lib/MARENOSTRUM5/config.sh (pre-configuration-ifs) (manually generated comment)
        pre-configuration-"${ATM_MODEL}"
    fi

    # configuration checker
    # lib/common/checkers.sh (checker_model_version) (auto generated comment)
    checker_model_version
    # lib/common/utils/local_setup_utils.sh (manually generated comment)
    checker_"${MODEL_NAME}"
    if [ "${USE_FIXED_DVC_COMMIT,,}" == "false" ]; then
        # lib/common/utils/local_setup_utils.sh (manually generated comment)
        inputs_checkout_"${MODEL_NAME}"
    fi
fi

# Check if RUN.TYPE is defined and is correct
# lib/common/checkers.sh (checker_run_type) (auto generated comment)
checker_run_type ${RUN_TYPE}

# Tar project

cd "${ROOTDIR}"/proj
# lib/common/utils/local_setup_utils.sh (tar_project) (auto generated comment)
tar_project "${PROJDEST}"

# Remove the sent tarball flag
flag_tarball_path="${ROOTDIR}"/proj/flag_tarball_sent
rm -f ${flag_tarball_path}
