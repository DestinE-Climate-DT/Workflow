#!/bin/bash

set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${3:-%CURRENT_ARCH%}
CHUNKSIZE=${4:-%EXPERIMENT.CHUNKSIZE%}
CHUNKSIZEUNIT=${5:-%EXPERIMENT.CHUNKSIZEUNIT%}
MODEL_NAME=${6:-%MODEL.NAME%}
ENVIRONMENT=${7:-%RUN.ENVIRONMENT%}
HPCARCH=${8:-%HPCARCH%}
MODEL_VERSION=${9:-%MODEL.VERSION%}
OCEAN_GRID=${10:-%MODEL.GRID_OCE%}
EXPID=${11:-%DEFAULT.EXPID%}
ATM_GRID=${12:-%MODEL.GRID_ATM%}
CHUNK=${13:-%CHUNK%}
TOTAL_RETRIALS=${14:-%CONFIG.RETRIALS%}
CHUNK_START_DATE=${15:-%CHUNK_START_DATE%}
END_DATE=${16:-%CHUNK_END_DATE%}
CHUNK_END_IN_DAYS=${17:-%CHUNK_END_IN_DAYS%}
PREV=${18:-%PREV%}
RUN_DAYS=${19:-%RUN_DAYS%}
IFS_IO_TASKS=${20:-%CONFIGURATION.IFS.IO_TASKS%}
NEMO_IO_TASKS=${21:-%CONFIGURATION.NEMO.IO_TASKS%}
HPC_PROJECT=${22:-%CONFIGURATION.HPC_PROJECT_DIR%}
MULTIO_ATM_PLANS=${23:-%CONFIGURATION.IFS.MULTIO_PLANS%}
MULTIO_OCEAN_PLANS=${24:-%CONFIGURATION.NEMO.MULTIO_PLANS%}
PU=${25:-%RUN.PROCESSOR_UNIT%}
RAPS_USER_FLAGS=${26:-%CONFIGURATION.RAPS_USER_FLAGS%}
IFS_IO_PPN=${27:-%CONFIGURATION.IFS.IO_PPN%}
NEMO_IO_PPN=${28:-%CONFIGURATION.NEMO.IO_PPN%}
IFS_IO_NODES=${29:-%CONFIGURATION.IFS.IO_NODES%}
NEMO_IO_NODES=${30:-%CONFIGURATION.NEMO.IO_NODES%}
MEMBER=${31:-%MEMBER%}
MEMBER_LIST=${32:-%EXPERIMENT.MEMBERS%}
EXPVER=${33:-%REQUEST.EXPVER%}
IO_ON=${34:-%CONFIGURATION.IO_ON%} # True or False
LIBDIR=${35:-%CONFIGURATION.LIBDIR%}
SCRATCH_DIR=${36:-%CURRENT_SCRATCH_DIR%}
HPC_CONTAINER_DIR=${37:-%CURRENT_CONTAINER_DIR%}
GSV_VERSION=${38:-%GSV.VERSION%}
MODEL_INPUTS=${39:-%MODEL.INPUTS%}
SCRIPTDIR=${40:-%CONFIGURATION.SCRIPTDIR%}
# Platform-dependent RAPS parameters (conf/model/ifs-nemo/ifs-nemo.yml)
RAPS_HOST_CPU=${41:-%CURRENT_RAPS_HOST_CPU%}
RAPS_HOST_GPU=${42:-%CURRENT_RAPS_HOST_GPU%}
RAPS_BIN_HPC_NAME=${43:-%CURRENT_RAPS_BIN_HPC_NAME%}
RAPS_COMPILER=${44:-%CURRENT_RAPS_COMPILER%}
RAPS_MPILIB=${45:-%CURRENT_RAPS_MPILIB%}
# Path to the modules profile (conf/platforms.yml)
MODULES_PROFILE_PATH=${46:-%CONFIGURATION.MODULES_PROFILE_PATH%}
# Extra bindings needed for the container in hpc-fdb
OPERATIONAL_PROJECT_SCRATCH=${47:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${48:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}
HPC_PROJECT_ROOT=${49:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${50:-%CURRENT_LOCAL_DIR%}
SIM_START_DATE=${51:-%SDATE%}
RUNDIR_PATH=${52:-%CONFIGURATION.RUNDIR_PATH%}
GENERAL_FLAGS=${53:-%MODEL.RAPS.GENERAL_FLAGS%}
NEMO_FLAGS=${54:-%MODEL.RAPS.NEMO_FLAGS%}
RESTART_FLAGS=${55:-%MODEL.RAPS.RESTART_FLAGS%}
FDB_FLAGS=${56:-%MODEL.RAPS.FDB_FLAGS%}
IO_FLAGS=${57:-%MODEL.RAPS.IO_FLAGS%}
SCI_FLAGS=${58:-%MODEL.RAPS.SCI_FLAGS%}
PERFORMANCE_GEN_FLAGS=${59:-%MODEL.RAPS.PERFORMANCE_GEN_FLAGS%}
PERFORMANCE_PLATFORM_FLAGS=${60:-%CURRENT_PERFORMANCE_PLATFORM_FLAGS%}
USER_RESOL_SCI_FLAGS=${61:-%MODEL.RAPS.USER_RESOL_SCI_FLAGS%}
USER_RESOL_PERF_FLAGS=${62:-%MODEL.RAPS.USER_RESOL_PERF_FLAGS%}
USER_SIM_SCI_FLAGS=${63:-%MODEL.RAPS.USER_SIM_SCI_FLAGS%}

input_expver=${64:-%CONFIGURATION.IFS.EXPVER%}
label=${65:-%CONFIGURATION.IFS.LABEL%}
gtype=${66:-%CONFIGURATION.IFS.GTYPE%}
resol=${67:-%CONFIGURATION.IFS.RESOL%}
levels=${68:-%CONFIGURATION.IFS.LEVELS%}
IFS_START_DATE=${69:-%CONFIGURATION.IFS.START_DATE%}
USE_LOCAL_TIME=${70:-%CONFIGURATION.IFS.USE_LOCAL_TIME%}

RAPS_BIN=${71:-%MODEL.RAPS_BIN%}
BUNDLE_BUILD_DIR=${72:-%MODEL.BUNDLE_BUILD_DIR%}
PRE_RESTART_DIR=${73:-%CONFIGURATION.PRE_RESTART_DIR%}
RESTART_DIR=${74:-%CONFIGURATION.RESTART_DIR%}
WEIGHTS_DIR=${75:-%MODEL.WEIGHTS_DIR%}

VARS_TO_EXPORT=${76:-%CONFIGURATION.VARS_TO_EXPORT%}
AS_JOBNAME=${77:-%JOBNAME%}
# Performance-metrics metadata (written to the per-chunk env file for the
# MONITOR_RESOURCES / PERFORMANCE_METRICS jobs; see write_performance_env).
RESOLUTION=${78:-%MODEL.RESOLUTION%}
CHUNK_SECOND_TO_LAST_DATE=${79:-%CHUNK_SECOND_TO_LAST_DATE%}
FDB_HOME=${80:-%REQUEST.FDB_HOME%}
CLASS=${81:-%REQUEST.CLASS%}
DATASET=${82:-%REQUEST.DATASET%}
ACTIVITY=${83:-%REQUEST.ACTIVITY%}
EXPERIMENT=${84:-%REQUEST.EXPERIMENT%}
GENERATION=${85:-%REQUEST.GENERATION%}
MODEL_REQ=${86:-%REQUEST.MODEL%}
STREAM=${87:-%REQUEST.STREAM%}
COMPLEXITY_IFS=${88:-%PERFORMANCE_METRICS.COMPLEXITY.IFS%}
COMPLEXITY_NEMO=${89:-%PERFORMANCE_METRICS.COMPLEXITY.NEMO%}
PERFORMANCE_METRICS_VERSION=${90:-%PERFORMANCE_METRICS.VERSION%}
PERFORMANCE_RESOLUTION=${91:-%PERFORMANCE_METRICS.RESOLUTION%}
# END_HEADER

set -xuve

NEMO_IO_PPN=${NEMO_IO_PPN:-0}
IFS_IO_PPN=${IFS_IO_PPN:-0}

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

# Directory definition

export MIR_MATRIX_LOADER=shmem
export MULTIO_CLIENT_MPI_BUFFER_SIZE=131072
export BUNDLE_BUILD_DIR
export PATH=${RAPS_BIN}:$PATH

export OUTROOT=${RUNDIR_PATH}
export USE_LOCAL_TIME

hres_out_dir=${HPCROOTDIR}/hres_out
mkdir -p ${hres_out_dir}

mkdir -p "${PRE_RESTART_DIR}/${CHUNK}"
cd ${PRE_RESTART_DIR}
rm -f current
ln -s "${CHUNK}" current
cd current

files=("waminfo" "rcf" "nemorcf" "nemorcf.${CHUNK_START_DATE}_000000")

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        if [ -f "${file}-backup" ]; then
            # Means that is a retrial!
            cp "${file}-backup" "$file"
        fi
        cp "$file" "${file}-backup"
    fi
done

# TODO REVISE THIS
if [ -d ${HPCROOTDIR}/inipath/${SIM_START_DATE}/${MEMBER} ]; then
    export INPROOT=${HPCROOTDIR}/inipath/${SIM_START_DATE}/${MEMBER}
else
    export INPROOT=${MODEL_INPUTS}
fi

export MULTIO_RAPS_PLANS_PATH=${RAPS_BIN}/../multio_yaml

export MULTIO_IFSIO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ifsio-config${MULTIO_ATM_PLANS}.yaml
export MULTIO_NEMO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-nemo${MULTIO_OCEAN_PLANS}.yaml

# Defines the host as RAPS_HOST_CPU or RAPS_HOST_GPU depending on the PU
# lib/common/utils/sim_utils.sh (get_host_for_raps) (auto generated comment)
host=$(get_host_for_raps "${PU}" "${RAPS_HOST_CPU}" "${RAPS_HOST_GPU}")
# Exports mpilib for RAPS
export mpilib=${RAPS_MPILIB}

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
# (incl. one inside run_experiment_ifs) before an explicit signal runs. We trap
# ERR, NOT EXIT: Autosubmit owns the EXIT trap (as_exit_handler in its header)
# that writes the _COMPLETED stat file, so trapping EXIT here would replace it and
# make every successful job be marked FAILED. ERR fires at the failing command,
# before the shell exits, so our signal runs first and Autosubmit's EXIT handler
# still runs afterwards. signal_performance_done is idempotent, so this is a no-op
# once an explicit success/failure signal has already fired.
# lib/common/utils/sim_utils.sh (signal_performance_done) (auto generated comment)
trap 'signal_performance_done' ERR

export LD_LIBRARY_PATH=$BUNDLE_BUILD_DIR/ifs_sp:$LD_LIBRARY_PATH

RAPS_FLAGS="$GENERAL_FLAGS $NEMO_FLAGS $RESTART_FLAGS $SCI_FLAGS $PERFORMANCE_GEN_FLAGS $PERFORMANCE_PLATFORM_FLAGS $RAPS_USER_FLAGS $USER_RESOL_SCI_FLAGS $USER_RESOL_PERF_FLAGS $USER_SIM_SCI_FLAGS"
RAPS_IO_FLAGS=" $FDB_FLAGS $IO_FLAGS --realization=${MEMBER_NUMBER}"

# lib/common/utils/sim_utils.sh (export_vars) (auto generated comment)
export_vars

mkdir -p "${WEIGHTS_DIR}"
run_experiment_"${ATM_MODEL}" "$RAPS_FLAGS" "$RAPS_IO_FLAGS" "$hres_out_dir" "$AS_JOBNAME"

echo "The model ran successfully."

# Resolve the rundir RAPS just created and record it in the env file so
# PERFORMANCE_METRICS reads it directly instead of guessing the pattern (which
# previously failed for wrapped chunks — issue #1557).
RESOLVED_RUNDIR=$(find "${RUNDIR_PATH}" -type d -name "h*${AS_JOBNAME}-${SLURM_JOB_ID}" -print -quit 2>/dev/null)
# lib/common/utils/sim_utils.sh (write_performance_env) (auto generated comment)
write_performance_env "${RESOLVED_RUNDIR:-N/A}"

echo "Moving the restart files to the next chunk folder to use them in the following chunk"

# lib/common/utils/sim_utils.sh (restarts_moving) (auto generated comment)
restarts_moving

# Everything in the SIM template has now finished (model run, env file, restarts
# moved). Signal the resource monitor so it stops only at this point, having
# observed the whole chunk. Idempotent, and on this success path the ERR trap
# above never fires anyway.
# lib/common/utils/sim_utils.sh (signal_performance_done) (auto generated comment)
signal_performance_done
