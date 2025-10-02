#!/bin/bash

HPCROOTDIR=${1:-%HPCROOTDIR%}
REPOSITORY_DIR=${2:-%CONFIGURATION.DATAFLOW.REPOSITORY_DIR%}
OUTPUT_FOLDER=${3:-%CONFIGURATION.DATAFLOW.OUTPUT_DIR%}
ANEMOI_CONTAINER_DIR=${4:-%CURRENT_ANEMOI_CONTAINER%}
CONFIG_OUTPUT_PATH=${REPOSITORY_DIR}/configs/generated_anemoi_config.yaml
anemoi_dataset_path="${OUTPUT_FOLDER}/anemoi_dataset.zarr"
anemoi_container=/gpfs/projects/ehpc165/containers/anemoi-containers/anemoi-250606.sif

module load singularity

echo "Initializing Anemoi dataset..."
singularity exec --cleanenv \
    --bind ${REPOSITORY_DIR} \
    "${ANEMOI_CONTAINER_DIR}" \
    bash -c "cd $REPOSITORY_DIR && \
    bash runscripts/initialize_anemoi-dataset.sh \
        --overwrite \
        --config-path $CONFIG_OUTPUT_PATH \
        --dataset-path $anemoi_dataset_path"
