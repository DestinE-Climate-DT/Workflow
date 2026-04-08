#!/bin/bash

set -xuve

# HEADER
EXPID=${1:-%DEFAULT.EXPID%}
USER=${2:-%CURRENT_USER%}
HPCROOTDIR=${3:-%HPCROOTDIR%}
CHUNK=${4:-%CHUNK%}
WRAPPER=${5:-%WRAPPERS.WRAPPER.JOBS_IN_WRAPPER%}
SIM_START_DATE=${6:-%SDATE%}
MEMBER=${7:-%MEMBER%}
MODEL_NAME=${8:-%MODEL.NAME%}
RESOLUTION=${9:-%MODEL.RESOLUTION%}
SCRIPTDIR=${10:-%CONFIGURATION.SCRIPTDIR%}
CURRENT_ARCH=${11:-%CURRENT_ARCH%}
CHUNK_START_DATE=${12:-%CHUNK_START_DATE%}
CHUNK_SECOND_TO_LAST_DATE=${13:-%CHUNK_SECOND_TO_LAST_DATE%}
FDB_HOME=${14:-%REQUEST.FDB_HOME%}
CLASS=${15:-%REQUEST.CLASS%}
DATASET=${16:-%REQUEST.DATASET%}
ACTIVITY=${17:-%REQUEST.ACTIVITY%}
EXPERIMENT=${18:-%REQUEST.EXPERIMENT%}
GENERATION=${19:-%REQUEST.GENERATION%}
MODEL_REQ=${20:-%REQUEST.MODEL%}
REALIZATION=${21:-%REQUEST.REALIZATION%}
EXPVER=${22:-%REQUEST.EXPVER%}
STREAM=${23:-%REQUEST.STREAM%}
GRID_ATM=${24:-%MODEL.GRID_ATM%}
GRID_OCE=${25:-%MODEL.GRID_OCE%}
# Complexity variables - will be loaded based on model
COMPLEXITY_ATMOSPHERE=${26:-%PERFORMANCE_METRICS.COMPLEXITY.ATMOSPHERE%}
COMPLEXITY_OCEAN=${27:-%PERFORMANCE_METRICS.COMPLEXITY.OCEAN%}
COMPLEXITY_LAND=${28:-%PERFORMANCE_METRICS.COMPLEXITY.LAND%}
COMPLEXITY_IFS=${29:-%PERFORMANCE_METRICS.COMPLEXITY.IFS%}
COMPLEXITY_NEMO=${30:-%PERFORMANCE_METRICS.COMPLEXITY.NEMO%}
HPC_CONTAINER_DIR=${31:-%CURRENT_CONTAINER_DIR%}
PERFORMANCE_METRICS_VERSION=${32:-%PERFORMANCE_METRICS.VERSION%}
TASKS_PER_NODE=${33:-%JOBS.SIM.TASKS%}
PERFORMANCE_RESOLUTION=${34:-%PERFORMANCE_METRICS.RESOLUTION%}
SLURM_FREQ=${35:-%JOBS.PERFORMANCE_METRICS.SLURM_FREQ%}
LIBDIR=${36:-%CONFIGURATION.LIBDIR%}
THREADS=${37:-%JOBS.SIM.THREADS%}
PROCESSOR_UNIT=${38:-%RUN.PROCESSOR_UNIT%}
# RUNDIR_PATH=${39:-%CONFIGURATION.RUNDIR_PATH%}  # Deprecated: rundir is now auto-discovered
# END_HEADER

# Build job name
if [ -n "${WRAPPER:-}" ]; then
    jobname="${EXPID}_ASThread"
else
    jobname="${EXPID}_${SIM_START_DATE}_${MEMBER}_${CHUNK}_SIM"
fi

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

# lib/LUMI/config.sh (load_additional_modules) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_additional_modules) (auto generated comment)
load_additional_modules

