#!/bin/bash

# The model serving flow is designed to run inference using several dates but using one chunk at a time.
checker_msf() {
    local chunk_id="$1"

    if [ "${chunk_id}" -gt 1 ]; then
        echo "Chunk ID is greater than 1, skipping inference stage."
        exit 0
    fi

    echo "AutosubmitChunk ID is ${chunk_id}"
}

# retrieve the run id from the active run dir symlink, to be used in later stages
# example from <expid>/runs/active -> <expid>/runs/20240601_120000, it returns 20240601_120000
run_id_from_symlink() {
    local run_dir_symlink="$1"
    if [ ! -L "${run_dir_symlink}" ]; then
        echo "Error: ${run_dir_symlink} is not a symbolic link."
        exit 1
    fi
    echo "$(basename "$(readlink -f "${run_dir_symlink}")")"
}

# Converts SDATE (YYYYMMDD) to YYYY-MM-DDTHH:mm:ss format, with optional hour (default=12)
format_start_date() {
    local start_date="$1" # YYYYMMDD
    local hour="${2:-12}" # default = 12 if not provided

    printf "%s-%s-%sT%02d:00:00\n" \
        "${start_date:0:4}" \
        "${start_date:4:2}" \
        "${start_date:6:2}" \
        "${hour}"
}

# Builds the output netcdf path of the inference
build_name_inference_output() {
    local run_id="$1"
    local epoch="$2"
    local step="$3"
    local formatted_time="$4"
    local lead_time="$5"

    printf "run-%s_epoch-%s_step-%s_LT%d_SD-%s.nc\n" \
        "$run_id" "$epoch" "$step" "$lead_time" "$formatted_time"
}

# Computes lead time in hours
compute_lead_time_hours() {
    local start_date="$1" # YYYYMMDD
    local chunksize="$2"
    local chunksize_unit="$3"

    local start_ts=$(date -d "$start_date" +%s)
    local end_ts=$(date -d "$start_date +$chunksize $chunksize_unit" +%s)
    echo $(((end_ts - start_ts) / 3600))
}
