#!/bin/bash

# HEADER

# TODO: Adding fake variables to be able to use horizontal wrappers.
# Solved after: https://github.com/BSC-ES/autosubmit/issues/1474

VAR_1=${1:-%VAR_1%}
VAR_2=${2:-%VAR_2%}

HPCROOTDIR=${3:-%HPCROOTDIR%}
FDB_HOME=${4:-%REQUEST.FDB_HOME%}
CONTAINER_DIR=${5:-%CURRENT_DATAFLOW_CONTAINER%}
REPOSITORY_DIR=${6:-%CONFIGURATION.DATAFLOW.REPOSITORY_DIR%}

start_date=${7:-%SPLIT_START_DATE%}
end_date=${8:-%SPLIT_SECOND_TO_LAST_DATE%}
chunk_start_date=${9:-%CHUNK_START_DATE%}
chunk_end_date=${10:-%CHUNK_SECOND_TO_LAST_DATE%}
target_res=${11:-%CONFIGURATION.DATAFLOW.TARGET_RES%}
output_folder=${12:-%CONFIGURATION.DATAFLOW.OUTPUT_DIR%}
requests_dir=${13:-%CONFIGURATION.DATAFLOW.REQUESTS_DIR%}
HPC_EARTHKIT_REGRID_CACHE_DIR=${14:-%CURRENT_HPC_EARTHKIT_REGRID_CACHE_DIR%}
JOBNAME=${15:-%JOBNAME%}

CURRENT_ARCH=${16:-%CURRENT_ARCH%}
LIBDIR=${17:-%CONFIGURATION.LIBDIR%}
SCRATCH_DIR=${18:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${19:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${20:-%CURRENT_LOCAL_DIR%}
target_grid=${21:-%CONFIGURATION.DATAFLOW.TARGET_GRID%}

# END_HEADER

HPC=$(echo ${CURRENT_ARCH})
. "${LIBDIR}/${HPC}"/config.sh

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

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
    --target_grid ${target_grid} \
    --target_res ${target_res} \
    --frequency 1d
