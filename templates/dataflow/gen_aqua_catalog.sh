#!/bin/bash

# HEADER
# Container Images
ANEMOI_CONTAINER_DIR=${1:-%CURRENT_ANEMOI_CONTAINER%}
# Repository, Project and Experiment paths
REPOSITORY_DIR=${2:-%CONFIGURATION.MODEL_SERVING_FLOW.REPOSITORY_DIR%}
PROJECT_DIR=${3:-%CONFIGURATION.PROJECT_ROOTDIR%}
HPC_PROJECT_DIR=${4:-%CONFIGURATION.HPC_PROJECT_DIR%}
UTILS_LIB_DIR=${5:-%CONFIGURATION.MODEL_SERVING_FLOW.UTILS_LIB_DIR%}
# Experiment & System Configuration
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
FIXER_NAME=${14:-%CONFIGURATION.MODEL_SERVING_FLOW.FIXER_NAME%}
# AQUA Setup & Paths
AQUA=${15:-%CURRENT_AQUA%}
AQUA_DIAGNOSTICS=${16:-%CURRENT_AQUA_DIAGNOSTICS%}
AQUA_CATALOG_DIR=${17:-%CURRENT_AQUA_CATALOG_DIR%}
# Output Folders
AQUA_CONFIG_DIR=${18:-%CONFIGURATION.MODEL_SERVING_FLOW.AQUA_CONFIG_DIR%}
INFERENCE_PROCESSED_DIR=${19:-%CONFIGURATION.MODEL_SERVING_FLOW.INFERENCE_OUTPUT_PROCESSED_DIR%}
ACTIVE_RUN_DIR=${20:-%CONFIGURATION.MODEL_SERVING_FLOW.ACTIVE_RUN_DIR_SYMLINK%}
# Data Catalogs - Reference Data
REFERENCE_DATA_CATALOG=${21:-%CONFIGURATION.MODEL_SERVING_FLOW.EVALUATION.REFERENCE_DATA.CATALOG%}
# Data Catalogs - Predictions Data
ADD_CATALOG_NAME=${22:-%CONFIGURATION.MODEL_SERVING_FLOW.EVALUATION.ADD_CATALOG_NAME%}
PREDICTIONS_DATA_CATALOG=${23:-%CONFIGURATION.MODEL_SERVING_FLOW.EVALUATION.PREDICTIONS_DATA.CATALOG%}
PREDICTIONS_DATA_MODEL=${24:-%CONFIGURATION.MODEL_SERVING_FLOW.EVALUATION.PREDICTIONS_DATA.MODEL%}
PREDICTIONS_DATA_EXP=${25:-%CONFIGURATION.MODEL_SERVING_FLOW.EVALUATION.PREDICTIONS_DATA.EXPERIMENT%}
# END_HEADER

module load singularity
source $UTILS_LIB_DIR/utils_inference.sh # format_start_date, compute_lead_time_hours, build_name_inference_output, run_id_from_symlink

# Get run ID from active folder created in inference stage
RUN_ID=$(run_id_from_symlink "${ACTIVE_RUN_DIR}")

# PYTHON SCRIPT ARGUMENTS
python_script="$REPOSITORY_DIR/scripts/create_catalog_entry.py"
catalog_yaml_path="${AQUA_CONFIG_DIR}/catalogs/${PREDICTIONS_DATA_CATALOG}/${PREDICTIONS_DATA_MODEL}/${PREDICTIONS_DATA_EXP}.yaml"
catalog_base_path="${AQUA_CONFIG_DIR}/catalogs/"

# lead time in hours
lead_time_hours=$(compute_lead_time_hours "$START_DATE" "$CHUNKSIZE" "$CHUNKSIZEUNIT")

# convert SDATE (YYYYMMDD) to YYYY-MM-DDTHH:mm:ss format
start_date_formatted=$(format_start_date "$START_DATE")
source_raw=$(build_name_inference_output "$RUN_ID" "$epoch" "$step" "$start_date_formatted" "$lead_time_hours")

# remove the tailing .nc
source=${source_raw%.nc}

singularity exec --nv \
    --bind ${HPC_PROJECT_DIR}:${HPC_PROJECT_DIR} \
    ${ANEMOI_CONTAINER_DIR} python ${python_script} \
    --epoch $epoch \
    --step $step \
    --run-id $RUN_ID \
    --inference-folder-path $INFERENCE_PROCESSED_DIR \
    --lead-time $lead_time_hours \
    --start-date $start_date_formatted \
    --fixer-name $FIXER_NAME \
    --catalog-base-path $catalog_base_path \
    --source $source \
    --reference-catalog $REFERENCE_DATA_CATALOG

# set AQUA catalog name to default aqua configuration
AQUA_CONFIG_FILE=$AQUA_CONFIG_DIR/config-aqua.yaml
sed -i "s/^catalog: null$/catalog: ${REFERENCE_DATA_CATALOG}/" "${AQUA_CONFIG_FILE}"

echo "Catalog entry created at ${catalog_yaml_path}"
