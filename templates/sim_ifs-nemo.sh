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
ENVIRONMENT=${7:-%RUN.ENVIRONMENT%}
HPCARCH=${8:-%HPCARCH%}
MODEL_VERSION=${9:-%MODEL.VERSION%}
OCEAN_GRID=${10:-%MODEL.GRID_OCE%}
EXPID=${11:-%DEFAULT.EXPID%}
ATM_GRID=${12:-%MODEL.GRID_ATM%}
CHUNK=${13:-%CHUNK%}
TOTAL_RETRIALS=${14:-%CONFIG.RETRIALS%}
ICMCL=${15:-%MODEL.ICMCL_PATTERN%}
START_DATE=${16:-%CHUNK_START_DATE%}
END_DATE=${17:-%CHUNK_END_DATE%}
END_IN_DAYS=${18:-%CHUNK_END_IN_DAYS%}
PREV=${19:-%PREV%}
RUN_DAYS=${20:-%RUN_DAYS%}
IFS_IO_TASKS=${21:-%CONFIGURATION.IFS.IO_TASKS%}
NEMO_IO_TASKS=${22:-%CONFIGURATION.NEMO.IO_TASKS%}
HPC_PROJECT=${23:-%CONFIGURATION.HPC_PROJECT_DIR%}
MULTIO_ATM_PLANS=${24:-%CONFIGURATION.IFS.MULTIO_PLANS%}
MULTIO_OCEAN_PLANS=${25:-%CONFIGURATION.NEMO.MULTIO_PLANS%}
PU=${26:-%RUN.PROCESSOR_UNIT%}
RAPS_USER_FLAGS=${27:-%CONFIGURATION.RAPS_USER_FLAGS%}
RAPS_EXPERIMENT=${28:-%CONFIGURATION.RAPS_EXPERIMENT%}
RUN_TYPE=${29:-%RUN.TYPE%}
IFS_IO_PPN=${30:-%CONFIGURATION.IFS.IO_PPN%}
NEMO_IO_PPN=${31:-%CONFIGURATION.NEMO.IO_PPN%}
IFS_IO_NODES=${32:-%CONFIGURATION.IFS.IO_NODES%}
NEMO_IO_NODES=${33:-%CONFIGURATION.NEMO.IO_NODES%}
MEMBER=${34:-%MEMBER%}
MEMBER_LIST=${35:-%EXPERIMENT.MEMBERS%}
WORKFLOW=${36:-%RUN.WORKFLOW%}
SPLITS=${37:-%JOBS.DN.SPLITS%}
EXPVER=${38:-%REQUEST.EXPVER%}
CLASS=${39:-%REQUEST.CLASS%}
FDB_HOME=${40:-%REQUEST.FDB_HOME%}
DQC_PROFILE_PATH=${41:-%CONFIGURATION.DQC_PROFILE_PATH%}
EXPERIMENT=${42:-%REQUEST.EXPERIMENT%}
ACTIVITY=${43:-%REQUEST.ACTIVITY%}
GENERATION=${44:-%REQUEST.GENERATION%}
MODEL=${45:-%REQUEST.MODEL%}
IO_ON=${46:-%CONFIGURATION.IO_ON%} # True or False
LIBDIR=${47:-%CONFIGURATION.LIBDIR%}
SCRATCH_DIR=${48:-%CURRENT_SCRATCH_DIR%}
HPC_CONTAINER_DIR=${49:-%CONFIGURATION.CONTAINER_DIR%}
GSV_VERSION=${50:-%GSV.VERSION%}
MODEL_ROOT_PATH=${51:-%MODEL.ROOT_PATH%}
MODEL_PATH=${52:-%MODEL.PATH%}
MODEL_INPUTS=${53:-%MODEL.INPUTS%}
SCRIPTDIR=${54:-%CONFIGURATION.SCRIPTDIR%}
# Platform-dependent RAPS parameters (conf/model/ifs-nemo/ifs-nemo.yml)
RAPS_HOST_CPU=${55:-%CURRENT_RAPS_HOST_CPU%}
RAPS_HOST_GPU=${56:-%CURRENT_RAPS_HOST_GPU%}
RAPS_BIN_HPC_NAME=${57:-%CURRENT_RAPS_BIN_HPC_NAME%}
RAPS_COMPILER=${58:-%CURRENT_RAPS_COMPILER%}
RAPS_MPILIB=${59:-%CURRENT_RAPS_MPILIB%}
# Path to the modules profile (conf/platforms.yml)
MODULES_PROFILE_PATH=${60:-%CONFIGURATION.MODULES_PROFILE_PATH%}
# Extra bindings needed for the container in hpc-fdb
OPERATIONAL_PROJECT_SCRATCH=${61:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${62:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}

# END_HEADER

set -xuve

ICMCL=${ICMCL:-ICMCL_%CONFIGURATION.IFS.RESOL%_%CHUNK_START_YEAR%_extra}

NEMO_IO_PPN=${NEMO_IO_PPN:-0}
IFS_IO_PPN=${IFS_IO_PPN:-0}

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

# Directory definition

RAPS_BIN="${MODEL_PATH}/source/raps/bin"
BUNDLE_BUILD_DIR=${MODEL_PATH}/build

export BUNDLE_BUILD_DIR
export PATH=${RAPS_BIN}:$PATH

PRE_RESTART_DIR=${HPCROOTDIR}/restarts/${MEMBER}
RESTART_DIR=${PRE_RESTART_DIR}/current

OUTROOT=${HPCROOTDIR}/rundir
export OUTROOT=${OUTROOT}

mkdir -p ${PRE_RESTART_DIR}
cd ${PRE_RESTART_DIR}
mkdir -p "${CHUNK}"
rm -f current
ln -s "${CHUNK}" current
cd current

files=("waminfo" "rcf" "nemorcf" "nemorcf.${START_DATE}_000000")

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
if [ -d ${HPCROOTDIR}/inipath/${MEMBER} ]; then
    export INPROOT=${HPCROOTDIR}/inipath/${MEMBER}
else
    export INPROOT=${MODEL_INPUTS}
fi

export MULTIO_RAPS_PLANS_PATH=${RAPS_BIN}/../multio_yaml

if [ ! -z "$MULTIO_ATM_PLANS" ]; then
    export MULTIO_IFSIO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ifsio-config-${MULTIO_ATM_PLANS}.yaml
fi

if [ ! -z "$MULTIO_OCEAN_PLANS" ]; then
    export MULTIO_NEMO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-nemo-${MULTIO_OCEAN_PLANS}.yaml
fi

export FDB_DIRS="${FDB_HOME}/native:${FDB_HOME}:${FDB_HOME}/latlon"

#####################################################
# Sets experiment dependent variables for RAPS
# Globals:
#	CHUNKSIZEUNIT
# Arguments:
#
######################################################
function load_experiment_ifs() {

    export input_expver=%CONFIGURATION.IFS.EXPVER%
    export label=%CONFIGURATION.IFS.LABEL%

    export gtype=%CONFIGURATION.IFS.GTYPE%
    export resol=%CONFIGURATION.IFS.RESOL%
    export levels=%CONFIGURATION.IFS.LEVELS%

    SDATE=%SDATE%
    yyyymmdd=${SDATE::8}
    export yyyymmddzz=${yyyymmdd}00

    if [ "${CHUNKSIZEUNIT,,}" == "month" ] || [ "${CHUNKSIZEUNIT,,}" == "year" ]; then
        runlength=%CHUNK_END_IN_DAYS%
        CHUNKSIZEUNIT=day
    else
        runlength=$((CHUNK * CHUNKSIZE))
    fi
    fclen=${CHUNKSIZEUNIT:0:1}${runlength}

    load_variables_"${ATM_MODEL}"

}

#####################################################
# Runs an hres simulation
# Globals:
#	RAPS_BIN
#	RAPS_BIN_HPC_NAME
#	BUNDLE_BUILD_DIR
#	ICMCL
#	OCEAN_GRID
#	nemox
#	nemoy
#	IFS_IO_TASKS
#	NEMO_IO_TASKS
#	PREV
#	RUN_DAYS
#	EXPID
#	RESTART_DIR
#	FDB_DIRS
#	nproma
#	depth
#	ht
#	RAPS_ROOTDIR
# Arguments:
######################################################
function run_experiment_ifs() {

    cd "${RAPS_BIN}"/SLURM/"${RAPS_BIN_HPC_NAME}"

    # lib/common/util.sh (get_member_number) (auto generated comment)
    MEMBER_NUMBER=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

    other="--ifs-bundle-build-dir=${BUNDLE_BUILD_DIR} --icmcl ${ICMCL} -R --nemo \
    --nemo-ver=V40 --nemo-grid=${OCEAN_GRID} --nemo-xproc=${nemox} --nemo-yproc=${nemoy} \
    --deep  --nonemopart  --restartdirectory=${RESTART_DIR}  \
    --keeprestart $RAPS_USER_FLAGS"

    export other

    if [ ${IO_ON,,} == "false" ]; then
        flags_fdb=""
        io_flags=""
    else
        flags_fdb="--keepfdb --multio-production-fdbs=${FDB_DIRS} --outexp=${EXPVER} \
        --realization=${MEMBER_NUMBER} --generation=${GENERATION} --experiment=${RAPS_EXPERIMENT}"
        io_flags="--keepnetcdf --nextgemsout=6 --wam-multio --ifs-multio"

        # Undefined IO for NEMO, default configuration. Uses half of the IO resources for IFS and half for NEMO.
        if [ -z "${NEMO_IO_TASKS}" ] && [ -z "${NEMO_IO_NODES}" ] && [ -n "${IFS_IO_NODES}" ]; then
            echo "Same tasks for IFS and NEMO"
            IFS_IO_TASKS=$((${IFS_IO_NODES} * ${SLURM_CPUS_ON_NODE} / ${SLURM_CPUS_PER_TASK} / 2))
            NEMO_IO_TASKS=$((${IFS_IO_NODES} * ${SLURM_CPUS_ON_NODE} / ${SLURM_CPUS_PER_TASK} / 2))
        fi

        # Check for IFS and NEMO server resources
        if [ -n "${IFS_IO_TASKS}" ] && [ -n "${NEMO_IO_TASKS}" ]; then
            io_flags+=" --io-tasks=${IFS_IO_TASKS} --nemo-multio-server-num=${NEMO_IO_TASKS}"
        elif [ -n "${IFS_IO_NODES}" ] && [ -n "${NEMO_IO_NODES}" ]; then
            io_flags+=" --io-nodes=${IFS_IO_NODES} --io-ppn=${IFS_IO_PPN} --nemo-multio-server-nodes=${NEMO_IO_NODES} --nemo-multio-server-ppn=${NEMO_IO_PPN}"
        else
            echo 'Error: No resources selected for IFS or NEMO servers. Add IFS_IO_NODES and NEMO_IO_NODES or IFS_IO_TASKS and NEMO_IO_TASKS variables.'
            exit 1
        fi
    fi

    export other
    export flags_fdb
    export io_flags

    set +e
    source ../../../.again
    set -e

    # Run the RAPS script

    set -eux

    ifsMASTER=""

    nproma=${nproma:-32}
    depth=${depth:-$omp}
    ht=${ht:-$(htset.pl "$SLURM_NTASKS_PER_NODE" "$SLURM_CPUS_PER_TASK")}

    echo "Model run starts"

    hres \
        -p "$mpi" -t "$omp" -h "$ht" \
        -j "$jobid" -J "$jobname" \
        -d "$yyyymmddzz" -e "$input_expver" -L "$label" \
        -T "$gtype" -r "$resol" -l "$levels" -f "$fclen" \
        -x "$ifsMASTER" \
        -N "$nproma" \
        -H "$host" -n "$nodes" -C "$RAPS_COMPILER" ${other:-} ${flags_fdb} ${io_flags} |
        grep -v 'IO_SERV_CLOSE_EC FLUSHFDB'
}

###################################################
# Checking, before the actual model run, if there
# was a previous directory with the same chunk number
# (so the same runlength and jobname) in the wrapper
# (same jobid), and in case it exists, renaming
# it with the RETRIAL number.
####################################################

function check_rundir_name() {
    jobname=$SLURM_JOB_NAME
    jobid=$SLURM_JOB_ID

    rundir=$(find "${HPCROOTDIR}" -type d -name "h$(($runlength * 24))*${jobname}-${jobid}" -print -quit)

    if [ -z "${rundir}" ]; then
        echo "Rundir variable is empty. No previous rundir found. "
    else
        echo "Previous rundir found. This is a retrial inside a wrapper"
        echo "The previous rundir was: ${rundir}"

    fi

    if [ -d "$rundir" ]; then
        retrial_number=0
        for i in $(seq 0 "$TOTAL_RETRIALS"); do
            if [ -d "${rundir}"."$i" ]; then
                echo "Found the $i attempt to run this chunk inside the wrapper"
                retrial_number=$((i + 1))
            fi
        done
        mv "$rundir" "${rundir}".$retrial_number
        echo "The previous rundir: ${rundir} has been renamed"
        echo "It can be found in: ${rundir}.${retrial_number}"
    fi
}

#################################################
# Indentifying the new restart files generated
# and moving them to the next chunk's folder
# in order to use them in the following
# chunk.
################################################
function restarts_moving() {

    cd ${PRE_RESTART_DIR}

    SDATE=%SDATE%
    SDATE_LONG=%SDATE%000000
    CHUNK_END_IN_DAYS=%CHUNK_END_IN_DAYS%

    formatted_days=$(printf "%06d" "$CHUNK_END_IN_DAYS")0000

    CHUNK_END_IN_DAYS_1=$((CHUNK_END_IN_DAYS - 1))
    formatted_days_1=$(printf "%06d" "$CHUNK_END_IN_DAYS_1")

    mkdir -p $((CHUNK + 1))/

    mv "$CHUNK"/"LAW${SDATE_LONG}_${formatted_days_1}"* $((CHUNK + 1))/
    mv "$CHUNK"/"srf${formatted_days}"* $((CHUNK + 1))/
    mv "$CHUNK"/"BLS"${SDATE_LONG}_"${formatted_days_1}"* $((CHUNK + 1))/

    mv "$CHUNK"/"${EXPVER}_%CHUNK_END_DATE%"* $((CHUNK + 1))/

    mv "$CHUNK"/waminfo $((CHUNK + 1))/
    mv "$CHUNK"/rcf $((CHUNK + 1))/
    mv "$CHUNK"/nemorcf $((CHUNK + 1))/
    mv "$CHUNK"/nemorcf.%CHUNK_END_DATE%* $((CHUNK + 1))/
    sed -i "s#${PRE_RESTART_DIR}/${CHUNK}#${PRE_RESTART_DIR}/$((CHUNK + 1))#" ${RESTART_DIR}/../$((CHUNK + 1))/nemorcf

    if [ -f "$CHUNK/nemorcf-backup" ]; then
        mv "$CHUNK"/"nemorcf-backup" "$CHUNK/nemorcf"
    fi

    if [ -f "$CHUNK/rcf-backup" ]; then
        mv "$CHUNK"/"rcf-backup" "$CHUNK/rcf"
    fi

    if [ -f "$CHUNK/waminfo-backup" ]; then
        mv "$CHUNK"/"waminfo-backup" "$CHUNK/waminfo"
    fi

    if [ -f "$CHUNK/nemorcf.${START_DATE}-backup" ]; then
        mv "$CHUNK"/"nemorcf.${START_DATE}-backup" "$CHUNK/nemorcf.${START_DATE}_000000"
    fi

    rm -rf current

}

# Defines the host as RAPS_HOST_CPU or RAPS_HOST_GPU depending on the PU
# lib/common/util.sh (get_host_for_raps) (auto generated comment)
host=$(get_host_for_raps "${PU}" "${RAPS_HOST_CPU}" "${RAPS_HOST_GPU}")
# Exports mpilib for RAPS
export mpilib=${RAPS_MPILIB}

load_experiment_"${ATM_MODEL}"

check_rundir_name

nemox=-1
nemoy=-1

export LD_LIBRARY_PATH=$BUNDLE_BUILD_DIR/ifs_sp:$LD_LIBRARY_PATH

run_experiment_"${ATM_MODEL}"

echo "The model ran successfully."
echo "Moving the restart files to the next chunk folder to use them in the following chunk"

restarts_moving

cd $OUTROOT

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
    --env "FDB_HOME=$(realpath ${FDB_HOME})" \
    --env "HPCROOTDIR=${HPCROOTDIR}" \
    --env "SCRIPTDIR=${SCRIPTDIR}" \
    --bind "$(realpath ${HPCROOTDIR})" \
    --bind "$(realpath ${FDB_HOME})" \
    --bind "${FDB_HOME}" \
    --bind "$(realpath ${SCRATCH_DIR})" \
    --bind "${DEVELOPMENT_PROJECT_SCRATCH}" \
    --bind "$(realpath ${DEVELOPMENT_PROJECT_SCRATCH})" \
    --bind "${OPERATIONAL_PROJECT_SCRATCH}" \
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
