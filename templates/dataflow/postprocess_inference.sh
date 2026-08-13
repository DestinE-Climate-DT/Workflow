#!/bin/bash

# HEADER
# Container Images
ANEMOI_CONTAINER_DIR=${1:-%CURRENT_ANEMOI_CONTAINER%}
# Repository, Project and Experiment paths
MSF_REPOSITORY_DIR=${2:-%CONFIGURATION.MODEL_SERVING_FLOW.REPOSITORY_DIR%}
PROJECT_DIR=${3:-%CONFIGURATION.PROJECT_ROOTDIR%}
HPC_PROJECT_DIR=${4:-%CONFIGURATION.HPC_PROJECT_DIR%}
UTILS_LIB_DIR=${5:-%CONFIGURATION.MODEL_SERVING_FLOW.UTILS_LIB_DIR%}
EXPERIMENT_DIR=${6:-%HPCROOTDIR%}
# Checkpoint Information
epoch=${7:-%CONFIGURATION.MODEL_SERVING_FLOW.CHECKPOINT.EPOCH%}
step=${8:-%CONFIGURATION.MODEL_SERVING_FLOW.CHECKPOINT.STEP%}
# Inference Execution Parameters
START_DATE=${9:-%CHUNK_START_DATE%}
CHUNKSIZE=${10:-%EXPERIMENT.CHUNKSIZE%}
CHUNKSIZEUNIT=${11:-%EXPERIMENT.CHUNKSIZEUNIT%}
# Data Configuration
grid_nx=${12:-%CONFIGURATION.MODEL_SERVING_FLOW.GRID_SIZE_LONGITUDE%}
grid_ny=${13:-%CONFIGURATION.MODEL_SERVING_FLOW.GRID_SIZE_LATITUDE%}
target_patterns=${14:-%CONFIGURATION.MODEL_SERVING_FLOW.TARGET_PATTERNS%}
levels=${15:-%CONFIGURATION.MODEL_SERVING_FLOW.PRESSURE_LEVELS%}
# Output Folders
INFERENCE_DIR=${16:-%CONFIGURATION.MODEL_SERVING_FLOW.INFERENCE_OUTPUT_DIR%}
INFERENCE_PROCESSED_DIR=${17:-%CONFIGURATION.MODEL_SERVING_FLOW.INFERENCE_OUTPUT_PROCESSED_DIR%}
ACTIVE_RUN_DIR=${18:-%CONFIGURATION.MODEL_SERVING_FLOW.ACTIVE_RUN_DIR_SYMLINK%}
# END_HEADER

module load singularity
source $UTILS_LIB_DIR/utils_inference.sh # format_start_date, compute_lead_time_hours, build_name_inference_output, run_id_from_symlink

# Get run ID from active folder created in inference stage
RUN_ID=$(run_id_from_symlink "${ACTIVE_RUN_DIR}")

mkdir -p "$INFERENCE_PROCESSED_DIR"

####
# PYTHON SCRIPT ARGUMENTS
####

# compute lead time in hours
lead_time_hours=$(compute_lead_time_hours "$START_DATE" "$CHUNKSIZE" "$CHUNKSIZEUNIT")

python_script="$MSF_REPOSITORY_DIR/scripts/postprocess_inference.py"
start_date_formatted=$(format_start_date "$START_DATE")
inference_netcdf=$INFERENCE_DIR/$(build_name_inference_output "$RUN_ID" "$epoch" "$step" "$start_date_formatted" "$lead_time_hours")

singularity exec --nv \
    --bind ${HPC_PROJECT_DIR}:${HPC_PROJECT_DIR} \
    ${ANEMOI_CONTAINER_DIR} python ${python_script} \
    --input-file ${inference_netcdf} \
    --output-dir ${INFERENCE_PROCESSED_DIR} \
    --nx ${grid_nx} \
    --ny ${grid_ny} \
    --target-patterns ${target_patterns} \
    --levels ${levels}

echo "Post-processing of inference output completed for ${inference_netcdf}. Saved to the folder ${INFERENCE_PROCESSED_DIR}"
