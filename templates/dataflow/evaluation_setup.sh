#!/bin/bash

# HEADER
# Container Images
AQUA_CONTAINER=${1:-%CURRENT_AQUA_CONTAINER%}
# Experiment, System and Project Paths
EXPERIMENT_DIR=${2:-%HPCROOTDIR%}
HPCARCH_short=${3:-%CURRENT_HPCARCH_SHORT%}
PREDICTIA_REPO=${4:-%CURRENT_AQUA_PREDICTIA_REPO%}
HPC_PROJECT_DIR=${5:-%CONFIGURATION.HPC_PROJECT_DIR%}
# AQUA Setup & Paths
AQUA=${6:-%CURRENT_AQUA%}
AQUA_DIAGNOSTICS=${7:-%CURRENT_AQUA_DIAGNOSTICS%}
AQUA_CATALOG_DIR=${8:-%CURRENT_AQUA_CATALOG%}
# Output Folders
AQUA_CONFIG_DIR=${9:-%CONFIGURATION.MODEL_SERVING_FLOW.AQUA_CONFIG_DIR%}
# Data Catalogs - Predictions Data
ADD_CATALOG_NAME=${10:-%CONFIGURATION.MODEL_SERVING_FLOW.EVALUATION.ADD_CATALOG_NAME%}
# END_HEADER

mkdir -p "$AQUA_CONFIG_DIR"
# remove previous aqua installation if exist
rm -rf $AQUA_CONFIG_DIR/*

module load singularity

singularity exec --nv \
    --env AQUA_CONFIG=${AQUA_CONFIG_DIR} \
    --bind ${HPC_PROJECT_DIR}:${HPC_PROJECT_DIR} \
    ${AQUA_CONTAINER} bash -c \
    "
    set -xuve
    yes | aqua install mn5 --path ${AQUA_CONFIG_DIR}
    # aqua add ${ADD_CATALOG_NAME} --editable ${AQUA_CATALOG_DIR} # we do not use add because we don't want a symlink
    "

# equivalent to aqua add ${ADD_CATALOG_NAME} --editable ${AQUA_CATALOG_DIR} but without symbolic link and without the subfolder
CATALOG_TARGET_PATH=${AQUA_CONFIG_DIR}/catalogs
mkdir -p ${CATALOG_TARGET_PATH}
cp -r ${AQUA_CATALOG_DIR}/* ${CATALOG_TARGET_PATH}

# copy fixes files from predictia repo to aqua config fixes folder
cp ${PREDICTIA_REPO}/aqua/fixes/*.yaml ${AQUA_CONFIG_DIR}/fixes

echo "Added catalog from ${AQUA_CATALOG_DIR} to AQUA configuration at ${AQUA_CONFIG_DIR}"
echo "AQUA evaluation setup completed."
