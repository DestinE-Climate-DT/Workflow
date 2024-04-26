#!/bin/bash
#

set -xuve

# Interface
HPCROOTDIR=%HPCROOTDIR%
PROJDEST=%PROJECT.PROJECT_DESTINATION%
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
ICMCL=${15:-%ICMCL%}
ICMCL=${ICMCL:-ICMCL_%CONFIGURATION.IFS.RESOL%_%CHUNK_START_YEAR%_extra}
START_DATE=${16:-%CHUNK_START_DATE%}
END_DATE=${17:-%CHUNK_END_DATE%}
END_IN_DAYS=${18:-%CHUNK_END_IN_DAYS%}
PREV=${19:-%PREV%}
RUN_DAYS=${20:-%RUN_DAYS%}
IFS_IO_TASKS=${23:-%CONFIGURATION.IFS.IO_TASKS%}
NEMO_IO_TASKS=${24:-%CONFIGURATION.NEMO.IO_TASKS%}
HPC_PROJECT=${25:-%CURRENT_HPC_PROJECT_DIR%}
MULTIO_ATM_PLANS=${26:-%CONFIGURATION.IFS.MULTIO_PLANS%}
MULTIO_OCEAN_PLANS=${27:-%CONFIGURATION.NEMO.MULTIO_PLANS%}
PU=${28:-%RUN.PROCESSOR_UNIT%}
RAPS_USER_FLAGS=${29:-%CONFIGURATION.RAPS_USER_FLAGS%}
RAPS_EXPERIMENT=${30:-%CONFIGURATION.RAPS_EXPERIMENT%}
INPUTS=${31:-%CONFIGURATION.INPUTS%}
RUN_TYPE=${32:-%RUN.TYPE%}
FDB_PROD=${33:-%CURRENT_FDB_PROD%}
FDB_DIR=${34:-%CURRENT_FDB_DIR%}
IFS_IO_PPN=${35:-%CONFIGURATION.IFS.IO_PPN%}
IFS_IO_PPN=${IFS_IO_PPN:-0}
NEMO_IO_PPN=${36:-%CONFIGURATION.NEMO.IO_PPN%}
NEMO_IO_PPN=${NEMO_IO_PPN:-0}
IFS_IO_NODES=${37:-%CONFIGURATION.IFS.IO_NODES%}
NEMO_IO_NODES=${38:-%CONFIGURATION.NEMO.IO_NODES%}
MEMBER=${39:-%MEMBER%}
MEMBER_LIST="${40:-%EXPERIMENT.MEMBERS%}"
WORKFLOW=${41:-%RUN.WORKFLOW%}
SPLITS=${42:-%JOBS.DN.SPLITS%}

ATM_MODEL=${MODEL_NAME%%-*}

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

# Source libraries
. "${LIBDIR}"/common/util.sh
. "${LIBDIR}"/"${HPC}"/config.sh

export MODEL_VERSION
export ENVIRONMENT
export HPCARCH
export HPCROOTDIR
export INPUTS
export PROJDEST

load_model_dir
load_inproot_precomp_path

# Directory definition
if [ -z "${MODEL_VERSION}" ]; then
    RAPS_BIN="${HPCROOTDIR}/${PROJDEST}/${MODEL_NAME}/source/raps/bin"
else
    RAPS_BIN="${PRECOMP_MODEL_PATH}/source/raps/bin"
fi

PRE_RESTART_DIR=${HPCROOTDIR}/restarts/${MEMBER}
RESTART_DIR=${PRE_RESTART_DIR}/current

if [ -z "${MODEL_VERSION}" ]; then
    BUNDLE_BUILD_DIR=${HPCROOTDIR}/${PROJDEST}/${MODEL_NAME}/build
else
    BUNDLE_BUILD_DIR=${PRECOMP_MODEL_PATH}/build
fi

export BUNDLE_BUILD_DIR
export PATH=${RAPS_BIN}:$PATH

OUTROOT=${HPCROOTDIR}/rundir

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

if [ -d ${HPCROOTDIR}/inipath/${MEMBER} ]; then
    export INPROOT=${HPCROOTDIR}/inipath/${MEMBER}
else
    export INPROOT=${INPROOT}
fi

export OUTROOT=${OUTROOT}

export MULTIO_RAPS_PLANS_PATH=${RAPS_BIN}/../multio_yaml

if [ ! -z "$MULTIO_ATM_PLANS" ]; then
    export MULTIO_IFSIO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ifsio-config-${MULTIO_ATM_PLANS}.yaml
else
    export MULTIO_IFSIO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ifsio-config.yaml
fi

if [ ! -z "$MULTIO_OCEAN_PLANS" ]; then
    export MULTIO_NEMO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ocean-client-skeleton-${MULTIO_OCEAN_PLANS}.yaml
else
    export MULTIO_NEMO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ocean-client-skeleton.yaml
fi

set_data_gov ${RUN_TYPE}

if [ "${FDB_TYPE}" = "PROD" ]; then
    export FDB_DIRS="${FDB_PROD}/native:${FDB_PROD}:${FDB_PROD}/latlon"
else
    export FDB_DIRS="${FDB_DIR}/${EXPID}/fdb/NATIVE_grids:${FDB_DIR}/${EXPID}/fdb/HEALPIX_grids:${FDB_DIR}/${EXPID}/fdb/REGULARLL_grids"
fi

