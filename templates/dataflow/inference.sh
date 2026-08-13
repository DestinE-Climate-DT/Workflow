#!/bin/bash

# HEADER
# Container Images
ANEMOI_CONTAINER_DIR=${1:-%CURRENT_ANEMOI_CONTAINER%}
# Repository, Project and Experiment paths
REPOSITORY_DIR=${2:-%CONFIGURATION.MODEL_SERVING_FLOW.REPOSITORY_DIR%}
PROJECT_DIR=${3:-%CONFIGURATION.PROJECT_ROOTDIR%}
HPC_PROJECT_DIR=${4:-%CONFIGURATION.HPC_PROJECT_DIR%}
UTILS_LIB_DIR=${5:-%CONFIGURATION.MODEL_SERVING_FLOW.UTILS_LIB_DIR%}
EXPERIMENT_DIR=${6:-%HPCROOTDIR%}
# Checkpoint Information
checkpoint=${7:-%CONFIGURATION.MODEL_SERVING_FLOW.CHECKPOINT.FILE%}
epoch=${8:-%CONFIGURATION.MODEL_SERVING_FLOW.CHECKPOINT.EPOCH%}
step=${9:-%CONFIGURATION.MODEL_SERVING_FLOW.CHECKPOINT.STEP%}
# Inference Execution Parameters
START_DATE=${10:-%CHUNK_START_DATE%}
CHUNKSIZE=${11:-%EXPERIMENT.CHUNKSIZE%}
CHUNKSIZEUNIT=${12:-%EXPERIMENT.CHUNKSIZEUNIT%}
CHUNK=${13:-%CHUNK%}
# Data Configuration
input_dataset=${14:-%CONFIGURATION.MODEL_SERVING_FLOW.INPUT_DATASET%}
# Output Folders
RUNS_DIR=${15:-%CONFIGURATION.MODEL_SERVING_FLOW.RUNS_DIR%}
INFERENCE_DIR=${16:-%CONFIGURATION.MODEL_SERVING_FLOW.INFERENCE_OUTPUT_DIR%}
ACTIVE_RUN_DIR=${17:-%CONFIGURATION.MODEL_SERVING_FLOW.ACTIVE_RUN_DIR_SYMLINK%}
# END_HEADER

# Used accross multiple stages, defined per start date
RUN_ID="$(date +%Y%m%d_%H%M%S)"

# Create the rundir for the current start date
mkdir -p ${RUNS_DIR}
CURRENT_RUN_DIR=${RUNS_DIR}/${RUN_ID}
mkdir -p ${CURRENT_RUN_DIR}

# Create the active symlink to the current rundir, so that later stages can easily find the current run outputs without needing to know the run id
ln -sfn ${CURRENT_RUN_DIR} ${ACTIVE_RUN_DIR}

module load singularity
source $UTILS_LIB_DIR/utils_inference.sh # format_start_date, compute_lead_time_hours, build_name_inference_output
# check chunk id and exit if greater than 1, since we want to run inference only for one chunk at a time
checker_msf "$CHUNK"
mkdir -p "$INFERENCE_DIR"

# ANEMOI INFERENCE using GPU
device=cuda

# compute lead time in hours
lead_time_hours=$(compute_lead_time_hours "$START_DATE" "$CHUNKSIZE" "$CHUNKSIZEUNIT")

# convert SDATE (YYYYMMDD) to YYYY-MM-DDTHH:mm:ss format
start_date_formatted=$(format_start_date "$START_DATE")

# output netcdf path
output_netcdf=$INFERENCE_DIR/$(build_name_inference_output "$RUN_ID" "$epoch" "$step" "$start_date_formatted" "$lead_time_hours")

echo "Running inference with the following parameters:"
echo "Start date: $start_date_formatted"
echo "Lead time: $lead_time_hours hours"
echo "Checkpoint: $checkpoint"
echo "Input dataset: $input_dataset"
echo "Output NetCDF: $output_netcdf"

singularity exec --nv \
    --env CC=gcc \
    --env CXX=g++ \
    --bind ${HPC_PROJECT_DIR}:${HPC_PROJECT_DIR} \
    ${ANEMOI_CONTAINER_DIR} anemoi-inference run \
    device=${device} \
    checkpoint=${checkpoint} \
    lead_time=${lead_time_hours} \
    date=${start_date_formatted} \
    input.dataset=${input_dataset} \
    output.netcdf=${output_netcdf}

echo "Inference completed. Output saved to ${output_netcdf}"
