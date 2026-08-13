#!/bin/bash

# Utils functions for clean.sh

#####################################################
# Compresses and archives SIM job log files.
# Globals: LOG_DIR, CHUNKSIZEUNIT, CHUNK_END_IN_DAYS
#####################################################
function compress_logs() {
    SIM_JOBNAME=${CLEAN_JOBNAME//CLEAN/SIM}
    timestamp=$(date +"%Y%m%d%H%M%S")
    tar -I 'pigz -p ${SLURM_CPUS_PER_TASK:-1}' -cf "${LOG_DIR}/${SIM_JOBNAME}_${timestamp}.tar.gz" "${LOG_DIR}/${SIM_JOBNAME}"*
    for file in "${LOG_DIR}/${SIM_JOBNAME}"*; do
        if [ -f "$file" ] && [[ "$file" != *.tar.gz ]] && [[ "$file" != *COMPLETED* ]]; then
            rm "$file"
        fi
    done
}

#####################################################
# Compresses and archives rundir.
# Globals: CHUNKSIZEUNIT, CHUNK_END_IN_DAYS,
# CHUNK, CHUNKSIZE, HPCROOTDIR, runlength
#####################################################
function compress_rundir() {
    SIM_JOBNAME=${CLEAN_JOBNAME//CLEAN/SIM}
    # Compress and archive old rundirs
    if [ "${CHUNKSIZEUNIT}" == "month" ] || [ "${CHUNKSIZEUNIT}" == "year" ]; then
        runlength=${CHUNK_END_IN_DAYS}
        CHUNKSIZEUNIT=day
    else
        runlength=$((CHUNK * CHUNKSIZE))
    fi

    find_results=$(find "${HPCROOTDIR}" -type d \( -name "h$(($runlength * 24))*${SIM_JOBNAME}*" -o -name "run_${CHUNK_START_DATE}*" \) -print)
    while IFS= read -r rundir; do
        if [ -n "${rundir}" ]; then
            tar -I 'pigz -p ${SLURM_CPUS_PER_TASK:-1}' -cf "${rundir}.tar.gz" "${rundir}" && rm -rf "${rundir}"
        fi
    done <<<"$find_results"
}
