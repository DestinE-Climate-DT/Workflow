#!/bin/bash

# HEADER
HPCROOTDIR=${1:-%HPCROOTDIR%}
SIM_START_DATE=${2:-%SDATE%}
MEMBER=${3:-%MEMBER%}
CHUNK=${4:-%CHUNK%}
SAMPLING_FREQUENCY=${5:-%JOBS.MONITOR_RESOURCES.SAMPLING_FREQ%}
SLURM_FREQUENCY=${6:-%JOBS.MONITOR_RESOURCES.SLURM_FREQ%}
# Required by load_singularity (sourced from the HPC config below) to build
# SINGULARITY_BIND: under 'set -u' it aborts if these are unset. Exported
# because their only consumer is that sourced helper, not this script directly.
export SCRATCH_DIR=${7:-%CURRENT_SCRATCH_DIR%}
export HPC_PROJECT_ROOT=${8:-%CURRENT_HPC_PROJECT_ROOT%}
export LOCAL_DIR=${9:-%CURRENT_LOCAL_DIR%}
# END_HEADER

set -xuve

# Everything else (SIM job id, container, paths) comes from the per-chunk env
# file the SIM job writes. The monitor is triggered on SIM RUNNING, so it only
# needs to locate that file and attach to the job id recorded inside it.
#
# Layout: ${HPCROOTDIR}/performance/<jobname>-<jobid>/<sdate>_<member>_<chunk>/
#             env.json      (read here)
#             monitor/      (our output)
CHUNK_KEY="${SIM_START_DATE}_${MEMBER}_${CHUNK}"
PERF_ROOT="${HPCROOTDIR}/performance"

# Resolve THIS run's env file and bind the monitor to the SIM job it names.
#
# The SIM publishes a chunk-keyed pointer (.current/${CHUNK_KEY}) naming the
# current attempt's chunk dir, so we follow that instead of guessing by mtime.
# The monitor is triggered on SIM RUNNING and the SIM writes the pointer +
# env.json only after its (slow) setup, so neither may exist yet — and a re-run
# may briefly leave a stale pointer from a dead attempt. So we re-check every
# 30s (up to 5 min) and accept the env.json only once its SIM_JOBID is a live
# SLURM job; the liveness check rejects any dead attempt until the current run
# publishes its own.
CURRENT_POINTER="${PERF_ROOT}/.current/${CHUNK_KEY}"

env_file_job_is_live() {
    local env_path="$1" job_id
    job_id=$(ENV_FILE="${env_path}" python3 -c '
import json
import os

try:
    with open(os.environ["ENV_FILE"], encoding="utf-8") as handle:
        print(json.load(handle).get("SIM_JOBID", ""))
except Exception:
    pass
' 2>/dev/null)
    [ -n "${job_id}" ] || return 1
    [ -n "$(squeue -h -j "${job_id}" 2>/dev/null)" ]
}

ENV_FILE=""
elapsed=0
while true; do
    CANDIDATE=""
    # Follow the SIM's pointer to the current attempt's chunk dir; accept only
    # once its env.json exists (the pointer may briefly precede the env write).
    if [ -f "${CURRENT_POINTER}" ]; then
        chunk_dir=$(cat "${CURRENT_POINTER}" 2>/dev/null || true)
        if [ -n "${chunk_dir}" ] && [ -f "${chunk_dir}/env.json" ]; then
            CANDIDATE="${chunk_dir}/env.json"
        fi
    fi
    if [ -n "${CANDIDATE}" ] && env_file_job_is_live "${CANDIDATE}"; then
        ENV_FILE="${CANDIDATE}"
        break
    fi
    if [ "${elapsed}" -ge 300 ]; then
        break
    fi
    echo "INFO: current env.json for ${CHUNK_KEY} is not from a live SIM job yet; re-checking in 30s (waited ${elapsed}s)"
    sleep 30
    elapsed=$((elapsed + 30))
done

if [ -z "${ENV_FILE}" ] || [ ! -f "${ENV_FILE}" ]; then
    # No live SIM job for this chunk within the 5 min window — the chunk finished
    # before the monitor could attach (e.g. a very short chunk). Nothing to
    # sample, so exit cleanly: PERFORMANCE_METRICS depends on MONITOR_RESOURCES
    # COMPLETED and recovers the chunk from sacct on its own.
    echo "INFO: no live SIM job for chunk ${CHUNK_KEY} after 5 min; SIM already finished — nothing to monitor."
    exit 0
fi
echo "INFO: using performance env file: ${ENV_FILE}"

# Read the values we need from the JSON env file as shell variables.
eval "$(
    ENV_FILE="${ENV_FILE}" python3 <<'PY'
import json
import os
import shlex

with open(os.environ["ENV_FILE"], encoding="utf-8") as handle:
    data = json.load(handle)

for key in (
    "SIM_JOBID",
    "PERF_CHUNK_DIR",
    "HPC_CONTAINER_DIR",
    "PERFORMANCE_METRICS_VERSION",
    "SCRIPTDIR",
    "LIBDIR",
    "HPC",
    "PROCESSOR_UNIT",
):
    print(f"{key}={shlex.quote(str(data.get(key, '')))}")
PY
)"

