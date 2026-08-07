#!/bin/bash

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
CONTAINER_DIR=${2:-%CURRENT_DATAFLOW_CONTAINER%}
START_DATE=${3:-%SDATE%}
END_DATE=${4:-%EXPERIMENT.LAST_DATE%}
REPOSITORY_DIR=${5:-%CONFIGURATION.DATAFLOW.REPOSITORY_DIR%}
output_folder=${6:-%CONFIGURATION.DATAFLOW.OUTPUT_DIR%}
SPLIT_SIZE=${7:-%EXPERIMENT.SPLITSIZE%}
CURRENT_ARCH=${8:-%CURRENT_ARCH%}
LIBDIR=${9:-%CONFIGURATION.LIBDIR%}
SCRATCH_DIR=${10:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${11:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${12:-%CURRENT_LOCAL_DIR%}

# END_HEADER

HPC=$(echo ${CURRENT_ARCH})
. "${LIBDIR}/${HPC}"/config.sh

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

# TODO convert AS monthly chunking to 1M, same for other options
CHUNK_SIZE="1M"
# TODO improve frequency
# Frequency needs to be the chunksize and the unit (first letter lowercase)
#frequency="${CHUNKSIZE}${CHUNKSIZEUNIT:0:1,,}"
frequency="1d"
# TODO get this from as
# Relative to REPOSITORY DIR
CONFIG_OUTPUT_PATH=${REPOSITORY_DIR}/configs/generated_anemoi_config.yaml

# convert SDATE (YYYYMMDD) to YYYY-MM-DD format
start_date_formatted=$(echo "${START_DATE}" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')
# convert EDATE (YYYYMMDD) to YYYY-MM-DD format
end_date_formatted=$(echo "${END_DATE}" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')

echo "Creating anemoi-datasets config..."
singularity exec --cleanenv \
    --bind ${REPOSITORY_DIR} \
    "$CONTAINER_DIR" \
    bash -c "cd ${REPOSITORY_DIR} && python3 ${REPOSITORY_DIR}/runscripts/create_anemoi-datasets_config.py \
        --start_date ${start_date_formatted}T00:00 \
        --end_date ${end_date_formatted}T23:00 \
        --frequency $frequency \
        --group_size ${SPLIT_SIZE}d \
        --store_size ${CHUNK_SIZE} \
        --base_path $output_folder \
        --output $CONFIG_OUTPUT_PATH"