# Build path to resource monitor metadata directory
# Note: We'll get the job ID from the monitor metadata, which follows pattern: ${jobname}-${jobid}
# For now, we need to find it since we don't know the jobid yet
MONITOR_METADATA_DIR_BASE="${HPCROOTDIR}/performance/monitor"

echo "INFO: Searching for monitor metadata in: ${MONITOR_METADATA_DIR_BASE}"

# Find the most recent metadata directory for this job name
MONITOR_DIR=$(find "${MONITOR_METADATA_DIR_BASE}" -type d -name "${jobname}-*" -print | sort -r | head -1 2>/dev/null)

if [ -z "$MONITOR_DIR" ]; then
    echo "ERROR: Could not find monitor directory for job ${jobname}"
    echo "Searched in: ${MONITOR_METADATA_DIR_BASE}"
    echo "Available monitor directories:"
    ls -la "${MONITOR_METADATA_DIR_BASE}" 2>/dev/null || echo "  Directory does not exist or is empty"
    exit 1
fi

echo "INFO: Found monitor directory: ${MONITOR_DIR}"

MONITOR_METADATA_DIR="${MONITOR_DIR}/metadata"

# Verify metadata directory exists
if [ ! -d "${MONITOR_METADATA_DIR}" ]; then
    echo "ERROR: Monitor metadata directory not found: ${MONITOR_METADATA_DIR}"
    exit 1
fi

# Verify end.json.gz file exists
MONITOR_END_FILE="${MONITOR_METADATA_DIR}/end.json.gz"
if [ ! -f "${MONITOR_END_FILE}" ]; then
    echo "ERROR: Monitor end file not found: ${MONITOR_END_FILE}"
    echo "Available files in metadata directory:"
    ls -la "${MONITOR_METADATA_DIR}" || true
    exit 1
fi

echo "INFO: Using monitor metadata from: ${MONITOR_END_FILE}"

# Extract Job ID from end.json.gz file (nested in Job_Metadata)

jobid=$(gzip -dc "${MONITOR_END_FILE}" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('Job_Metadata', {}).get('Job_Id', ''))")

if [ -z "$jobid" ]; then
    echo "ERROR: Could not extract Job_Id from ${MONITOR_END_FILE}"
    echo "Attempting to display file contents for debugging:"
    gzip -dc "${MONITOR_END_FILE}" | python3 -m json.tool | head -20 || true
    exit 1
fi

echo "INFO: Extracted Job ID: ${jobid}"

# Validate that the job exists in sacct
job_info=$(sacct -j "$jobid" --noheader -P -o JobIDRaw,JobName%1000,ElapsedRaw,State 2>/dev/null)
if [ -z "$job_info" ]; then
    echo "ERROR: Job $jobid not found in sacct"
    exit 1
fi

# Build consistent performance directory name: ${jobname}-${jobid}
PERFORMANCE_DIR="${HPCROOTDIR}/performance/performance_metrics/${jobname}-${jobid}"
echo "INFO: Using performance directory: ${PERFORMANCE_DIR}"

# Find rundir path using jobname and jobid pattern
rundir=$(find "${HPCROOTDIR}/rundir/${SIM_START_DATE}/${MEMBER}/${CHUNK}" -type d -name "h*${jobname}-${jobid}" -print -quit 2>/dev/null)

if [ -z "$rundir" ]; then
    echo "WARNING: Could not find rundir with pattern h*${jobname}-${jobid}"
    echo "         Searched in: ${HPCROOTDIR}/rundir/${SIM_START_DATE}/${MEMBER}/${CHUNK}"
    rundir="N/A"
else
    echo "INFO: Found rundir: ${rundir}"
fi

# Extract HPC name from CURRENT_ARCH (e.g., MARENOSTRUM5-TRANSFER -> MARENOSTRUM5)
HPC_NAME_UPPER=$(echo "${CURRENT_ARCH:-N/A}" | cut -d- -f1 | tr '[:lower:]' '[:upper:]')

