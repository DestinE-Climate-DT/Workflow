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
TOTAL_RETRIALS=${15:-%CONFIG.RETRIALS%}
ICMCL=${16:-%MODEL.ICMCL_PATTERN%}
SIM_START_DATE=${17:-%SDATE%}
END_DATE=${18:-%CHUNK_END_DATE%}
END_IN_DAYS=${19:-%CHUNK_END_IN_DAYS%}
PREV=${20:-%PREV%}
RUN_DAYS=${21:-%RUN_DAYS%}
IFS_IO_TASKS=${22:-%CONFIGURATION.IFS.IO_TASKS%}
FESOM_IO_TASKS=${23:-%CONFIGURATION.FESOM.IO_TASKS%}
HPC_PROJECT=${24:-%CONFIGURATION.HPC_PROJECT_DIR%}
MULTIO_ATM_PLANS=${25:-%CONFIGURATION.IFS.MULTIO_PLANS%}
MULTIO_OCEAN_PLANS=${26:-%CONFIGURATION.NEMO.MULTIO_PLANS%}
PU=${27:-%RUN.PROCESSOR_UNIT%}
RAPS_USER_FLAGS=${28:-%CONFIGURATION.RAPS_USER_FLAGS%}
RAPS_FORCING_SSP=${29:-%CONFIGURATION.RAPS_FORCING_SSP%}
RUN_TYPE=${30:-%RUN.TYPE%}
IFS_IO_PPN=${31:-%CONFIGURATION.IFS.IO_PPN%}
FESOM_IO_PPN=${32:-%CONFIGURATION.FESOM.IO_PPN%}
IFS_IO_NODES=${33:-%CONFIGURATION.IFS.IO_NODES%}
FESOM_IO_NODES=${34:-%CONFIGURATION.FESOM.IO_NODES%}
MEMBER=${35:-%MEMBER%}
MEMBER_LIST=${36:-%EXPERIMENT.MEMBERS%}
WORKFLOW=${37:-%RUN.WORKFLOW%}
SPLITS=${38:-%JOBS.DN.SPLITS%}
EXPVER=${39:-%REQUEST.EXPVER%}
CLASS=${40:-%REQUEST.CLASS%}
FDB_HOME=${41:-%REQUEST.FDB_HOME%}
DQC_PROFILE_PATH=${42:-%CONFIGURATION.DQC_PROFILE_PATH%}
EXPERIMENT=${43:-%REQUEST.EXPERIMENT%}
ACTIVITY=${44:-%REQUEST.ACTIVITY%}
GENERATION=${45:-%REQUEST.GENERATION%}
MODEL=${46:-%REQUEST.MODEL%}
LIBDIR=${47:-%CONFIGURATION.LIBDIR%}
SCRATCH_DIR=${48:-%CURRENT_SCRATCH_DIR%}
HPC_CONTAINER_DIR=${49:-%CONFIGURATION.CONTAINER_DIR%}
GSV_VERSION=${50:-%GSV.VERSION%}
MODEL_PATH=${51:-%MODEL.PATH%}
MODEL_INPUTS=${52:-%MODEL.INPUTS%}
SCRIPTDIR=${53:-%CONFIGURATION.SCRIPTDIR%}
# Platform-dependent RAPS parameters (conf/model/ifs-fesom/ifs-fesom.yml)
RAPS_HOST_CPU=${54:-%CURRENT_RAPS_HOST_CPU%}
RAPS_HOST_GPU=${55:-%CURRENT_RAPS_HOST_GPU%}
RAPS_BIN_HPC_NAME=${56:-%CURRENT_RAPS_BIN_HPC_NAME%}
RAPS_COMPILER=${57:-%CURRENT_RAPS_COMPILER%}
RAPS_MPILIB=${58:-%CURRENT_RAPS_MPILIB%}
# Path to the modules profile (conf/platforms.yml)
MODULES_PROFILE_PATH=${59:-%CONFIGURATION.MODULES_PROFILE_PATH%}
MIR_CACHE_PATH=${60:-%MODEL.RAPS_MIR_CACHE_PATH%}
MIR_FESOM_CACHE_PATH=${61:-%MODEL.RAPS_MIR_FESOM_CACHE_PATH%}
# Extra bindings needed for the container in hpc-fdb
OPERATIONAL_PROJECT_SCRATCH=${62:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${63:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}
HPC_PROJECT_ROOT=${64:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${65:-%CURRENT_LOCAL_DIR%}
BUNDLE_BUILD_DIR=${66:-%MODEL.BUNDLE_BUILD_DIR%}
FDB_DIRS=${67:-%MODEL.FDB_DIRS%}
# Model RAPS flag groups (conf/model/ifs-fesom/ifs-fesom.yml)
GENERAL_FLAGS=${68:-%MODEL.RAPS.GENERAL_FLAGS%}
FESOM_FLAGS=${69:-%MODEL.RAPS.FESOM_FLAGS%}
RESTART_FLAGS=${70:-%MODEL.RAPS.RESTART_FLAGS%}
FDB_FLAGS=${71:-%MODEL.RAPS.FDB_FLAGS%}
IO_FLAGS=${72:-%MODEL.RAPS.IO_FLAGS%}
NAMELIST_FLAGS=${73:-%MODEL.RAPS.NAMELIST_FLAGS%}
# FESOM perturbation parameters
FESOM_PERTURB=${74:-%CONFIGURATION.FESOM_PERTURB%}
FESOM_PERTURBATION_SEED_BASE=${75:-%CONFIGURATION.FESOM_PERTURBATION_SEED_BASE%}

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

RAPS_BIN=${MODEL_PATH}/source/raps/bin
BUNDLE_BUILD_DIR=${MODEL_PATH}/build

export BUNDLE_BUILD_DIR
export PATH=${RAPS_BIN}:$PATH

OUTROOT=${HPCROOTDIR}/rundir
RESTART_DIR=${HPCROOTDIR}/restarts/${SIM_START_DATE}

export INPROOT=${MODEL_INPUTS}
export OUTROOT=${OUTROOT}

export MULTIO_RAPS_PLANS_PATH=${RAPS_BIN}/../multio_yaml

if [ ! -z $MULTIO_ATM_PLANS ]; then
    export MULTIO_IFSIO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ifsio-config-${MULTIO_ATM_PLANS}.yaml
else
    export MULTIO_IFSIO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ifsio-config.yaml
fi

export FDB_DIRS="${FDB_HOME}/native:${FDB_HOME}:${FDB_HOME}/latlon"

export input_expver=%CONFIGURATION.IFS.EXPVER%
export label=%CONFIGURATION.IFS.LABEL%

export gtype=%CONFIGURATION.IFS.GTYPE%
export resol=%CONFIGURATION.IFS.RESOL%
export levels=%CONFIGURATION.IFS.LEVELS%

SDATE=%SDATE%
yyyymmdd=${SDATE::8}
export yyyymmddzz=${yyyymmdd}00

# compute fclen

if [ "${CHUNKSIZEUNIT}" == "month" ] || [ "${CHUNKSIZEUNIT}" == "year" ]; then
    runlength=%CHUNK_END_IN_DAYS%
    CHUNKSIZEUNIT=day
else
    runlength=$((CHUNK * CHUNKSIZE))
fi
fclen=${CHUNKSIZEUNIT:0:1}${runlength}

# lib/common/utils/sim_utils.sh (manually generated comment)
load_variables_"${ATM_MODEL}"

jobname=$SLURM_JOB_NAME
jobid=$SLURM_JOB_ID

rundir=$(find "${HPCROOTDIR}" -type d -name "h$(($runlength * 24))*${jobname}-${jobid}" -print -quit)

if [ -z ${rundir} ]; then
    echo "Rundir variable is empty. No previous rundir found. "
else
    echo "Previous rundir found. This is a retrial inside a wrapper"
    echo "The previous rundir was: ${rundir}"

fi

if [ -d "$rundir" ]; then
    retrial_number=0
    for i in $(seq 0 $TOTAL_RETRIALS); do
        if [ -d ${rundir}.$i ]; then
            echo "Found the $i attempt to run this chunk inside the wrapper"
            retrial_number=$((i + 1))
        fi
    done
    mv $rundir ${rundir}.$retrial_number
    echo "The previous rundir: ${rundir} has been renamed"
    echo "It can be found in: ${rundir}.${retrial_number}"
fi

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
