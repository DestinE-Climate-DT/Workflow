#!/bin/bash

EXPID=${1:-%DEFAULT.EXPID%}
USER=${2:-%CURRENT_USER%}
HPCROOTDIR=${3:-%HPCROOTDIR%}
FREQUENCY=${4:-%RUN.MEMORY_FREQUENCY%}
CHUNK=${5:-%CHUNK%}
WRAPPER=${6:-%WRAPPERS.WRAPPER.JOBS_IN_WRAPPER%}
SDATE=${7:-%SDATE%}
MEMBER=${8:-%MEMBER%}
CHUNK=${9:-%CHUNK%}

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

sentence="$(squeue -j $jobid)" # read job's slurm status
stringarray=("$sentence")
jobstatus=(${stringarsray[12]})

cd "${HPCROOTDIR}"
mkdir -p "check_mem/${CHUNK}"
cd "check_mem"/$CHUNK

until [ "$jobstatus" = "R" ]; do
    sleep 5s
    sentence="$(squeue -j $jobid)" # read job's slurm status
    stringarray=("$sentence")
    jobstatus=(${stringarray[12]})
done
NODES=$(sacct --noheader -X -P -oNodeList --jobs="$jobid")
NODES=$(echo "$NODES" | cut -d "[" -f2 | cut -d "]" -f1)
NODES=$(echo "$NODES" | perl -pe 's/(\d+)-(\d+)/join(",",$1..$2)/eg')
IFS=', ' read -r -a nodes <<<"$NODES"
for node in "${nodes[@]}"; do
    file=$node"_mem.txt"
    node2="nid[${node}]"
    (srun --overlap --jobid="$jobid" -w "$node2" free -s "$FREQUENCY" &) &>"$file"
done
