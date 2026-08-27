#!/bin/bash
#

set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${3:-%CURRENT_ARCH%}
CHUNKSIZE=${4:-%EXPERIMENT.CHUNKSIZE%}
CHUNKSIZEUNIT=${5:-%EXPERIMENT.CHUNKSIZEUNIT%}
MODEL_NAME=${6:-%MODEL.NAME%}
MODEL_ROOT_PATH=${7:-%MODEL.ROOT_PATH%}
ENVIRONMENT=${8:-%RUN.ENVIRONMENT%}
HPCARCH=${9:-%HPCARCH%}
MODEL_VERSION=${10:-%MODEL.VERSION%}
OCEAN_GRID=${11:-%MODEL.GRID_OCE%}
EXPID=${12:-%DEFAULT.EXPID%}
ATM_GRID=${13:-%MODEL.GRID_ATM%}
CHUNK=${14:-%CHUNK%}
NUMCHUNKS=${15:-%EXPERIMENT.NUMCHUNKS%}
TOTAL_RETRIALS=${16:-%CONFIG.RETRIALS%}
ICMCL=${17:-%MODEL.ICMCL_PATTERN%}
SIM_START_DATE=${18:-%SDATE%}
END_DATE=${19:-%CHUNK_END_DATE%}
CHUNK_END_IN_DAYS=${20:-%CHUNK_END_IN_DAYS%}
PREV=${21:-%PREV%}
RUN_DAYS=${22:-%RUN_DAYS%}
IFS_IO_TASKS=${23:-%CONFIGURATION.IFS.IO_TASKS%}
FESOM_IO_TASKS=${24:-%CONFIGURATION.FESOM.IO_TASKS%}
HPC_PROJECT=${25:-%CONFIGURATION.HPC_PROJECT_DIR%}
MULTIO_ATM_PLANS=${26:-%CONFIGURATION.IFS.MULTIO_PLANS%}
MULTIO_OCEAN_PLANS=${27:-%CONFIGURATION.NEMO.MULTIO_PLANS%}
PU=${28:-%RUN.PROCESSOR_UNIT%}
RAPS_USER_FLAGS=${29:-%CONFIGURATION.RAPS_USER_FLAGS%}
# Forcing options (replace the old --forcing-SSP with granular forcing flags)
RAPS_FORCING_AEROSOLS=${30:-%CONFIGURATION.RAPS_FORCING_AEROSOLS%}
RAPS_FORCING_AEROSOLS_VOLCANIC=${31:-%CONFIGURATION.RAPS_FORCING_AEROSOLS_VOLCANIC%}
RAPS_FORCING_GHG=${32:-%CONFIGURATION.RAPS_FORCING_GHG%}
RAPS_FORCING_OZONE=${33:-%CONFIGURATION.RAPS_FORCING_OZONE%}
DATA_PORTFOLIO=${34:-%CONFIGURATION.DATA_PORTFOLIO%}
RUN_TYPE=${35:-%RUN.TYPE%}
IFS_IO_PPN=${36:-%CONFIGURATION.IFS.IO_PPN%}
FESOM_IO_PPN=${37:-%CONFIGURATION.FESOM.IO_PPN%}
IFS_IO_NODES=${38:-%CONFIGURATION.IFS.IO_NODES%}
FESOM_IO_NODES=${39:-%CONFIGURATION.FESOM.IO_NODES%}
MEMBER=${40:-%MEMBER%}
MEMBER_LIST=${41:-%EXPERIMENT.MEMBERS%}
WORKFLOW=${42:-%RUN.WORKFLOW%}
SPLITS=${43:-%JOBS.DN.SPLITS%}
EXPVER=${44:-%REQUEST.EXPVER%}
CLASS=${45:-%REQUEST.CLASS%}
FDB_HOME=${46:-%REQUEST.FDB_HOME%}
DQC_PROFILE_PATH=${47:-%CONFIGURATION.DQC_PROFILE_PATH%}
EXPERIMENT=${48:-%REQUEST.EXPERIMENT%}
ACTIVITY=${49:-%REQUEST.ACTIVITY%}
GENERATION=${50:-%REQUEST.GENERATION%}
MODEL=${51:-%REQUEST.MODEL%}
LIBDIR=${52:-%CONFIGURATION.LIBDIR%}
SCRATCH_DIR=${53:-%CURRENT_SCRATCH_DIR%}
HPC_CONTAINER_DIR=${54:-%CURRENT_CONTAINER_DIR%}
GSV_VERSION=${55:-%GSV.VERSION%}
MODEL_PATH=${56:-%MODEL.PATH%}
MODEL_INPUTS=${57:-%MODEL.INPUTS%}
SCRIPTDIR=${58:-%CONFIGURATION.SCRIPTDIR%}
# Platform-dependent RAPS parameters (conf/model/ifs-fesom/ifs-fesom.yml)
RAPS_HOST_CPU=${59:-%CURRENT_RAPS_HOST_CPU%}
RAPS_HOST_GPU=${60:-%CURRENT_RAPS_HOST_GPU%}
RAPS_BIN_HPC_NAME=${61:-%CURRENT_RAPS_BIN_HPC_NAME%}
RAPS_COMPILER=${62:-%CURRENT_RAPS_COMPILER%}
RAPS_MPILIB=${63:-%CURRENT_RAPS_MPILIB%}
# Path to the modules profile (conf/platforms.yml)
MODULES_PROFILE_PATH=${64:-%CONFIGURATION.MODULES_PROFILE_PATH%}
MIR_CACHE_PATH=${65:-%MODEL.RAPS_MIR_CACHE_PATH%}
MIR_FESOM_CACHE_PATH=${66:-%MODEL.RAPS_MIR_FESOM_CACHE_PATH%}
# Extra bindings needed for the container in hpc-fdb
OPERATIONAL_PROJECT_SCRATCH=${67:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${68:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}
HPC_PROJECT_ROOT=${69:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${70:-%CURRENT_LOCAL_DIR%}
BUNDLE_BUILD_DIR=${71:-%MODEL.BUNDLE_BUILD_DIR%}
RAPS_BIN=${72:-%MODEL.RAPS.BIN%}
FDB_DIRS=${73:-%MODEL.FDB_DIRS%}
# Model RAPS flag groups (conf/model/ifs-fesom/ifs-fesom.yml)
GENERAL_FLAGS=${74:-%MODEL.RAPS.GENERAL_FLAGS%}
FESOM_FLAGS=${75:-%MODEL.RAPS.FESOM_FLAGS%}
RESTART_FLAGS=${76:-%MODEL.RAPS.RESTART_FLAGS%}
FDB_FLAGS=${77:-%MODEL.RAPS.FDB_FLAGS%}
IO_FLAGS=${78:-%MODEL.RAPS.IO_FLAGS%}
NAMELIST_FLAGS=${79:-%MODEL.RAPS.NAMELIST_FLAGS%}
# FESOM perturbation parameters
FESOM_PERTURB=${80:-%CONFIGURATION.FESOM_PERTURB%}
FESOM_PERTURBATION_SEED_BASE=${81:-%CONFIGURATION.FESOM_PERTURBATION_SEED_BASE%}
# Restart-related parameters (for restarted runs from previous experiments)
RESTART_FROM=${82:-%RUN.RESTART_FROM%}
RESTARTS_FROM_PATH=${83:-%MODEL.RESTARTS_FROM_PATH%}
RESTARTED_RUN=${84:-%RUN.RESTARTED_RUN%}
PRE_RESTART_DIR=${85:-%CONFIGURATION.PRE_RESTART_DIR%}
RESTART_DIR=${86:-%CONFIGURATION.RESTART_DIR%}
IFS_START_DATE=${87:-%CONFIGURATION.IFS.START_DATE%}
# IFS configuration parameters
input_expver=${88:-%CONFIGURATION.IFS.EXPVER%}
label=${89:-%CONFIGURATION.IFS.LABEL%}
gtype=${90:-%CONFIGURATION.IFS.GTYPE%}
resol=${91:-%CONFIGURATION.IFS.RESOL%}
levels=${92:-%CONFIGURATION.IFS.LEVELS%}
USE_LOCAL_TIME=${93:-%CONFIGURATION.IFS.USE_LOCAL_TIME%}
# Platform-specific performance flags (e.g. WAM flags for LUMI)
PERFORMANCE_PLATFORM_FLAGS=${94:-%CURRENT_PERFORMANCE_PLATFORM_FLAGS%}
RUNDIR_PATH=${95:-%CONFIGURATION.RUNDIR_PATH%}
AS_JOBNAME=${96:-%JOBNAME%}
# Performance-metrics metadata (written to the per-chunk env file for the
# MONITOR_RESOURCES / PERFORMANCE_METRICS jobs; see write_performance_env).
RESOLUTION=${97:-%MODEL.RESOLUTION%}
CHUNK_START_DATE=${98:-%CHUNK_START_DATE%}
CHUNK_SECOND_TO_LAST_DATE=${99:-%CHUNK_SECOND_TO_LAST_DATE%}
DATASET=${100:-%REQUEST.DATASET%}
STREAM=${101:-%REQUEST.STREAM%}
COMPLEXITY_IFS=${102:-%PERFORMANCE_METRICS.COMPLEXITY.IFS%}
COMPLEXITY_NEMO=${103:-%PERFORMANCE_METRICS.COMPLEXITY.NEMO%}
PERFORMANCE_METRICS_VERSION=${104:-%PERFORMANCE_METRICS.VERSION%}
PERFORMANCE_RESOLUTION=${105:-%PERFORMANCE_METRICS.RESOLUTION%}

# END_HEADER

ATM_MODEL=${MODEL_NAME%%-*}

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

# Source libraries
. "${LIBDIR}"/common/util.sh
. "${LIBDIR}"/common/utils/sim_utils.sh
. "${LIBDIR}"/"${HPC}"/config.sh

# Source the module profile if defined
if [ -n "${MODULES_PROFILE_PATH}" ]; then
    . "${MODULES_PROFILE_PATH}"
fi

# If IFS_START_DATE is not defined, use SIM_START_DATE
IFS_START_DATE=${IFS_START_DATE:-${SIM_START_DATE}}

export MODEL_VERSION
export ENVIRONMENT
export HPCARCH
export HPCROOTDIR
export PROJDEST
export USE_LOCAL_TIME

# Export MIR_CACHEs for RAPS if defined
if [[ -n "${MIR_CACHE_PATH}" && "${MIR_CACHE_PATH}" != "None" ]]; then
    export MIR_CACHE_PATH
fi
if [[ -n "${MIR_FESOM_CACHE_PATH}" && "${MIR_FESOM_CACHE_PATH}" != "None" ]]; then
    export MIR_FESOM_CACHE_PATH
fi

export MIR_MATRIX_LOADER=shmem
export MIR_CHECK_DUPLICATE_POINTS=0 # fesom interpolation matrices contain duplicate points due to the fesom grid holes

# Export RAPS environment variables (required by some RAPS installations)
# RAPS_ROOTDIR should point to the raps source directory (where multio_yaml exists)
export RAPS_ROOTDIR=${MODEL_PATH}/source/raps
export RAPS_BINDIR=${RAPS_BIN}
export RAPS_ETCDIR=${MODEL_PATH}/etc
export BUNDLE_BUILD_DIR
export PATH=${RAPS_BIN}:$PATH

#################################################
# FESOM Restart Management with 'current' symlink
# 1. Create chunk directory
# 2. Move fesom_raw_restart from previous chunk (or copy if retrial)
# 3. Update 'current' symlink to point to active chunk
# RAPS will link current/fesom_raw_restart to rundir
#################################################

mkdir -p "${PRE_RESTART_DIR}/${CHUNK}"
cd "${PRE_RESTART_DIR}/${CHUNK}"

# Backup IFS restart files for retrials (matching NEMO's approach)
files=("waminfo" "rcf")

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        if [ -f "${file}-backup" ]; then
            # Retrial: restore from backup
            mv "${file}-backup" "$file"
        fi
        cp "$file" "${file}-backup"
    fi
done

# Backup FESOM restart directory for retrials
# Guard: For chunk 1 of non-restarted runs.
# If it exists here, it's stale output from a previous run — remove it to ensure
# RAPS uses initial conditions mode (no np64.info → reads initial fesom.clock files).
# When RESTART_FROM is set, restarts were copied by INI and must be preserved.
if [[ "${CHUNK}" == "1" ]] && [ -d "fesom_raw_restart" ] && [[ -z "${RESTART_FROM:-}" ]]; then
    echo "WARNING: Removing stale fesom_raw_restart from chunk 1 (re-run detected)"
    rm -rf fesom_raw_restart fesom_raw_restart-backup
elif [ -d "fesom_raw_restart" ]; then
    if [ -d "fesom_raw_restart-backup" ]; then
        # Retrial: restore from backup
        rm -rf fesom_raw_restart
        cp -r "fesom_raw_restart-backup" fesom_raw_restart
    else
        cp -r fesom_raw_restart fesom_raw_restart-backup
    fi
fi

# Create /current/ symlink to point to the current chunk before running
cd ${PRE_RESTART_DIR}
ln -sfn ${CHUNK} current

OUTROOT=${RUNDIR_PATH}
mkdir -p "${OUTROOT}"

# For restarted runs, check if inipath exists (similar to IFS-NEMO approach)
# Note: FESOM shares inipath across members (forcing is read-only), unlike NEMO which uses per-member inipath
if [ -d ${HPCROOTDIR}/inipath/${SIM_START_DATE} ]; then
    export INPROOT=${HPCROOTDIR}/inipath/${SIM_START_DATE}
else
    export INPROOT=${MODEL_INPUTS}
fi
export OUTROOT=${OUTROOT}

export MULTIO_RAPS_PLANS_PATH=${RAPS_BIN}/../multio_yaml

export FDB_DIRS="${FDB_HOME}/native:${FDB_HOME}:${FDB_HOME}/latlon"

# lib/common/utils/sim_utils.sh (load_experiment_ifs) (auto generated comment)
load_experiment_"${ATM_MODEL}"

# lib/common/utils/sim_utils.sh (check_rundir_name) (auto generated comment)
check_rundir_name "$AS_JOBNAME"

# The resource monitor is an optional per-run job (toggled via
# CONFIGURATION.ADDITIONAL_JOBS). Export the toggle so the perf hooks in
# sim_utils.sh (write_performance_env, signal_performance_done) no-op when it is
# not scheduled for this run.
export MONITOR_RESOURCES_ENABLED="%CONFIGURATION.ADDITIONAL_JOBS.MONITOR_RESOURCES%"

# Resolved before write_performance_env so the performance records carry the same
# realization the model writes to the FDB
# lib/common/util.sh (get_member_number) (auto generated comment)
MEMBER_NUMBER=$(get_member_number "${MEMBER_LIST}" ${MEMBER})
REALIZATION="${MEMBER_NUMBER}"

# Publish the per-chunk performance env file early (rundir not known yet) so the
# MONITOR_RESOURCES job, triggered on SIM RUNNING, can attach to this job id.
# lib/common/utils/sim_utils.sh (write_performance_env) (auto generated comment)
write_performance_env

# Catch-all so the monitor stops cleanly even on an unexpected 'set -e' abort
# between here and the explicit success/failure signals below. We trap ERR, NOT
# EXIT: Autosubmit owns the EXIT trap (as_exit_handler in its header), which is
# what writes the _COMPLETED stat file. Trapping EXIT here replaces it, so every
# successful job would run fine yet be marked FAILED. ERR fires at the point of
# the failing command, before the shell exits, so our signal runs first and
# Autosubmit's EXIT handler still runs afterwards. signal_performance_done is
# idempotent, so this is a no-op once an explicit success/failure signal ran.
# lib/common/utils/sim_utils.sh (signal_performance_done) (auto generated comment)
trap 'signal_performance_done' ERR

############ RUN SIMULATION #########################

# Defines the host as RAPS_HOST_CPU or RAPS_HOST_GPU depending on the PU
# lib/common/utils/sim_utils.sh (get_host_for_raps) (auto generated comment)
host=$(get_host_for_raps "${PU}" "${RAPS_HOST_CPU}" "${RAPS_HOST_GPU}")
# Exports mpilib for RAPS
export mpilib=${RAPS_MPILIB}
cd ${RAPS_BIN}/SLURM/${RAPS_BIN_HPC_NAME}

# Create output directory for hres logs
hres_out_dir=${HPCROOTDIR}/hres_out
mkdir -p ${hres_out_dir}

# Build RAPS flags in organized groups (matching ifs-nemo pattern)
# GENERAL_FLAGS has incomplete --ifs-bundle-build-dir flag, complete it with BUNDLE_BUILD_DIR
# Need to insert the path RIGHT AFTER the flag, not at the end
GENERAL_FLAGS="${GENERAL_FLAGS/--ifs-bundle-build-dir /--ifs-bundle-build-dir ${BUNDLE_BUILD_DIR} }"

# Append output-portfolio flag to IO_FLAGS
IO_FLAGS="${IO_FLAGS} --output-portfolio ${DATA_PORTFOLIO}"

RAPS_FLAGS="$GENERAL_FLAGS $FESOM_FLAGS $RESTART_FLAGS $IO_FLAGS $NAMELIST_FLAGS"

# Add MultIO activity and experiment flags (required when using MultIO)
if [ -n "${ACTIVITY}" ] && [ -n "${EXPERIMENT}" ]; then
    RAPS_FLAGS="${RAPS_FLAGS} --multio-activity ${ACTIVITY} --multio-experiment ${EXPERIMENT}"
    echo "MultIO metadata set: activity=${ACTIVITY}, experiment=${EXPERIMENT}"
fi
# Add individual forcing flags
# Format: "VARIABLE_NAME|--raps-flag|Display label"
FORCING_LIST=(
    "RAPS_FORCING_AEROSOLS|--forcing-aerosols|Forcing aerosols"
    "RAPS_FORCING_AEROSOLS_VOLCANIC|--forcing-aerosols-volcanic|Forcing aerosols volcanic"
    "RAPS_FORCING_GHG|--forcing-ghg|Forcing GHG"
    "RAPS_FORCING_OZONE|--forcing-ozone|Forcing ozone"
)
for entry in "${FORCING_LIST[@]}"; do
    IFS='|' read -r var_name flag_name display_label <<<"$entry"
    value="${!var_name}"
    if [ -n "${value}" ] && [ "${value}" != "None" ]; then
        RAPS_FLAGS="${RAPS_FLAGS} ${flag_name} ${value}"
        echo "${display_label}: ${value}"
    fi
done

# Add FESOM perturbation flags if enabled
# Seed is calculated as: FESOM_PERTURBATION_SEED_BASE + MEMBER_NUMBER
# MEMBER_NUMBER follows the member name: fc0 -> 1 (50001), fc10 -> 11 (50011)
if [ "${FESOM_PERTURB,,}" == "true" ] && [ -n "${FESOM_PERTURBATION_SEED_BASE}" ]; then
    FESOM_PERTURBATION_SEED=$((FESOM_PERTURBATION_SEED_BASE + MEMBER_NUMBER))
    RAPS_FLAGS="${RAPS_FLAGS} --fesom-perturb --fesom-perturbation-seed ${FESOM_PERTURBATION_SEED}"
    echo "FESOM perturbation enabled with seed: ${FESOM_PERTURBATION_SEED} (base: ${FESOM_PERTURBATION_SEED_BASE}, member: ${MEMBER_NUMBER})"
fi

# Append platform-specific performance flags and user-defined flags at the end
RAPS_FLAGS="${RAPS_FLAGS} ${PERFORMANCE_PLATFORM_FLAGS} ${RAPS_USER_FLAGS}"

# FDB flags with realization number
flags_fdb="${FDB_FLAGS} --realization=${MEMBER_NUMBER}"

# Check for IFS and FESOM server resources
# sbeyer: currently if IO_NODES and IO_PPN is set this overwrites the tasks, maybe we should check that only one of them is set?
if [[ ${IFS_IO_TASKS} -ne 0 ]] && [[ ${FESOM_IO_TASKS} -ne 0 ]]; then
    io_flags="--io-tasks=${IFS_IO_TASKS} --fesom-multio-server-num=${FESOM_IO_TASKS}"
elif [[ ${IFS_IO_NODES} -ne 0 ]] && [[ ${FESOM_IO_NODES} -ne 0 ]]; then
    io_flags="--io-nodes=${IFS_IO_NODES} --io-ppn=${IFS_IO_PPN} --fesom-multio-server-nodes=${FESOM_IO_NODES} --fesom-multio-server-ppn=${FESOM_IO_PPN}"
else
    echo 'Error: No resources selected for IFS or FESOM IO servers. Add IFS_IO_NODES and FESOM_IO_NODES or IFS_IO_TASKS and FESOM_IO_TASKS variables.'
    exit 1
fi

export other
export flags_fdb
export io_flags

set +e
source ../../../.again
set -e

set -eux

# Use FESOM grid from config (MODEL.GRID_OCE) instead of computing from resolution
export FESOM_GRID="${OCEAN_GRID}"

# Set coupling frequency per resolution
# RAPS sets tstep to 3600 for TCo79; CORE2 ocean runs with 45min timestep
if [ "${resol}" == "79" ]; then
    export COUPFREQ=10800
fi
# tco319/tco399 use hourly coupling
if [ "${resol}" == "319" ] || [ "${resol}" == "399" ]; then
    export COUPFREQ=3600
fi

ifsMASTER=""

nproma=${nproma:-32}
depth=${depth:-$omp}
ht=${ht:-$(htset.pl "$SLURM_NTASKS_PER_NODE" "$SLURM_CPUS_PER_TASK")}

# Prepare hres output file for capture
outfile=${hres_out_dir}/${SLURM_JOB_NAME}_${SLURM_JOB_ID}_${retrial_number}_hres.log

echo "Model run starts. hres output will be stored in ${outfile}"

# Run hres with output capture for error handling
set +e
hres \
    -p "$mpi" -t "$omp" -h "$ht" \
    --ppn $SLURM_NTASKS_PER_NODE \
    -j "$jobid" -J "$AS_JOBNAME" \
    -d "$yyyymmddzz" -e "$input_expver" -L "$label" \
    -T "$gtype" -r "$resol" -l "$levels" -f "$fclen" \
    -x "$ifsMASTER" \
    -N "$nproma" \
    -H "$host" -n "$nodes" -C "$RAPS_COMPILER" ${RAPS_FLAGS} ${flags_fdb} ${io_flags} \
    >"$outfile" 2>&1

status=$?
set -e

if [ $status -ne 0 ]; then
    # lib/common/utils/sim_utils.sh (report_errors_in_raps_output) (auto generated comment)
    report_errors_in_raps_output "$outfile"
    # Tell the resource monitor this chunk failed so it stops cleanly instead of
    # running until its wallclock.
    # lib/common/utils/sim_utils.sh (signal_performance_done) (auto generated comment)
    signal_performance_done
    exit $status
else
    echo "Model run completed successfully."
fi

# Resolve the rundir RAPS just created and record it in the env file so
# PERFORMANCE_METRICS reads it directly instead of guessing the pattern (which
# previously failed for wrapped chunks — issue #1557).
RESOLVED_RUNDIR=$(find "${RUNDIR_PATH}" -type d -name "h*${AS_JOBNAME}-${SLURM_JOB_ID}" -print -quit 2>/dev/null)
# lib/common/utils/sim_utils.sh (write_performance_env) (auto generated comment)
write_performance_env "${RESOLVED_RUNDIR:-N/A}"

echo "Moving restart files to the next chunk folder"

# lib/common/utils/sim_utils.sh (restarts_moving) (auto generated comment)
restarts_moving

# Everything in the SIM template has now finished (model run, env file, restarts
# moved). Signal the resource monitor so it stops only at this point, having
# observed the whole chunk. Idempotent, and on this success path the ERR trap
# above never fires anyway.
# lib/common/utils/sim_utils.sh (signal_performance_done) (auto generated comment)
signal_performance_done
