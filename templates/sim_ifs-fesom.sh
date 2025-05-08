#!/bin/bash
#

set -xuve

# HEADER

HPCROOTDIR=%HPCROOTDIR%
PROJDEST=%PROJECT.PROJECT_DESTINATION%
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
START_DATE=${17:-%CHUNK_START_DATE%}
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
RAPS_EXPERIMENT=${29:-%CONFIGURATION.RAPS_EXPERIMENT%}
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

# END_HEADER

ATM_MODEL=${MODEL_NAME%%-*}

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

# Source libraries
. "${LIBDIR}"/common/util.sh
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
RESTART_DIR=${HPCROOTDIR}/restarts

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

load_variables_"${ATM_MODEL}"

###################################################
# Checking, before the actual model run, if there
# was a previous directory with the same chunk number
# (so the same runlength and jobname) in the wrapper
# (same jobid), and in case it exists, renaming
# it with the RETRIAL number.
####################################################

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
# lib/common/util.sh (get_host_for_raps) (auto generated comment)
host=$(get_host_for_raps "${PU}" "${RAPS_HOST_CPU}" "${RAPS_HOST_GPU}")
# Exports mpilib for RAPS
export mpilib=${RAPS_MPILIB}
cd ${RAPS_BIN}/SLURM/${RAPS_BIN_HPC_NAME}

# lib/common/util.sh (get_member_number) (auto generated comment)
MEMBER_NUMBER=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

other="--ifs-bundle-build-dir=${BUNDLE_BUILD_DIR} --icmcl ${ICMCL} -R --fesom --deep --nonemopart --keepnetcdf --nextgemsout=6 --wam-multio --ifs-multio --restartdirectory=${RESTART_DIR} --keeprestart --experiment=${RAPS_EXPERIMENT} --inproot-namelists $RAPS_USER_FLAGS"

flags_fdb="--keepfdb --multio-production-fdbs=${FDB_DIRS} --outexp=${EXPVER} --realization=${MEMBER_NUMBER} --generation=${GENERATION}"

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
    -H "$host" -n "$nodes" -C "$RAPS_COMPILER" ${other:-} ${flags_fdb} ${io_flags}

echo "The model ran successfully."

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity
singularity exec --cleanenv --no-home \
    --env "LIBDIR=${LIBDIR}" \
    --env "DQC_PROFILE_PATH=${DQC_PROFILE_PATH}" \
    --env "EXPVER=${EXPVER}" \
    --env "EXPERIMENT=${EXPERIMENT}" \
    --env "ACTIVITY=${ACTIVITY}" \
    --env "REALIZATION=${MEMBER_NUMBER}" \
    --env "GENERATION=${GENERATION}" \
    --env "MODEL=${MODEL}" \
    --env "START_DATE=${START_DATE}" \
    --env "END_DATE=${END_DATE}" \
    --env "CHUNK=${CHUNK}" \
    --env "FDB_HOME=${FDB_HOME}" \
    --env "HPCROOTDIR=${HPCROOTDIR}" \
    --env "SCRIPTDIR=${SCRIPTDIR}" \
    --bind "$(realpath ${HPCROOTDIR})" \
    --bind "$(realpath ${FDB_HOME})" \
    --bind "$(realpath ${SCRATCH_DIR})" \
    "$HPC_CONTAINER_DIR"/gsv/gsv_${GSV_VERSION}.sif \
    bash -c \
    '
    set -xuve
    cd ${HPCROOTDIR}
    . "${LIBDIR}"/common/util.sh
# lib/common/util.sh (fix_constant_variables) (auto generated comment)
    fix_constant_variables "${LIBDIR}" "${DQC_PROFILE_PATH}" "${EXPVER}" \
        "${EXPERIMENT}" "${ACTIVITY}" "${MODEL}" "${START_DATE}" \
        "${END_DATE}" "${CHUNK}" "${FDB_HOME}" "${REALIZATION}" "${GENERATION}"
    '
