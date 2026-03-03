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
RAPS_FORCING_SSP=${30:-%CONFIGURATION.RAPS_FORCING_SSP%}
DATA_PORTFOLIO=${31:-%CONFIGURATION.DATA_PORTFOLIO%}
RUN_TYPE=${32:-%RUN.TYPE%}
IFS_IO_PPN=${33:-%CONFIGURATION.IFS.IO_PPN%}
FESOM_IO_PPN=${34:-%CONFIGURATION.FESOM.IO_PPN%}
IFS_IO_NODES=${35:-%CONFIGURATION.IFS.IO_NODES%}
FESOM_IO_NODES=${36:-%CONFIGURATION.FESOM.IO_NODES%}
MEMBER=${37:-%MEMBER%}
MEMBER_LIST=${38:-%EXPERIMENT.MEMBERS%}
WORKFLOW=${39:-%RUN.WORKFLOW%}
SPLITS=${40:-%JOBS.DN.SPLITS%}
EXPVER=${41:-%REQUEST.EXPVER%}
CLASS=${42:-%REQUEST.CLASS%}
FDB_HOME=${43:-%REQUEST.FDB_HOME%}
DQC_PROFILE_PATH=${44:-%CONFIGURATION.DQC_PROFILE_PATH%}
EXPERIMENT=${45:-%REQUEST.EXPERIMENT%}
ACTIVITY=${46:-%REQUEST.ACTIVITY%}
GENERATION=${47:-%REQUEST.GENERATION%}
MODEL=${48:-%REQUEST.MODEL%}
LIBDIR=${49:-%CONFIGURATION.LIBDIR%}
SCRATCH_DIR=${50:-%CURRENT_SCRATCH_DIR%}
HPC_CONTAINER_DIR=${51:-%CURRENT_CONTAINER_DIR%}
GSV_VERSION=${52:-%GSV.VERSION%}
MODEL_PATH=${53:-%MODEL.PATH%}
MODEL_INPUTS=${54:-%MODEL.INPUTS%}
SCRIPTDIR=${55:-%CONFIGURATION.SCRIPTDIR%}
# Platform-dependent RAPS parameters (conf/model/ifs-fesom/ifs-fesom.yml)
RAPS_HOST_CPU=${56:-%CURRENT_RAPS_HOST_CPU%}
RAPS_HOST_GPU=${57:-%CURRENT_RAPS_HOST_GPU%}
RAPS_BIN_HPC_NAME=${58:-%CURRENT_RAPS_BIN_HPC_NAME%}
RAPS_COMPILER=${59:-%CURRENT_RAPS_COMPILER%}
RAPS_MPILIB=${60:-%CURRENT_RAPS_MPILIB%}
# Path to the modules profile (conf/platforms.yml)
MODULES_PROFILE_PATH=${61:-%CONFIGURATION.MODULES_PROFILE_PATH%}
MIR_CACHE_PATH=${62:-%MODEL.RAPS_MIR_CACHE_PATH%}
MIR_FESOM_CACHE_PATH=${63:-%MODEL.RAPS_MIR_FESOM_CACHE_PATH%}
# Extra bindings needed for the container in hpc-fdb
OPERATIONAL_PROJECT_SCRATCH=${64:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${65:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}
HPC_PROJECT_ROOT=${66:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${67:-%CURRENT_LOCAL_DIR%}
BUNDLE_BUILD_DIR=${68:-%MODEL.BUNDLE_BUILD_DIR%}
RAPS_BIN=${69:-%MODEL.RAPS.BIN%}
FDB_DIRS=${70:-%MODEL.FDB_DIRS%}
# Model RAPS flag groups (conf/model/ifs-fesom/ifs-fesom.yml)
GENERAL_FLAGS=${71:-%MODEL.RAPS.GENERAL_FLAGS%}
FESOM_FLAGS=${72:-%MODEL.RAPS.FESOM_FLAGS%}
RESTART_FLAGS=${73:-%MODEL.RAPS.RESTART_FLAGS%}
FDB_FLAGS=${74:-%MODEL.RAPS.FDB_FLAGS%}
IO_FLAGS=${75:-%MODEL.RAPS.IO_FLAGS%}
NAMELIST_FLAGS=${76:-%MODEL.RAPS.NAMELIST_FLAGS%}
# FESOM perturbation parameters
FESOM_PERTURB=${77:-%CONFIGURATION.FESOM_PERTURB%}
FESOM_PERTURBATION_SEED_BASE=${78:-%CONFIGURATION.FESOM_PERTURBATION_SEED_BASE%}
# Restart-related parameters (for restarted runs from previous experiments)
RESTART_FROM=${79:-%RUN.RESTART_FROM%}
RESTARTS_FROM_PATH=${80:-%MODEL.RESTARTS_FROM_PATH%}
RESTARTED_RUN=${81:-%RUN.RESTARTED_RUN%}
PRE_RESTART_DIR=${82:-%CONFIGURATION.PRE_RESTART_DIR%}
RESTART_DIR=${83:-%CONFIGURATION.RESTART_DIR%}
IFS_START_DATE=${84:-%CONFIGURATION.IFS.START_DATE%}
# IFS configuration parameters
input_expver=${85:-%CONFIGURATION.IFS.EXPVER%}
label=${86:-%CONFIGURATION.IFS.LABEL%}
gtype=${87:-%CONFIGURATION.IFS.GTYPE%}
resol=${88:-%CONFIGURATION.IFS.RESOL%}
levels=${89:-%CONFIGURATION.IFS.LEVELS%}

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

# Backup FESOM restart directory for retrials (matching NEMO's approach for nemorcf)
if [ -d "fesom_raw_restart" ]; then
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

OUTROOT=${HPCROOTDIR}/rundir

# For restarted runs, check if inipath exists (similar to IFS-NEMO approach)
# Note: FESOM shares inipath across members (forcing is read-only), unlike NEMO which uses per-member inipath
if [ -d ${HPCROOTDIR}/inipath/${SIM_START_DATE} ]; then
    export INPROOT=${HPCROOTDIR}/inipath/${SIM_START_DATE}
else
    export INPROOT=${MODEL_INPUTS}
fi
export OUTROOT=${OUTROOT}

export MULTIO_RAPS_PLANS_PATH=${RAPS_BIN}/../multio_yaml

if [ ! -z $MULTIO_ATM_PLANS ]; then
    export MULTIO_IFSIO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ifsio-config-${MULTIO_ATM_PLANS}.yaml
else
    export MULTIO_IFSIO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ifsio-config.yaml
fi

export FDB_DIRS="${FDB_HOME}/native:${FDB_HOME}:${FDB_HOME}/latlon"

# lib/common/utils/sim_utils.sh (load_experiment_ifs) (auto generated comment)
load_experiment_"${ATM_MODEL}"

# lib/common/utils/sim_utils.sh (check_rundir_name) (auto generated comment)
check_rundir_name

############ RUN SIMULATION #########################

# Defines the host as RAPS_HOST_CPU or RAPS_HOST_GPU depending on the PU
# lib/common/utils/sim_utils.sh (get_host_for_raps) (auto generated comment)
host=$(get_host_for_raps "${PU}" "${RAPS_HOST_CPU}" "${RAPS_HOST_GPU}")
# Exports mpilib for RAPS
export mpilib=${RAPS_MPILIB}
cd ${RAPS_BIN}/SLURM/${RAPS_BIN_HPC_NAME}

# lib/common/util.sh (get_member_number) (auto generated comment)
MEMBER_NUMBER=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

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

# Add FORCING_FLAGS only if RAPS_FORCING_SSP is defined (for storylines configs)
if [ -n "${RAPS_FORCING_SSP}" ] && [ "${RAPS_FORCING_SSP}" != "None" ]; then
    RAPS_FLAGS="${RAPS_FLAGS} --forcing-SSP ${RAPS_FORCING_SSP}"
    echo "FESOM forcing SSP enabled: ${RAPS_FORCING_SSP}"
fi

# Add FESOM perturbation flags if enabled
# Seed is calculated as: FESOM_PERTURBATION_SEED_BASE + MEMBER_NUMBER
# For fc0 (MEMBER_NUMBER=1): 50000 + 1 = 50001
# For fc1 (MEMBER_NUMBER=2): 50000 + 2 = 50002, etc.
if [ "${FESOM_PERTURB,,}" == "true" ] && [ -n "${FESOM_PERTURBATION_SEED_BASE}" ]; then
    FESOM_PERTURBATION_SEED=$((FESOM_PERTURBATION_SEED_BASE + MEMBER_NUMBER))
    RAPS_FLAGS="${RAPS_FLAGS} --fesom-perturb --fesom-perturbation-seed ${FESOM_PERTURBATION_SEED}"
    echo "FESOM perturbation enabled with seed: ${FESOM_PERTURBATION_SEED} (base: ${FESOM_PERTURBATION_SEED_BASE}, member: ${MEMBER_NUMBER})"
fi

# Append user-defined flags at the end
RAPS_FLAGS="${RAPS_FLAGS} ${RAPS_USER_FLAGS}"

# FDB flags with realization number
flags_fdb="${FDB_FLAGS} --realization=${MEMBER_NUMBER}"

# Check for IFS and FESOM server resources
# sbeyer: currently if IO_NODES and IO_PPN is set this overwrites the tasks, maybe we should check that only one of them is set?
if [[ ${IFS_IO_TASKS} -ne 0 ]] && [[ ${FESOM_IO_TASKS} -ne 0 ]]; then
    io_flags="--io-tasks=${IFS_IO_TASKS} --fesom-multio-server-num=${FESOM_IO_TASKS}"
elif [[ ${IFS_IO_NODES} -ne 0 ]] && [[ ${FESOM_IO_NODES} -ne 0 ]]; then
    io_flags="--ionodes=${IFS_IO_NODES} --io-ppn=${IFS_IO_PPN} --fesom-multio-server-nodes=${FESOM_IO_NODES} --fesom-multio-server-ppn=${FESOM_IO_PPN}"
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

if [ "${resol}" == "79" ]; then
    export COUPFREQ=10800 # 3hourly coupling (RAPS sets tstep to 3600 for TCo79; CORE2 oce runs with 45min timestep)
    export FESOM_GRID="CORE2"
fi
if [ "${resol}" == "1279" ]; then
    export FESOM_GRID="NG5"
fi
if [ "${resol}" == "2559" ]; then
    export FESOM_GRID="NG5"
fi
if [ "${resol}" == "399" ]; then
    export FESOM_GRID="D3"
fi

ifsMASTER=""

nproma=${nproma:-32}
depth=${depth:-$omp}
ht=${ht:-$(htset.pl "$SLURM_NTASKS_PER_NODE" "$SLURM_CPUS_PER_TASK")}

echo "Model run starts"

hres \
    -p "$mpi" -t "$omp" -h "$ht" \
    --ppn $SLURM_NTASKS_PER_NODE \
    -j "$jobid" -J "$jobname" \
    -d "$yyyymmddzz" -e "$input_expver" -L "$label" \
    -T "$gtype" -r "$resol" -l "$levels" -f "$fclen" \
    -x "$ifsMASTER" \
    -N "$nproma" \
    -H "$host" -n "$nodes" -C "$RAPS_COMPILER" ${RAPS_FLAGS} ${flags_fdb} ${io_flags}

echo "The model ran successfully."
echo "Moving restart files to the next chunk folder"

# lib/common/utils/sim_utils.sh (restarts_moving) (auto generated comment)
restarts_moving
