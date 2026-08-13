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
SCRATCH_DIR=${10:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${11:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${12:-%CURRENT_LOCAL_DIR%}

#TODO: Ask, Marvin, Aina and, Marc if this is okay
CURRENT_CHUNK=${13:-%CHUNK%}
NUMCHUNKS=${14:-%EXPERIMENT.NUMCHUNKS%}

# END_HEADER

anemoi_dataset_path="${OUTPUT_FOLDER}/anemoi_dataset.zarr"

HPC=$(echo ${CURRENT_ARCH})
. "${LIBDIR}/${HPC}"/config.sh

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

echo "Initializing Anemoi dataset..."
singularity exec --cleanenv \
    --pwd ${REPOSITORY_DIR} \
    --bind ${REPOSITORY_DIR} \
    "${DATAFLOW_CONTAINER_DIR}" \
    uv run --project /dataflow_runner/ \
    anemoi-datasets load-additions $anemoi_dataset_path --delta 1d --parts "$CURRENT_CHUNK/$NUMCHUNKS"