jobid="${SIM_JOBID}"
PERFORMANCE_DIR="${PERF_CHUNK_DIR}/monitor"
mkdir -p "${PERFORMANCE_DIR}"

echo "INFO: monitoring SIM job ${jobid}; writing to ${PERFORMANCE_DIR}"

# source libraries (HPC name is the CURRENT_ARCH prefix, e.g. MARENOSTRUM5-... )
HPC_NAME=$(echo "${HPC}" | cut -d- -f1)
source "${LIBDIR}"/"${HPC_NAME}"/config.sh
source "${LIBDIR}"/common/util.sh
# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity
# lib/LUMI/config.sh (load_additional_modules) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_additional_modules) (auto generated comment)
load_additional_modules

CONTAINER_SIF="${HPC_CONTAINER_DIR}/performance_metrics_${PERFORMANCE_METRICS_VERSION}.sif"
echo "INFO: using container: ${CONTAINER_SIF}"

echo "==================================================================="
echo "INFO: START resource monitoring  $(date '+%Y-%m-%d %H:%M:%S')"
echo "INFO:   SIM job id : ${jobid}"
echo "INFO:   chunk      : ${CHUNK_KEY}"
echo "INFO:   output dir : ${PERFORMANCE_DIR}"
echo "INFO:   (metrics under ${PERFORMANCE_DIR}/{metadata,sstat,pidstat})"
echo "==================================================================="

# GPU sampling (rocm-smi) only makes sense on GPU runs. Gate it on the processor
# unit from the env file so CPU runs don't try to run rocm-smi. rocm-smi runs
# natively on the host, so no container path is passed for it.
ROCM_ARGS=()
if [ "${PROCESSOR_UNIT,,}" = "gpu" ]; then
    ROCM_ARGS=(--rocm-smi-path "rocm-smi")
fi

# Don't launch the per-node sampler steps until the model's OWN step is running.
# On Cray MPICH a sampler step that overlaps the model's MPI_Init PMI node-local
# mmap bootstrap corrupts it ('_pmi_mmap_tmp bootstrap barrier failed'), aborting
# the model. The job being live only means the SIM script is running — its setup
# precedes the model srun — so wait here for a real application step (squeue -s
# lists only RUNNING steps; .batch / .extern are never the model), then a short
# grace for the bootstrap to finish. Bail early if the chunk already finished.
SAMPLER_WAIT_TIMEOUT=600
SAMPLER_START_GRACE=30
waited=0
while [ "${waited}" -lt "${SAMPLER_WAIT_TIMEOUT}" ]; do
    if [ -f "${PERF_CHUNK_DIR}/sim_done" ]; then
        echo "INFO: SIM already finished (sim_done present); not waiting for an application step"
        break
    fi
    app_step=$(squeue -s -h -j "${jobid}" -o '%i' 2>/dev/null |
        awk '$1 !~ /\.(batch|extern)$/ {print $1; exit}' || true)
    if [ -n "${app_step}" ]; then
        echo "INFO: application step ${app_step} running; waiting ${SAMPLER_START_GRACE}s for MPI init to settle before sampling"
        sleep "${SAMPLER_START_GRACE}"
        break
    fi
    sleep 10
    waited=$((waited + 10))
done
if [ "${waited}" -ge "${SAMPLER_WAIT_TIMEOUT}" ]; then
    echo "INFO: no application step for job ${jobid} within ${SAMPLER_WAIT_TIMEOUT}s; starting samplers anyway"
fi

# Run as a module from the project root so relative imports resolve. SLURM
# commands (scontrol/sstat/squeue) run natively on the host; pidstat is reached
# on each compute node via srun --overlap + singularity (hence the container).
cd "${SCRIPTDIR}/.." || exit 1
python3 -m runscripts.CPMIP.resource_monitor \
    --jobid "${jobid}" \
    --frequency "${SAMPLING_FREQUENCY}" \
    --slurm_frequency "${SLURM_FREQUENCY}" \
    --output-dir "${PERFORMANCE_DIR}" \
    --pidstat-path "/usr/local/bin/pidstat" \
    --container-sif "${CONTAINER_SIF}" \
    --stop-file "${PERF_CHUNK_DIR}/sim_done" \
    "${ROCM_ARGS[@]}"

echo "==================================================================="
echo "INFO: END resource monitoring  $(date '+%Y-%m-%d %H:%M:%S')"
echo "INFO:   monitor output written to: ${PERFORMANCE_DIR}"
echo "==================================================================="