echo "INFO: Detecting configuration for platform: ${HPC_NAME_UPPER}"

# Set all platform-dependent parameters based on HPC (unified case statement)
case "${HPC_NAME_UPPER}" in
MARENOSTRUM5)
    # Tasks per node
    if [ -z "${TASKS_PER_NODE}" ] || [ "${TASKS_PER_NODE}" == "N/A" ] || [ "${TASKS_PER_NODE}" -eq 0 ] 2>/dev/null; then
        TASKS_PER_NODE="%PLATFORMS.MARENOSTRUM5.TASKS%"
        echo "INFO: Using PLATFORMS.MARENOSTRUM5.TASKS as fallback: ${TASKS_PER_NODE}"
    fi

    # Threads per task
    if [ -z "${THREADS}" ] || [ "${THREADS}" == "N/A" ] || [ "${THREADS}" -eq 0 ] 2>/dev/null; then
        THREADS="%PLATFORMS.MARENOSTRUM5.THREADS%"
        echo "INFO: Using PLATFORMS.MARENOSTRUM5.THREADS as fallback: ${THREADS}"
    fi

    # I/O configuration
    IFS_IO_TASKS="${IFS_IO_TASKS:-%PLATFORMS.MARENOSTRUM5.IFS_IO_TASKS%}"
    IFS_IO_NODES="${IFS_IO_NODES:-%PLATFORMS.MARENOSTRUM5.IFS_IO_NODES%}"
    IFS_IO_PPN="${IFS_IO_PPN:-%PLATFORMS.MARENOSTRUM5.IFS_IO_PPN%}"
    NEMO_IO_TASKS="${NEMO_IO_TASKS:-%PLATFORMS.MARENOSTRUM5.NEMO_IO_TASKS%}"
    NEMO_IO_NODES="${NEMO_IO_NODES:-%PLATFORMS.MARENOSTRUM5.NEMO_IO_NODES%}"
    NEMO_IO_PPN="${NEMO_IO_PPN:-%PLATFORMS.MARENOSTRUM5.NEMO_IO_PPN%}"
    FESOM_IO_TASKS="${FESOM_IO_TASKS:-%PLATFORMS.MARENOSTRUM5.FESOM_IO_TASKS%}"
    FESOM_IO_NODES="${FESOM_IO_NODES:-%PLATFORMS.MARENOSTRUM5.FESOM_IO_NODES%}"
    FESOM_IO_PPN="${FESOM_IO_PPN:-%PLATFORMS.MARENOSTRUM5.FESOM_IO_PPN%}"
    echo "INFO: Using MARENOSTRUM5 configuration"
    ;;
LUMI)
    # Tasks per node
    if [ -z "${TASKS_PER_NODE}" ] || [ "${TASKS_PER_NODE}" == "N/A" ] || [ "${TASKS_PER_NODE}" -eq 0 ] 2>/dev/null; then
        TASKS_PER_NODE="%PLATFORMS.LUMI.TASKS%"
        echo "INFO: Using PLATFORMS.LUMI.TASKS as fallback: ${TASKS_PER_NODE}"
    fi

    # Threads per task
    if [ -z "${THREADS}" ] || [ "${THREADS}" == "N/A" ] || [ "${THREADS}" -eq 0 ] 2>/dev/null; then
        THREADS="%PLATFORMS.LUMI.THREADS%"
        echo "INFO: Using PLATFORMS.LUMI.THREADS as fallback: ${THREADS}"
    fi

    # I/O configuration
    IFS_IO_TASKS="${IFS_IO_TASKS:-%PLATFORMS.LUMI.IFS_IO_TASKS%}"
    IFS_IO_NODES="${IFS_IO_NODES:-%PLATFORMS.LUMI.IFS_IO_NODES%}"
    IFS_IO_PPN="${IFS_IO_PPN:-%PLATFORMS.LUMI.IFS_IO_PPN%}"
    NEMO_IO_TASKS="${NEMO_IO_TASKS:-%PLATFORMS.LUMI.NEMO_IO_TASKS%}"
    NEMO_IO_NODES="${NEMO_IO_NODES:-%PLATFORMS.LUMI.NEMO_IO_NODES%}"
    NEMO_IO_PPN="${NEMO_IO_PPN:-%PLATFORMS.LUMI.NEMO_IO_PPN%}"
    FESOM_IO_TASKS="${FESOM_IO_TASKS:-%PLATFORMS.LUMI.FESOM_IO_TASKS%}"
    FESOM_IO_NODES="${FESOM_IO_NODES:-%PLATFORMS.LUMI.FESOM_IO_NODES%}"
    FESOM_IO_PPN="${FESOM_IO_PPN:-%PLATFORMS.LUMI.FESOM_IO_PPN%}"
    echo "INFO: Using LUMI configuration"
    ;;
