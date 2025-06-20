#!/bin/bash

# HEADER

EXPID=${1:-%DEFAULT.EXPID%}
USER=${2:-%CURRENT_USER%}
HPCROOTDIR=${3:-%HPCROOTDIR%}
FREQUENCY=${4:-%RUN.MEMORY_FREQUENCY%}
CHUNK=${5:-%CHUNK%}
WRAPPER=${6:-%WRAPPERS.WRAPPER.JOBS_IN_WRAPPER%}
SDATE=${7:-%SDATE%}
MEMBER=${8:-%MEMBER%}
CHUNK=${9:-%CHUNK%}
MODEL=${10:-%MODEL.NAME%}
RESOLUTION=${11:-%MODEL.RESOLUTION%}
SCRIPTDIR=${12:-%CONFIGURATION.SCRIPTDIR%}

# END_HEADER

# Run squeue and filter the output for the given job nam
SIM_NAME="${EXPID}_${SDATE}_${MEMBER}_${CHUNK}_SIM"

if [ -n "${WRAPPER}" ]; then
    # Using wrappers
    squeue_output=$(squeue --user="${USER}" --format="%10i %50j" | grep "${EXPID}_ASThread")
else
    squeue_output=$(squeue --user="${USER}" --format="%10i %50j" | grep "${SIM_NAME}")
fi

# Extract JOBID from the filtered output
jobid=$(echo "$squeue_output" | awk '{print $1}')

# Display the result
if [ -n "$jobid" ]; then
    echo "JOBID for $EXPID: $jobid"
else
    echo "Job not found: $EXPID"
fi

cd "${HPCROOTDIR}"
mkdir -p "check_mem/${CHUNK}"
cd "check_mem"/$CHUNK

NODES=$(sacct --noheader -X -P -oNodeList --jobs="$jobid")
NODES=$(echo "$NODES" | cut -d "[" -f2 | cut -d "]" -f1)
NODES=$(echo "$NODES" | perl -pe 's/(\d+)-(\d+)/join(",",$1..$2)/eg')
IFS=', ' read -r -a nodes <<<"$NODES"
for node in "${nodes[@]}"; do
    file=$node"_mem.txt"
    node2="nid[${node}]"
    (srun --wait --overlap --jobid="$jobid" -w "$node2" free -s "$FREQUENCY" &) &>"$file"
done

JSON_FILE_PATH="${HPCROOTDIR}/check_mem/memory_bloat_${CHUNK}.json"
python3 "${SCRIPTDIR}"/CPMIP/memory_bloat.py --jobID "$jobid" --model "$MODEL" \
    --resolution "$RESOLUTION" --jsonfile "$JSON_FILE_PATH"
