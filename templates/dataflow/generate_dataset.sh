#!/bin/bash

HPCROOTDIR=%HPCROOTDIR%
FDB_HOME=%REQUEST.FDB_HOME%
CONTAINER_DIR=${3:-%CONFIGURATION.DATAFLOW.CONTAINER_DIR%}
REPOSITORY_DIR=${4:-%CONFIGURATION.DATAFLOW.REPOSITORY_DIR%}

start_date=${5:-%SPLIT_START_DATE%}
end_date=${6:-%SPLIT_SECOND_TO_LAST_DATE%}
chunk_start_date=${7:-%CHUNK_START_DATE%}
chunk_end_date=${8:-%CHUNK_SECOND_TO_LAST_DATE%}
target_res=${9:-%CONFIGURATION.DATAFLOW.TARGET_RES%}
output_folder=${10:-%CONFIGURATION.DATAFLOW.OUTPUT_DIR%}
requests_dir=${11:-%CONFIGURATION.DATAFLOW.REQUESTS_DIR%}
HPC_EARTHKIT_REGRID_CACHE_DIR=${12:-%CURRENT_HPC_EARTHKIT_REGRID_CACHE_DIR%}

JOBNAME=${13:-%JOBNAME%}

module load singularity
export FDB_HOME=${FDB_HOME}

mkdir -p "$TMPDIR/.cache/${JOBNAME}"

cp -r "${HPC_EARTHKIT_REGRID_CACHE_DIR}" "$TMPDIR/.cache/${JOBNAME}"

export EARTHKIT_REGRID_CACHE_DIR="$TMPDIR/.cache/${JOBNAME}"

# convert SDATE (YYYYMMDD) to YYYY-MM-DD format
start_date_formatted=$(echo "${start_date}" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')
chunk_start_date_formatted=$(echo "${chunk_start_date}" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')
# convert CHUNK_END_DATE (YYYYMMDD) to YYYY-MM-DD format
end_date_formatted=$(echo "${end_date}" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')
chunk_end_date_formatted=$(echo "${chunk_end_date}" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')

# Run pipeline for some requests of the first batch
singularity exec \
    ${CONTAINER_DIR} \
    python3 ${REPOSITORY_DIR}/src/pipeline.py \
    --request ${requests_dir}/${start_date_formatted}/*_${end_date_formatted}*.yaml \
    --zarr_template ${output_folder}/data-${chunk_start_date_formatted}T00:00-${chunk_end_date_formatted}T23:00.zarr \
    --target_grid regular_ll \
    --target_res ${target_res} \
    --frequency 1d