#####################################################
# Sets experiment dependent variables for RAPS
# Globals:
#	CHUNKSIZEUNIT
# Arguments:
#
######################################################
function load_experiment_ifs() {

    export expver=%CONFIGURATION.IFS.EXPVER%
    export label=%CONFIGURATION.IFS.LABEL%

    export gtype=%CONFIGURATION.IFS.GTYPE%
    export resol=%CONFIGURATION.IFS.RESOL%
    export levels=%CONFIGURATION.IFS.LEVELS%

    SDATE=%SDATE%
    yyyymmdd=${SDATE::8}
    export yyyymmddzz=${yyyymmdd}00

    if [ "${CHUNKSIZEUNIT}" == "month" ] || [ "${CHUNKSIZEUNIT}" == "year" ]; then
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
#	bin_hpc_name
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

    cd "${RAPS_BIN}"/SLURM/"${bin_hpc_name}"

    get_member_number "$MEMBER_LIST" "$MEMBER"

    other="--ifs-bundle-build-dir=${BUNDLE_BUILD_DIR} --icmcl ${ICMCL} -R --nemo --nemo-ver=V40 --nemo-grid=${OCEAN_GRID} --nemo-xproc=${nemox} --nemo-yproc=${nemoy} --deep  --nonemopart --keepnetcdf --nextgemsout=6 --wam-multio --ifs-multio --restartdirectory=${RESTART_DIR} --realization=${MEMBER_NUMBER} --keeprestart --experiment=${RAPS_EXPERIMENT} $RAPS_USER_FLAGS"

    export other

    flags_fdb="--keepfdb --multio-production-fdbs=${FDB_DIRS} --outexp=${EXPVER}"

    io_flags=""

    # Undefined IO for NEMO, default configuration. Uses half of the IO resources for IFS and half for NEMO.
    if [ -z "${NEMO_IO_TASKS}" ] && [ -z "${NEMO_IO_NODES}" ] && [ -n "${IFS_IO_NODES}" ]; then
        echo "Same tasks for IFS and NEMO"
        IFS_IO_TASKS=$((${IFS_IO_NODES} * ${SLURM_CPUS_ON_NODE} / ${SLURM_CPUS_PER_TASK} / 2))
        NEMO_IO_TASKS=$((${IFS_IO_NODES} * ${SLURM_CPUS_ON_NODE} / ${SLURM_CPUS_PER_TASK} / 2))
    fi

    # Check for IFS and NEMO server resources
    if [ -n "${IFS_IO_TASKS}" ] && [ -n "${NEMO_IO_TASKS}" ]; then
        io_flags="--io-tasks=${IFS_IO_TASKS} --nemo-multio-server-num=${NEMO_IO_TASKS}"
    elif [ -n "${IFS_IO_NODES}" ] && [ -n "${NEMO_IO_NODES}" ]; then
        io_flags="--io-nodes=${IFS_IO_NODES} --io-ppn=${IFS_IO_PPN} --nemo-multio-server-nodes=${NEMO_IO_NODES} --nemo-multio-server-ppn=${NEMO_IO_PPN}"
    else
        echo 'Error: No resources selected for IFS or NEMO servers. Add IFS_IO_NODES and NEMO_IO_NODES or IFS_IO_TASKS and NEMO_IO_TASKS variables.'
        exit 1
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
        -d "$yyyymmddzz" -e "$expver" -L "$label" \
        -T "$gtype" -r "$resol" -l "$levels" -f "$fclen" \
        -x "$ifsMASTER" \
        -N "$nproma" \
        -H "$host" -n "$nodes" -C "$compiler" ${other:-} ${flags_fdb} ${io_flags}
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

load_SIM_env_"${ATM_MODEL}"_"${PU}"

load_experiment_"${ATM_MODEL}"

check_rundir_name

nemox=-1
nemoy=-1

export LD_LIBRARY_PATH=$BUNDLE_BUILD_DIR/ifs_sp:$LD_LIBRARY_PATH

if [ "${WORKFLOW}" == "maestro-end-to-end" ]; then
    # Before we can run the Maestro-enabled model, we need the Pool Manager info to
    # connect to Maestro (file produced by templates/mstro_pm.sh)
    PM_INFO="${HPCROOTDIR}/LOG_${EXPID}/pm_${CHUNK}.info"
    while [ ! -s $PM_INFO ]; do
        echo "Waiting for pool manager credentials ..."
        sleep 1
    done
    echo "done."
    # reading for semi-colon separated line in the $PM_INFO file
    exec 4<$PM_INFO
    read -d ';' -u 4 pm_info_varname
    read -d ';' -u 4 pm_info
    MSTRO_POOL_MANAGER_INFO="$pm_info"
    export MSTRO_POOL_MANAGER_INFO
    echo "MSTRO_POOL_MANAGER_INFO=${MSTRO_POOL_MANAGER_INFO}"

    # We also need to wait for the OPA JOBS ready to listen to data events
    for i in $(seq 1 $SPLITS); do
        OPA_READY="${HPCROOTDIR}"/"LOG_${EXPID}"/"opa_"${CHUNK}"_"${i}"_mstrodep"
        while [ ! -f $OPA_READY ]; do
            echo "Waiting for OPA_${CHUNK}_${i} to prepare ..."
            sleep 1
        done
        echo "done."
    done

    load_environment_maestro_end_to_end
    export MSTRO_WORKFLOW_NAME="Maestro ECMWF Demo Workflow"
    export COMPONENT_NAME="IFS-Nemo"
fi

run_experiment_"${ATM_MODEL}"

# FIXME Perhaps using the Autosubmit-generated completed files is more economical
if [ "${WORKFLOW}" == "maestro-end-to-end" ]; then
    touch "${HPCROOTDIR}/LOG_${EXPID}/producer_${CHUNK}_mstrodep"
fi

echo "The model ran successfully."
echo "Moving the restart files to the next chunk folder to use them in the following chunk"

restarts_moving
