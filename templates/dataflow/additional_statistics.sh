#!/bin/bash

HPCROOTDIR=${1:-%HPCROOTDIR%}
REPOSITORY_DIR=${2:-%CONFIGURATION.DATAFLOW.REPOSITORY_DIR%}
OUTPUT_FOLDER=${3:-%CONFIGURATION.DATAFLOW.OUTPUT_DIR%}
ANEMOI_CONTAINER_DIR=${4:-%CURRENT_ANEMOI_CONTAINER%}
anemoi_dataset_path="${OUTPUT_FOLDER}/anemoi_dataset.zarr"

module load singularity

echo "Initializing Anemoi dataset..."
singularity exec --cleanenv \
    --bind ${REPOSITORY_DIR} \
    "${ANEMOI_CONTAINER_DIR}" \
    bash -c "anemoi-datasets init-additions $anemoi_dataset_path --delta 1d && \
    anemoi-datasets load-additions $anemoi_dataset_path --delta 1d --part 1/1 && \
    anemoi-datasets finalise-additions $anemoi_dataset_path --delta 1d"