*)
    echo "WARNING: Unknown platform ${HPC_NAME_UPPER}, configuration may be incomplete"
    # Set defaults for unknown platforms
    if [ -z "${TASKS_PER_NODE}" ] || [ "${TASKS_PER_NODE}" == "N/A" ] || [ "${TASKS_PER_NODE}" -eq 0 ] 2>/dev/null; then
        TASKS_PER_NODE=0
        echo "WARNING: Could not determine tasks per node for HPC: ${HPC_NAME_UPPER}"
    fi
    if [ -z "${THREADS}" ] || [ "${THREADS}" == "N/A" ] || [ "${THREADS}" -eq 0 ] 2>/dev/null; then
        THREADS=1
        echo "WARNING: Could not determine threads for HPC: ${HPC_NAME_UPPER}, defaulting to 1"
    fi
    ;;
esac

# Validate and convert IFS I/O tasks to integer
if [ -n "${IFS_IO_TASKS}" ] && [ "${IFS_IO_TASKS}" != "N/A" ] && [ "${IFS_IO_TASKS}" -gt 0 ] 2>/dev/null; then
    echo "INFO: IFS I/O tasks: ${IFS_IO_TASKS}"
else
    IFS_IO_TASKS=0
    echo "INFO: IFS I/O tasks not configured (IFS_IO_TASKS=${IFS_IO_TASKS})"
fi

# Validate and convert IFS I/O nodes to integer
if [ -n "${IFS_IO_NODES}" ] && [ "${IFS_IO_NODES}" != "N/A" ] && [ "${IFS_IO_NODES}" -gt 0 ] 2>/dev/null; then
    echo "INFO: IFS I/O nodes: ${IFS_IO_NODES}"
else
    IFS_IO_NODES=0
    echo "INFO: IFS I/O nodes not configured (IFS_IO_NODES=${IFS_IO_NODES})"
fi

# Validate and convert IFS I/O PPN to integer
if [ -n "${IFS_IO_PPN}" ] && [ "${IFS_IO_PPN}" != "N/A" ] && [ "${IFS_IO_PPN}" -gt 0 ] 2>/dev/null; then
    echo "INFO: IFS I/O PPN: ${IFS_IO_PPN}"
else
    IFS_IO_PPN=0
    echo "INFO: IFS I/O PPN not configured (IFS_IO_PPN=${IFS_IO_PPN})"
fi

# Validate and convert NEMO I/O tasks to integer
if [ -n "${NEMO_IO_TASKS}" ] && [ "${NEMO_IO_TASKS}" != "N/A" ] && [ "${NEMO_IO_TASKS}" -gt 0 ] 2>/dev/null; then
    echo "INFO: NEMO I/O tasks: ${NEMO_IO_TASKS}"
else
    NEMO_IO_TASKS=0
    echo "INFO: NEMO I/O tasks not configured (NEMO_IO_TASKS=${NEMO_IO_TASKS})"
fi

