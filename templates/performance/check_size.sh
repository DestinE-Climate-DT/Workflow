#!/bin/bash

set -xuve

CLASS=${1:-%REQUEST.CLASS%}
DATASET=${2:-%REQUEST.DATASET%}
ACTIVITY=${3:-%REQUEST.ACTIVITY%}
EXPERIMENT=${4:-%REQUEST.EXPERIMENT%}
GENERATION=${5:-%REQUEST.GENERATION%}
MODEL=${6:-%REQUEST.MODEL%}
REALIZATION=${7:-%REQUEST.REALIZATION%}
EXPVER=${8:-%REQUEST.EXPVER%}
STREAM=${9:-%REQUEST.STREAM%}
START_DATE=${10:-%CHUNK_START_DATE%}
END_DATE=${11:-%CHUNK_SECOND_TO_LAST_DATE%}
FDB_HOME=${12:-%REQUEST.FDB_HOME%}
HPCROOTDIR=${13:-%HPCROOTDIR%}
# --------------------------------------

CONFIG_FILE="${FDB_HOME}/etc/fdb/config.yaml"
LOG_FILE="${HPCROOTDIR}/fdb_usage.log"

touch "$LOG_FILE"

# Collect FDB root paths
paths=$(grep 'path:' "$CONFIG_FILE" | awk '{print $3}' | sed 's/"//g' | sort -u)
echo "Paths: $paths"

# Check if paths are empty
if [[ -z "$paths" ]]; then
    echo "⚠️  No paths found in $CONFIG_FILE"
    exit 1
fi

# Filter out paths without read/execute permission
filtered_paths=""

for path in $paths; do
    if [ -r "$path" ] && [ -x "$path" ]; then
        filtered_paths="$filtered_paths $path"
    else
        echo "Skipping $path: insufficient permissions"
    fi
done

# Update paths variable
paths="$filtered_paths"

# Loop over date range
current_date="$START_DATE"
while [[ "$current_date" -le "$END_DATE" ]]; do
    FOLDER_NAME="${CLASS}:${DATASET}:${ACTIVITY}:${EXPERIMENT}:${GENERATION}:${MODEL}:${REALIZATION}:${EXPVER}:${STREAM}:${current_date}"

    found=false
    for root in $paths; do
        full_path="$root/$FOLDER_NAME"
        if [[ -d "$full_path" ]]; then
            size=$(du -sh "$full_path" | cut -f1)
            echo "$size  $full_path" >>"$LOG_FILE"
            found=true
        fi
    done

    if ! $found; then
        echo "⚠️  $current_date: Folder not found"
        exit 1
    fi

    # Increment date
    current_date=$(date -I -d "$current_date + 1 day" | tr -d '-')
done
