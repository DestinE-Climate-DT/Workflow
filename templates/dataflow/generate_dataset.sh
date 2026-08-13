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
chunk_start_date=${8:-%CHUNK_START_DATE%}
chunk_end_date=${9:-%CHUNK_SECOND_TO_LAST_DATE%}
target_res=${10:-%CONFIGURATION.DATAFLOW.TARGET_RES%}
output_folder=${11:-%CONFIGURATION.DATAFLOW.OUTPUT_DIR%}
requests_dir=${12:-%CONFIGURATION.DATAFLOW.REQUESTS_DIR%}
HPC_EARTHKIT_REGRID_CACHE_DIR=${13:-%CURRENT_HPC_EARTHKIT_REGRID_CACHE_DIR%}
JOBNAME=${14:-%JOBNAME%}

CURRENT_ARCH=${15:-%CURRENT_ARCH%}
LIBDIR=${16:-%CONFIGURATION.LIBDIR%}
SCRATCH_DIR=${17:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${18:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${19:-%CURRENT_LOCAL_DIR%}
target_grid=${20:-%CONFIGURATION.DATAFLOW.TARGET_GRID%}
SPLIT_SIZE=${21:-%EXPERIMENT.SPLITSIZE%}
splits=${22:-%SPLITS%}
split=${23:-%SPLIT%}
split_second_to_last_date=${24:-%SPLIT_SECOND_TO_LAST_DATE%}
# END_HEADER
# THE FOLLOWING LINES ARE DUE TO AN Autosubmit bug: https://github.com/BSC-ES/autosubmit/issues/2866

if [[ "$split" == "$splits" ]]; then
    # Last split in chunk → end at the chunk boundary
    end_date=$chunk_end_date
else
    # Regular split → end at SECOND_TO_LAST_DATE
    end_date=$split_second_to_last_date
fi

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

## frequency should be the difference between start date and end date
#frequency_days=$((($(date -d "${end_date_formatted}" +%s) - $(date -d "${start_date_formatted}" +%s)) / 86400 + 1))
frequency_days=${SPLIT_SIZE}

request_path="${requests_dir}/${start_date_formatted}_to_${end_date_formatted}/*_${end_date_formatted}.yaml"

echo "Using request path: ${request_path}"

# Run pipeline for some requests of the first batch
singularity exec \
    --env FDB_HOME=${FDB_HOME} \
    --env EARTHKIT_REGRID_CACHE_DIR="$TMPDIR/.cache/${JOBNAME}" \
    --bind ${REPOSITORY_DIR}:/workspace \
    --pwd ${REPOSITORY_DIR} \
    ${CONTAINER_DIR} \
    bash -c "cd ${REPOSITORY_DIR} &&
    export PYTHONPATH=/workspace/src:${PYTHONPATH:-}
    uv run --project /dataflow_runner/ \
    python3 -m generate_dataset_pkg \
    --request ${request_path} \
    --zarr-template ${output_folder}/data-${chunk_start_date_formatted}T00:00-${chunk_end_date_formatted}T23:00.zarr \
    --target-grid ${target_grid} \
    --target-res ${target_res} \
    --frequency ${frequency_days}d"
