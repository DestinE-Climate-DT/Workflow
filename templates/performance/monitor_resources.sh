#!/bin/bash

# HEADER
EXPID=${1:-%DEFAULT.EXPID%}
USER=${2:-%CURRENT_USER%}
HPCROOTDIR=${3:-%HPCROOTDIR%}
CHUNK=${4:-%CHUNK%}
WRAPPER=${5:-%WRAPPERS.WRAPPER.JOBS_IN_WRAPPER%}
SIM_START_DATE=${6:-%SDATE%}
MEMBER=${7:-%MEMBER%}
SCRIPTDIR=${8:-%CONFIGURATION.SCRIPTDIR%}
HPC_CONTAINER_DIR=${9:-%CURRENT_CONTAINER_DIR%}
PERFORMANCE_METRICS_VERSION=${10:-%PERFORMANCE_METRICS.VERSION%}
SAMPLING_FREQUENCY=${11:-%JOBS.MONITOR_RESOURCES.SAMPLING_FREQ%}
SLURM_FREQUENCY=${12:-%JOBS.MONITOR_RESOURCES.SLURM_FREQ%}
LIBDIR=${13:-%CONFIGURATION.LIBDIR%}
CURRENT_ARCH=${14:-%CURRENT_ARCH%}
RUNDIR_PATH=${15:-%CONFIGURATION.RUNDIR_PATH%}
SCRATCH_DIR=${16:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${17:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${18:-%CURRENT_LOCAL_DIR%}
# END_HEADER

set -xuve

# Build job name
if [ -n "${WRAPPER:-}" ]; then
    jobname="${EXPID}_ASThread"
else
    jobname="${EXPID}_${SIM_START_DATE}_${MEMBER}_${CHUNK}_SIM"
fi

jobid=$(
    squeue -h -u "$USER" -n "$jobname" -o "%i" |
        sort -n | tail -1
)

if [ -n "$jobid" ]; then
    echo "INFO: Starting performance monitoring for job $jobid with name $jobname"
else
    echo "ERROR: No job found with name $jobname for user $USER"
    exit 1
fi

# Use HPCROOTDIR for performance output instead of searching for rundir
PERFORMANCE_DIR="${HPCROOTDIR}/performance/monitor/${jobname}-${jobid}"
echo "INFO: Using performance directory: ${PERFORMANCE_DIR}"

# Create output directory in HPCROOTDIR
mkdir -p "${PERFORMANCE_DIR}"
cd "${PERFORMANCE_DIR}"

# Verify Python script exists
PYTHON_SCRIPT="${SCRIPTDIR}/CPMIP/resource_monitor.py"
if [ ! -f "$PYTHON_SCRIPT" ]; then
    exit 1
fi

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh
# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity
# lib/LUMI/config.sh (load_additional_modules) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_additional_modules) (auto generated comment)
load_additional_modules

# Validate container path variables
if [ -z "${HPC_CONTAINER_DIR}" ]; then
    echo "ERROR: HPC_CONTAINER_DIR is not set. Check configuration."
    exit 1
fi

if [ -z "${PERFORMANCE_METRICS_VERSION}" ]; then
    echo "ERROR: PERFORMANCE_METRICS_VERSION is not set. Check configuration."
    exit 1
fi

# Build full container path
CONTAINER_SIF="${HPC_CONTAINER_DIR}/performance_metrics_${PERFORMANCE_METRICS_VERSION}.sif"

# Verify container file exists
if [ ! -f "$CONTAINER_SIF" ]; then
    echo "ERROR: Container file does not exist: $CONTAINER_SIF"
    echo "Available files in ${HPC_CONTAINER_DIR}:"
    ls -lh "${HPC_CONTAINER_DIR}/"*.sif 2>/dev/null || echo "  No .sif files found"
    exit 1
fi

echo "INFO: Using container: $CONTAINER_SIF"

# Execute the monitoring script directly on the host as a Python module
# This works because:
# 1. SLURM commands (scontrol, sstat, squeue) run natively on the host (no container needed)
# 2. pidstat is executed via 'srun --overlap + singularity' on job nodes (container ensures pidstat availability)
# The container path and version are passed as arguments for remote pidstat execution
# Use /usr/local/bin/pidstat to match the container's installation path (see Singularity def file)
# Run as module (-m) from the project root to enable relative imports

cd "${SCRIPTDIR}/.." || exit 1
python3 -m runscripts.CPMIP.resource_monitor \
    --jobid "$jobid" \
    --frequency "$SAMPLING_FREQUENCY" \
    --slurm_frequency "$SLURM_FREQUENCY" \
    --output-dir "${PERFORMANCE_DIR}" \
    --pidstat-path "/usr/local/bin/pidstat" \
    --container-sif "$CONTAINER_SIF"
