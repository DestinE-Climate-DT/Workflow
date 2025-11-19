#!/bin/bash

output_folder=${1:-%CONFIGURATION.DATAFLOW.OUTPUT_DIR%}
CONTAINER_PATH=${2:-%CURRENT_ANEMOI_CONTAINER%}

CURRENT_CHUNK=${3:-%CHUNK%}
NUMCHUNKS=${4:-%EXPERIMENT.NUMCHUNKS%}

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] $*"
}

module load singularity || error_exit "Failed to load Singularity module"

PWD_DIR="$(pwd)"

log "CHUNK: $CURRENT_CHUNK"
log "Total chunks: $NUMCHUNKS"
log "Dataset path: $output_folder"
log "Container: $CONTAINER_PATH"

# Construct command
CMD=(anemoi-datasets load "$output_folder/anemoi_dataset.zarr" --part "$CURRENT_CHUNK/$NUMCHUNKS")

log "Running anemoi-datasets inside container..."

singularity exec --cleanenv \
    --bind "$PWD_DIR":"$PWD_DIR" \
    "$CONTAINER_PATH" \
    "${CMD[@]}"

log "Dataset load complete."
