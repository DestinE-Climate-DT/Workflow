#!/bin/bash

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
REPOSITORY_DIR=${2:-%CONFIGURATION.DATAFLOW.REPOSITORY_DIR%}
OUTPUT_FOLDER=${3:-%CONFIGURATION.DATAFLOW.OUTPUT_DIR%}
ANEMOI_CONTAINER_DIR=${4:-%CURRENT_ANEMOI_CONTAINER%}
CURRENT_ARCH=${5:-%CURRENT_ARCH%}
LIBDIR=${6:-%CONFIGURATION.LIBDIR%}
SCRATCH_DIR=${7:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${8:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${9:-%CURRENT_LOCAL_DIR%}

# END_HEADER

anemoi_dataset_path="${OUTPUT_FOLDER}/anemoi_dataset.zarr"

HPC=$(echo ${CURRENT_ARCH})
. "${LIBDIR}/${HPC}"/config.sh

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

echo "Initializing Anemoi dataset..."
singularity exec --cleanenv \
    --bind ${REPOSITORY_DIR} \
    "${ANEMOI_CONTAINER_DIR}" \
    anemoi-datasets cleanup $anemoi_dataset_path
