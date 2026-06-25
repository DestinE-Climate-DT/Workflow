#!/bin/bash

# HEADER
HPCROOTDIR=${1:-%HPCROOTDIR%}
SIM_START_DATE=${2:-%SDATE%}
MEMBER=${3:-%MEMBER%}
CHUNK=${4:-%CHUNK%}
SLURM_FREQ=${5:-%JOBS.PERFORMANCE_METRICS.SLURM_FREQ%}
# END_HEADER

set -xuve

# All the model/grid/request/io values come from the per-chunk env file the SIM
# job wrote (and the MONITOR_RESOURCES job has since populated with monitor
# output). We only need to locate that file and read it.
#
# Layout: ${HPCROOTDIR}/performance/<jobname>-<jobid>/<sdate>_<member>_<chunk>/
#             env.json       (read here)
#             monitor/       (resource monitor output)
#             performance/   (our output)
CHUNK_KEY="${SIM_START_DATE}_${MEMBER}_${CHUNK}"
PERF_ROOT="${HPCROOTDIR}/performance"
CURRENT_POINTER="${PERF_ROOT}/.current/${CHUNK_KEY}"

# Read the chunk-keyed pointer the SIM published (it names the current attempt
# deterministically). PERFORMANCE_METRICS removes it on success, so it is still
# present here because the SIM published it and this job hasn't finished yet.
ENV_FILE=""
if [ -f "${CURRENT_POINTER}" ]; then
    chunk_dir=$(cat "${CURRENT_POINTER}" 2>/dev/null || true)
    if [ -n "${chunk_dir}" ] && [ -f "${chunk_dir}/env.json" ]; then
        ENV_FILE="${chunk_dir}/env.json"
    fi
fi

if [ -z "${ENV_FILE}" ] || [ ! -f "${ENV_FILE}" ]; then
    echo "ERROR: performance env pointer ${CURRENT_POINTER} missing or its env.json not found"
    exit 1
fi
echo "INFO: using performance env file: ${ENV_FILE}"

# Read the env file as shell variables. COMPLEXITY and IO_CONFIG are emitted as
# JSON strings (the form performance_metrics.py expects for --complexity /
# --io_config); everything else is a scalar.
eval "$(
    ENV_FILE="${ENV_FILE}" python3 <<'PY'
import json
import os
import shlex

with open(os.environ["ENV_FILE"], encoding="utf-8") as handle:
    data = json.load(handle)

scalars = (
    "SIM_JOBID",
    "SIM_JOBNAME",
    "PERF_CHUNK_DIR",
    "MODEL_NAME",
    "EXPID",
    "MEMBER",
    "CHUNK",
    "HPC",
    "GRID_ATM",
    "GRID_OCE",
    "RESOLUTION_KM",
    "PERFORMANCE_RESOLUTION",
    "START_DATE_CHUNK",
    "END_DATE_CHUNK",
    "FDB_HOME",
    "CLASS",
    "DATASET",
    "ACTIVITY",
    "EXPERIMENT",
    "GENERATION",
    "MODEL_REQ",
    "REALIZATION",
    "EXPVER",
    "STREAM",
    "RUNDIR",
    "RUNDIR_PATH",
    "TASKS_PER_NODE",
    "THREADS",
    "PROCESSOR_UNIT",
    "SCRIPTDIR",
    "LIBDIR",
)
for key in scalars:
    print(f"{key}={shlex.quote(str(data.get(key, '')))}")
for key in ("COMPLEXITY", "IO_CONFIG"):
    print(f"{key}={shlex.quote(json.dumps(data.get(key, {})))}")
PY
)"

MONITOR_DIR="${PERF_CHUNK_DIR}/monitor"
PERFORMANCE_DIR="${PERF_CHUNK_DIR}/performance"
mkdir -p "${PERFORMANCE_DIR}"

# HPC name is the CURRENT_ARCH prefix (e.g. MARENOSTRUM5-TRANSFER -> MARENOSTRUM5).
HPC_NAME=$(echo "${HPC}" | cut -d- -f1)

