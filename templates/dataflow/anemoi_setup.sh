#!/bin/bash

set -xuve

HPCROOTDIR=${1:-%HPCROOTDIR%}
FDB_HOME=${2:-%REQUEST.FDB_HOME%}
REPOSITORY_DIR=${3:-%CONFIGURATION.DATAFLOW.REPOSITORY_DIR%}
ANEMOI_CONTAINER_DIR=${4:-%CURRENT_ANEMOI_CONTAINER%}

start_date=${5:-%SDATE%}
#Not sure if this is going to work
end_date=${6:-%EXPERIMENT.LAST_DATE%}
CHUNKSIZEUNIT=${7:-%EXPERIMENT.CHUNKSIZEUNIT%}
CHUNKSIZE=${8:-%EXPERIMENT.CHUNKSIZE%}
target_res=${9:-%CONFIGURATION.DATAFLOW.TARGET_RES%}
output_folder=${10:-%CONFIGURATION.DATAFLOW.OUTPUT_DIR%}
#times_per_batch=${11:-%EXPERIMENT.NUMCHUNKS%}

# !! PARAMETRIZE !!
dataflow_container="/gpfs/projects/ehpc01/containers/de393/container_earthkitdata_0_13_6.sif"

# Frequency needs to be the chunksize and the unit (first letter lowercase)
#frequency="${CHUNKSIZE}${CHUNKSIZEUNIT:0:1,,}"
frequency="1d"

dataset_config=${REPOSITORY_DIR}/conf/models/climatedt_emulator/dataset_config.yaml
param_name_map=${REPOSITORY_DIR}/configs/param_to_longname.yaml
zarr_chunks="time:1,level:1,latitude:-1,longitude:-1"
fields_per_request="1"
times_per_batch="1"
# convert SDATE (YYYYMMDD) to YYYY-MM-DD format
start_date_formatted=$(echo "${start_date}" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')
# convert CHUNK_END_DATE (YYYYMMDD) to YYYY-MM-DD format
end_date_formatted=$(echo "${end_date}" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')

mkdir -p "${output_folder}"

module load singularity
export FDB_HOME="${FDB_HOME}"

# Basic checks; FDB_HOME must exist
if [ ! -d "${FDB_HOME}" ]; then
    echo "FDB_HOME directory does not exist: ${FDB_HOME}"
    exit 1
fi

# The data pipelines repository has to be cloned (can't be empty)
if [ ! -d "${REPOSITORY_DIR}" ]; then
    echo "Data pipelines repository not found at ${REPOSITORY_DIR}"
    exit 1
fi

cd ${REPOSITORY_DIR}

source "${REPOSITORY_DIR}"/setup.sh \
    -s $start_date_formatted \
    -e $end_date_formatted \
    -n $times_per_batch \
    -f $frequency \
    -o $output_folder \
    -c $dataset_config \
    -p $param_name_map \
    -z $zarr_chunks \
    -g $target_res \
    --dataflow-container $dataflow_container \
    --anemoi-container $ANEMOI_CONTAINER_DIR
