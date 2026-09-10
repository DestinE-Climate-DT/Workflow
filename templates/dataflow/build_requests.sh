#!/bin/bash

# HEADER

# TODO: Adding fake variables to be able to use horizontal wrappers.
# Solved after: https://github.com/BSC-ES/autosubmit/issues/1474

VAR_1=${1:-%VAR_1%}
VAR_2=${2:-%VAR_2%}
HPCROOTDIR=${3:-%HPCROOTDIR%}
FDB_HOME=${4:-%REQUEST.FDB_HOME%}
CONTAINER_DIR=${5:-%CURRENT_DATAFLOW_CONTAINER%}
CHUNK_START_DATE=${6:-%CHUNK_START_DATE%}
CHUNK_END_DATE=${7:-%CHUNK_END_DATE%}
REQUESTS_DIR=${8:-%CONFIGURATION.DATAFLOW.REQUESTS_DIR%}
REPOSITORY_DIR=${9:-%CONFIGURATION.DATAFLOW.REPOSITORY_DIR%}
target_res=${10:-%CONFIGURATION.DATAFLOW.TARGET_RES%}
output_folder=${11:-%CONFIGURATION.DATAFLOW.OUTPUT_DIR%}

CURRENT_ARCH=${12:-%CURRENT_ARCH%}
LIBDIR=${13:-%CONFIGURATION.LIBDIR%}
SCRATCH_DIR=${14:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${15:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${16:-%CURRENT_LOCAL_DIR%}
EXPID=${17:-%DEFAULT_EXPID%}
JOBNAME=${18:-%JOBNAME%}

# END_HEADER

HPC=$(echo ${CURRENT_ARCH})
. "${LIBDIR}/${HPC}"/config.sh

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

# !! PARAMETRIZE !!
request_format="FDB"

export FDB_HOME=${FDB_HOME}

mkdir -p "${REQUESTS_DIR}"

JOBNAME_WITHOUT_EXPID=$(echo ${JOBNAME} | sed 's/^[^_]*_//')
GENERAL_REQUEST_PATH=${HPCROOTDIR}/LOG_${EXPID}/general_request_workflow_${JOBNAME_WITHOUT_EXPID}

# Create requests for first batch
singularity exec "${CONTAINER_DIR}" \
    bash -c "cd ${REPOSITORY_DIR} && python3 ${REPOSITORY_DIR}/runscripts/build_requests.py \
    --model ${REPOSITORY_DIR}/conf/models/climatedt_emulator/dataset_config.yaml \
    --general ${GENERAL_REQUEST_PATH} \
    --start_date ${CHUNK_START_DATE} \
    --end_date ${CHUNK_END_DATE} \
    --output ${REQUESTS_DIR} \
    --zarr_chunks field:-1,time:1,level:-1,latitude:-1,longitude:-1 \
    --request_format $request_format \
    --target_res $target_res
"
