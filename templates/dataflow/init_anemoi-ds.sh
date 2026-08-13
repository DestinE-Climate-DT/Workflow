#!/bin/bash

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
REPOSITORY_DIR=${2:-%CONFIGURATION.DATAFLOW.REPOSITORY_DIR%}
OUTPUT_FOLDER=${3:-%CONFIGURATION.DATAFLOW.OUTPUT_DIR%}
DATAFLOW_CONTAINER_DIR=${4:-%CURRENT_DATAFLOW_CONTAINER%}

CURRENT_ARCH=${5:-%CURRENT_ARCH%}
LIBDIR=${6:-%CONFIGURATION.LIBDIR%}
SCRATCH_DIR=${7:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${8:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${9:-%CURRENT_LOCAL_DIR%}
# END_HEADER

CONFIG_OUTPUT_PATH=${REPOSITORY_DIR}/configs/generated_anemoi_config.yaml
anemoi_dataset_path="${OUTPUT_FOLDER}/anemoi_dataset.zarr"

HPC=$(echo ${CURRENT_ARCH})
. "${LIBDIR}/${HPC}"/config.sh

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

echo "Initializing Anemoi dataset..."
singularity exec --cleanenv \
    --bind ${REPOSITORY_DIR} \
    --pwd ${REPOSITORY_DIR} \
    "${DATAFLOW_CONTAINER_DIR}" \
    uv run --project /dataflow_runner/ \
    bash bin/initialize_anemoi-dataset.sh \
    --overwrite \
    --config-path $CONFIG_OUTPUT_PATH \
    --dataset-path $anemoi_dataset_path
