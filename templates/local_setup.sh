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
RUN_LRA_GENERATOR=${19:-%CONFIGURATION.ADDITIONAL_JOBS.LRA%}
PREV_AQUA_EXP=${20:-%AQUA.PREV_EXP%}
DATA_PORTFOLIO=${21:-%CONFIGURATION.DATA_PORTFOLIO%}
CATALOG_REF=${22:-%AQUA.CATALOG_REF%}

# checker_ifs-nemo variables
NODES=${23:-%HPCNODES%}
TASKS=${24:-%HPCTASKS%}
IFS_IO_PPN=${25:-%HPCIFS_IO_PPN%}
NEMO_IO_PPN=${26:-%HPCNEMO_IO_PPN%}
IFS_IO_NODES=${27:-%HPCIFS_IO_NODES%}
NEMO_IO_NODES=${28:-%HPCNEMO_IO_NODES%}
IFS_IO_TASKS=${29:-%HPCIFS_IO_TASKS%}
NEMO_IO_TASKS=${30:-%HPCNEMO_IO_TASKS%}

# END_HEADER

LIBDIR="${ROOTDIR}"/proj/"${PROJDEST}"/lib

export ROOTDIR
export MODEL_NAME
export PROJDEST
export INSTALL

export MODEL_VERSION
ATM_MODEL=${MODEL_NAME%%-*}

export DATA_PORTFOLIO

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

# Clone ClimateDT-catalog. This was introduced in v6.2.1 as an improved solution,
# in order to overcome the operational dirty-repo issues that arised in cycle e26.1
if [ "${AQUA_ON,,}" == "true" ]; then
    # lib/common/utils/local_setup_utils.sh (clone_catalog) (auto generated comment)
    clone_catalog ${CATALOG_REF}
    # lib/common/checkers.sh (checker_catalog) (auto generated comment)
    checker_catalog
fi

# Run check to see if CONFIGURATION.ADDITIONAL_JOBS.LRA is True
# if not, a previous AQUA exp must be defined
if [ "${AQUA_ON,,}" == "true" ]; then
    # lib/common/checkers.sh (checker_run_lra_generator) (auto generated comment)
    checker_run_lra_generator
fi

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

# Check if CONFIGURATION.DATA_PORTFOLIO is defined and is correct
# lib/common/checkers.sh (checker_data_portfolio) (auto generated comment)
checker_data_portfolio ${DATA_PORTFOLIO}

# Tar project

# lib/common/utils/local_setup_utils.sh (tar_directory) (auto generated comment)
tar_directory "${ROOTDIR}/proj" "${PROJDEST}"
if [ "${AQUA_ON,,}" == "true" ]; then
    # lib/common/utils/local_setup_utils.sh (tar_directory) (auto generated comment)
    tar_directory "${ROOTDIR}/tmp" "catalog"
fi

# Remove the sent tarball flag
flag_tarball_path="${ROOTDIR}"/flag_tarball_sent
rm -f ${flag_tarball_path}
