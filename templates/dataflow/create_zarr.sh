#!/bin/bash

# HEADER

# TODO: Adding fake variables to be able to use horizontal wrappers.
# Solved after: https://github.com/BSC-ES/autosubmit/issues/1474

VAR_1=${1:-%VAR_1%}
VAR_2=${2:-%VAR_2%}
HPCROOTDIR=${3:-%HPCROOTDIR%}
CONTAINER_DIR=${4:-%CURRENT_DATAFLOW_CONTAINER%}
CHUNK_START_DATE=${5:-%CHUNK_START_DATE%}
CHUNK_END_DATE=${6:-%CHUNK_END_DATE%}
REPOSITORY_DIR=${7:-%CONFIGURATION.DATAFLOW.REPOSITORY_DIR%}
target_grid=${8:-%CONFIGURATION.DATAFLOW.TARGET_GRID%}
target_res=${9:-%CONFIGURATION.DATAFLOW.TARGET_RES%}
output_folder=${10:-%CONFIGURATION.DATAFLOW.OUTPUT_DIR%}
CURRENT_ARCH=${11:-%CURRENT_ARCH%}
LIBDIR=${12:-%CONFIGURATION.LIBDIR%}
SCRATCH_DIR=${13:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${14:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${15:-%CURRENT_LOCAL_DIR%}
SPLIT_SIZE=${16:-%EXPERIMENT.SPLITSIZE%}
CHUNKSIZE=${17:-%EXPERIMENT.CHUNKSIZE%}
CHUNKSIZEUNIT=${18:-%EXPERIMENT.CHUNKSIZEUNIT%}
# END_HEADER

dataset_config=${REPOSITORY_DIR}/conf/models/climatedt_emulator/dataset_config.yaml
# TODO Parametrize
zarr_chunks="time:1,level:1,latitude:-1,longitude:-1"
# TODO improve frequency
# Frequency needs to be the chunksize and the unit (first letter lowercase)
frequency="1d" # Related to inner frequency of final pipeline
param_name_map=${REPOSITORY_DIR}/configs/param_to_longname.yaml

# convert SDATE (YYYYMMDD) to YYYY-MM-DD format
start_date_formatted=$(echo "${CHUNK_START_DATE}" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')
# convert CHUNK_END_DATE (YYYYMMDD) to YYYY-MM-DD format
CHUNK_END_DATE_MINUS1=$(date -d "${CHUNK_END_DATE} -1 day" +%%Y%%m%%d)
end_date_formatted=$(echo "${CHUNK_END_DATE_MINUS1}" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')

HPC=$(echo ${CURRENT_ARCH})
. "${LIBDIR}/${HPC}"/config.sh

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

zarr_path="${output_folder}/data-${start_date_formatted}T00:00-${end_date_formatted}T23:00.zarr"

echo "Creating Zarr: $zarr_path"

singularity exec --cleanenv \
    --bind ${REPOSITORY_DIR}:/workspace \
    --pwd ${REPOSITORY_DIR} \
    "$CONTAINER_DIR" \
    bash -c "cd ${REPOSITORY_DIR} &&
    export PYTHONPATH=/workspace/src:${PYTHONPATH:-}
    uv run --project /dataflow_runner/ python3 -m zarr_template_creation_pkg \
    --output-zarr-path $zarr_path \
    --dataset-config $dataset_config \
    --zarr-chunks $zarr_chunks \
    --start-date ${start_date_formatted}T00:00 \
    --end-date ${end_date_formatted}T23:00 \
    --frequency $frequency \
    --param-to-longname $param_name_map \
    --target-grid $target_grid \
    --target-res $target_res"