# performance_metrics.py imports typing.TypedDict (Python >= 3.8), but the bare
# host python3 on LUMI is older. Load the project's Python module the same way
# the monitor job does. It runs on the host (not in the container) because it
# shells out to sacct/sstat, which aren't available inside the SIF.
source "${LIBDIR}"/"${HPC_NAME}"/config.sh
source "${LIBDIR}"/common/util.sh
# lib/LUMI/config.sh (load_additional_modules) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_additional_modules) (auto generated comment)
load_additional_modules

# Rundir for I/O analysis: the SIM resolved it after the run and stored it in
# the env file (authoritative even for wrapped chunks). Fall back to a job-id
# search only if it is missing.
rundir="${RUNDIR}"
if [ -z "${rundir}" ] || [ "${rundir}" = "N/A" ]; then
    rundir=$(find "${RUNDIR_PATH}" -type d -name "*-${SIM_JOBID}" -print -quit 2>/dev/null)
    [ -z "${rundir}" ] && rundir="N/A"
fi
echo "INFO: rundir for I/O analysis: ${rundir}"

PYTHON_SCRIPT="${SCRIPTDIR}/CPMIP/performance_metrics.py"

PYTHON_ARGS=(
    --jobid "${SIM_JOBID}"
    --job_name "${SIM_JOBNAME}"
    --expid "${EXPID}"
    --member "${MEMBER}"
    --chunk "${CHUNK}"
    --hpcrootdir "${HPCROOTDIR}"
    --sdate "${SIM_START_DATE}"
    --model "${MODEL_NAME}"
    --resolution_km "${RESOLUTION_KM}"
    --grid_atm "${GRID_ATM}"
    --grid_oce "${GRID_OCE}"
    --complexity "${COMPLEXITY}"
    --hpc "${HPC_NAME}"
    --start_date_chunk "${START_DATE_CHUNK}"
    --end_date_chunk "${END_DATE_CHUNK}"
    --output_dir "${PERFORMANCE_DIR}"
    --fdb_home "${FDB_HOME}"
    --class_val "${CLASS}"
    --dataset "${DATASET}"
    --activity "${ACTIVITY}"
    --experiment "${EXPERIMENT}"
    --generation "${GENERATION}"
    --model_req "${MODEL_REQ}"
    --realization "${REALIZATION}"
    --expver "${EXPVER}"
    --stream "${STREAM}"
    --slurm_freq "${SLURM_FREQ:-60}"
    --monitor_dir "${MONITOR_DIR}"
    --rundir_path "${rundir}"
    --tasks_per_node "${TASKS_PER_NODE:-0}"
    --performance_resolution "${PERFORMANCE_RESOLUTION}"
    --io_config "${IO_CONFIG}"
    --threads "${THREADS:-1}"
    --processor_unit "${PROCESSOR_UNIT:-cpu}"
)

CPMIPS_FILE="${PERFORMANCE_DIR}/CPMIPS/CPMIPS.json.gz"

echo "==================================================================="
echo "INFO: START performance metrics computation  $(date '+%Y-%m-%d %H:%M:%S')"
echo "INFO:   SIM job id  : ${SIM_JOBID}"
echo "INFO:   chunk       : ${CHUNK_KEY}"
echo "INFO:   monitor dir : ${MONITOR_DIR}"
echo "INFO:   rundir      : ${rundir}"
echo "INFO:   output file : ${CPMIPS_FILE}"
echo "==================================================================="

python3 "${PYTHON_SCRIPT}" "${PYTHON_ARGS[@]}"

# Metrics computed: remove the chunk pointer so a future run's MONITOR_RESOURCES
# never binds to a stale one before its SIM republishes it. Only runs on success
# (set -e aborts above on failure, leaving the pointer for a retry to reuse).
rm -f "${CURRENT_POINTER}"

echo "==================================================================="
echo "INFO: END performance metrics computation  $(date '+%Y-%m-%d %H:%M:%S')"
echo "INFO:   metrics written to: ${CPMIPS_FILE}"
echo "==================================================================="
