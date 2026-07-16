#!/bin/bash

# HEADER

output_folder=${1:-%CONFIGURATION.DATAFLOW.OUTPUT_DIR%}
CONTAINER_PATH=${2:-%CURRENT_ANEMOI_CONTAINER%}

CURRENT_CHUNK=${3:-%CHUNK%}
NUMCHUNKS=${4:-%EXPERIMENT.NUMCHUNKS%}

CURRENT_ARCH=${5:-%CURRENT_ARCH%}
LIBDIR=${6:-%CONFIGURATION.LIBDIR%}
SCRATCH_DIR=${7:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${8:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${9:-%CURRENT_LOCAL_DIR%}

# END_HEADER

HPC=$(echo ${CURRENT_ARCH})
. "${LIBDIR}/${HPC}"/config.sh

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") [INFO] $*"
}

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