# Validate and convert NEMO I/O nodes to integer
if [ -n "${NEMO_IO_NODES}" ] && [ "${NEMO_IO_NODES}" != "N/A" ] && [ "${NEMO_IO_NODES}" -gt 0 ] 2>/dev/null; then
    echo "INFO: NEMO I/O nodes: ${NEMO_IO_NODES}"
else
    NEMO_IO_NODES=0
    echo "INFO: NEMO I/O nodes not configured (NEMO_IO_NODES=${NEMO_IO_NODES})"
fi

# Validate and convert NEMO I/O PPN to integer
if [ -n "${NEMO_IO_PPN}" ] && [ "${NEMO_IO_PPN}" != "N/A" ] && [ "${NEMO_IO_PPN}" -gt 0 ] 2>/dev/null; then
    echo "INFO: NEMO I/O PPN: ${NEMO_IO_PPN}"
else
    NEMO_IO_PPN=0
    echo "INFO: NEMO I/O PPN not configured (NEMO_IO_PPN=${NEMO_IO_PPN})"
fi

# Validate and convert FESOM I/O tasks to integer
if [ -n "${FESOM_IO_TASKS}" ] && [ "${FESOM_IO_TASKS}" != "N/A" ] && [ "${FESOM_IO_TASKS}" -gt 0 ] 2>/dev/null; then
    echo "INFO: FESOM I/O tasks: ${FESOM_IO_TASKS}"
else
    FESOM_IO_TASKS=0
    echo "INFO: FESOM I/O tasks not configured (FESOM_IO_TASKS=${FESOM_IO_TASKS})"
fi

# Validate and convert FESOM I/O nodes to integer
if [ -n "${FESOM_IO_NODES}" ] && [ "${FESOM_IO_NODES}" != "N/A" ] && [ "${FESOM_IO_NODES}" -gt 0 ] 2>/dev/null; then
    echo "INFO: FESOM I/O nodes: ${FESOM_IO_NODES}"
else
    FESOM_IO_NODES=0
    echo "INFO: FESOM I/O nodes not configured (FESOM_IO_NODES=${FESOM_IO_NODES})"
fi

# Validate and convert FESOM I/O PPN to integer
if [ -n "${FESOM_IO_PPN}" ] && [ "${FESOM_IO_PPN}" != "N/A" ] && [ "${FESOM_IO_PPN}" -gt 0 ] 2>/dev/null; then
    echo "INFO: FESOM I/O PPN: ${FESOM_IO_PPN}"
else
    FESOM_IO_PPN=0
    echo "INFO: FESOM I/O PPN not configured (FESOM_IO_PPN=${FESOM_IO_PPN})"
fi

# Validate and convert threads to integer
if [ -n "${THREADS}" ] && [ "${THREADS}" != "N/A" ] && [ "${THREADS}" -gt 0 ] 2>/dev/null; then
    THREADS=$((THREADS))
    echo "INFO: Using threads: ${THREADS}"
else
    THREADS=1
    echo "WARNING: Threads not available or invalid (THREADS=${THREADS}), defaulting to 1"
fi

# Validate and convert tasks per node to integer
if [ -n "${TASKS_PER_NODE}" ] && [ "${TASKS_PER_NODE}" != "N/A" ] && [ "${TASKS_PER_NODE}" -gt 0 ] 2>/dev/null; then
    TASKS_PER_NODE=$((TASKS_PER_NODE))
    echo "INFO: Using tasks per node: ${TASKS_PER_NODE}"
else
    TASKS_PER_NODE=0
    echo "WARNING: Tasks per node not available or invalid (TASKS_PER_NODE=${TASKS_PER_NODE})"
fi

echo "INFO: Starting performance monitoring for job $jobid with name $jobname"

# Create output directory
mkdir -p "${PERFORMANCE_DIR}"
cd "${PERFORMANCE_DIR}"

# Verify dependencies
PYTHON_SCRIPT="${SCRIPTDIR}/CPMIP/performance_metrics.py"
if [ ! -f "$PYTHON_SCRIPT" ]; then
    exit 1
