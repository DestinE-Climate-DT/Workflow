#!/bin/bash

HPCROOTDIR=%HPCROOTDIR%
FDB_HOME=%REQUEST.FDB_HOME%
CONTAINER_DIR=${3:-%CONFIGURATION.DATAFLOW.CONTAINER_DIR%}
CHUNK_START_DATE=${4:-%CHUNK_START_DATE%}
CHUNK_END_DATE=${5:-%CHUNK_END_DATE%}
REQUESTS_DIR=${3:-%CONFIGURATION.DATAFLOW.REQUESTS_DIR%}
REPOSITORY_DIR=${6:-%CONFIGURATION.DATAFLOW.REPOSITORY_DIR%}
target_res=${7:-%CONFIGURATION.DATAFLOW.TARGET_RES%}
output_folder=${8:-%CONFIGURATION.DATAFLOW.OUTPUT_DIR%}

# !! PARAMETRIZE !!
request_format="FDB"

module load singularity
export FDB_HOME=${FDB_HOME}

mkdir -p "${REQUESTS_DIR}"

# Create requests for first batch
singularity exec "${CONTAINER_DIR}" \
    bash -c "cd ${REPOSITORY_DIR} && python3 "${REPOSITORY_DIR}"/runscripts/build_requests.py \
    --model "${REPOSITORY_DIR}"/conf/models/climatedt_emulator/dataset_config.yaml \
    --general "${REPOSITORY_DIR}"/conf/general_request.yaml \
    --start_date "${CHUNK_START_DATE}" \
    --end_date "${CHUNK_END_DATE}" \
    --output "${REQUESTS_DIR}" \
    --zarr_chunks field:-1,time:1,level:-1,latitude:-1,longitude:-1" \
    --request_format $request_format \
    --target_grid $target_res