fi

HPC_NAME=$(echo "${CURRENT_ARCH:-N/A}" | cut -d- -f1)

# Build complexity JSON based on model name
case "${MODEL_NAME^^}" in
ICON)
    # ICON uses ATMOSPHERE, OCEAN, LAND
    PERFORMANCE_COMPLEXITY_JSON=$(printf '{"ATMOSPHERE":"%s","OCEAN":"%s","LAND":"%s"}' \
        "${COMPLEXITY_ATMOSPHERE:-N/A}" \
        "${COMPLEXITY_OCEAN:-N/A}" \
        "${COMPLEXITY_LAND:-N/A}")
    ;;
IFS-NEMO | IFS-FESOM)
    # IFS-NEMO and IFS-FESOM use IFS, NEMO
    PERFORMANCE_COMPLEXITY_JSON=$(printf '{"IFS":"%s","NEMO":"%s"}' \
        "${COMPLEXITY_IFS:-N/A}" \
        "${COMPLEXITY_NEMO:-N/A}")
    ;;
*)
    # Unknown model: set all to N/A
    PERFORMANCE_COMPLEXITY_JSON='{"ATMOSPHERE":"N/A","OCEAN":"N/A","LAND":"N/A","IFS":"N/A","NEMO":"N/A"}'
    ;;
esac

# Compute CMIPS
PYTHON_ARGS=(
    --jobid "${jobid:-N/A}"
    --job_name "${jobname:-N/A}"
    --expid "${EXPID:-N/A}"
    --chunk "${CHUNK:-N/A}"
    --model "${MODEL_NAME:-N/A}"
    --resolution_km "${RESOLUTION:-N/A}"
    --grid_atm "${GRID_ATM:-N/A}" # Atmospheric grid
    --grid_oce "${GRID_OCE:-N/A}" # Ocean grid
    --complexity "${PERFORMANCE_COMPLEXITY_JSON}"
    --hpc "${HPC_NAME:-N/A}"
    --start_date_chunk "${CHUNK_START_DATE:-N/A}"
    --end_date_chunk "${CHUNK_SECOND_TO_LAST_DATE:-N/A}"
    --output_dir "$(pwd)"
    --fdb_home "${FDB_HOME:-N/A}"
    --class "${CLASS:-N/A}"
    --dataset "${DATASET:-N/A}"
    --activity "${ACTIVITY:-N/A}"
    --experiment "${EXPERIMENT:-N/A}"
    --generation "${GENERATION:-N/A}"
    --model_req "${MODEL_REQ:-N/A}"
    --realization "${REALIZATION:-N/A}"
    --expver "${EXPVER:-N/A}"
    --stream "${STREAM:-N/A}"
    --slurm_freq "${SLURM_FREQ:-60}"
    --monitor_metadata "${MONITOR_END_FILE}"
    --rundir_path "${rundir:-N/A}"
    --tasks_per_node "${TASKS_PER_NODE:-0}"
    --performance_resolution "${PERFORMANCE_RESOLUTION:-N/A}"
    --ifs_io_tasks "${IFS_IO_TASKS:-0}"
    --nemo_io_tasks "${NEMO_IO_TASKS:-0}"
    --ifs_io_nodes "${IFS_IO_NODES:-0}"
    --nemo_io_nodes "${NEMO_IO_NODES:-0}"
    --ifs_io_ppn "${IFS_IO_PPN:-0}"
    --nemo_io_ppn "${NEMO_IO_PPN:-0}"
    --fesom_io_tasks "${FESOM_IO_TASKS:-0}"
    --fesom_io_nodes "${FESOM_IO_NODES:-0}"
    --fesom_io_ppn "${FESOM_IO_PPN:-0}"
    --threads "${THREADS:-1}"
    --processor_unit "${PROCESSOR_UNIT:-cpu}"
)

python3 "$PYTHON_SCRIPT" "${PYTHON_ARGS[@]}"
