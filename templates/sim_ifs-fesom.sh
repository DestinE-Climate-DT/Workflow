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
ICMCL=${ICMCL:-ICMCL_%CONFIGURATION.IFS.RESOL%_%CHUNK_START_YEAR%-%CHUNK_START_YEAR%}
START_DATE=${16:-%CHUNK_START_DATE%}
END_DATE=${17:-%CHUNK_END_DATE%}
END_IN_DAYS=${18:-%CHUNK_END_IN_DAYS%}
PREV=${19:-%PREV%}
RUN_DAYS=${20:-%RUN_DAYS%}
HPC_PROJECT=${25:-%CURRENT_HPC_PROJECT_DIR%}
MULTIO_ATM_PLANS=${26:-%CONFIGURATION.IFS.MULTIO_PLANS%}
MULTIO_OCEAN_PLANS=${27:-%CONFIGURATION.NEMO.MULTIO_PLANS%}
PU=${28:-%RUN.PROCESSOR_UNIT%}
RAPS_USER_FLAGS=${29:-%CONFIGURATION.RAPS_USER_FLAGS%}
RAPS_EXPERIMENT=${30:-%CONFIGURATION.RAPS_EXPERIMENT%}
INPUTS=${31:-%CONFIGURATION.INPUTS%}
PRODUCTION=${32:-%RUN.PRODUCTION%}
FDB_PROD=${33:-%CURRENT_FDB_PROD%}
FDB_DIR=${34:-%CURRENT_FDB_DIR%}
IFS_IO_NODES=${37:-%CONFIGURATION.IFS.IO_NODES%}
IFS_IO_PPN=${35:-%CONFIGURATION.IFS.IO_PPN%}
FESOM_IO_NODES=${38:-%CONFIGURATION.FESOM.IO_NODES%}
FESOM_IO_PPN=${36:-%CONFIGURATION.FESOM.IO_PPN%}

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

if [ -z "${MODEL_VERSION}" ]; then
    BUNDLE_BUILD_DIR=${HPCROOTDIR}/${PROJDEST}/${MODEL_NAME}/build
else
    BUNDLE_BUILD_DIR=${PRECOMP_MODEL_PATH}/build
fi

export BUNDLE_BUILD_DIR
export PATH=${RAPS_BIN}:$PATH

OUTROOT=${HPCROOTDIR}/rundir
RESTART_DIR=${HPCROOTDIR}/restarts

export INPROOT=${INPROOT}
export OUTROOT=${OUTROOT}

export MULTIO_RAPS_PLANS_PATH=${RAPS_BIN}/../multio_yaml

if [ ! -z $MULTIO_ATM_PLANS ]; then
    export MULTIO_IFSIO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ifsio-config-${MULTIO_ATM_PLANS}.yaml
else
    export MULTIO_IFSIO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ifsio-config.yaml
fi

if [ ${PRODUCTION,,} = "true" ]; then
    export FDB_DIRS="${FDB_PROD}/native:${FDB_PROD}:${FDB_PROD}/latlon"
else
    export FDB_DIRS="${FDB_DIR}/${EXPID}/fdb/NATIVE_grids:${FDB_DIR}/${EXPID}/fdb/HEALPIX_grids:${FDB_DIR}/${EXPID}/fdb/REGULARLL_grids"
fi

export expver=%CONFIGURATION.IFS.EXPVER%
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

load_SIM_env_"${ATM_MODEL}"_"${PU}"
cd ${RAPS_BIN}/SLURM/${bin_hpc_name}

other="--ifs-bundle-build-dir=${BUNDLE_BUILD_DIR} --icmcl ${ICMCL} -R --fesom --deep --nonemopart --keepnetcdf --nextgemsout=6 --wam-multio --ifs-multio --restartdirectory=${RESTART_DIR} --keeprestart --experiment=${RAPS_EXPERIMENT} $RAPS_USER_FLAGS"

if [ "${PRODUCTION,,}" = "true" ]; then
    echo "Production run. The experiment id in the FDB will be 0001."
    flags_fdb="--keepfdb --multio-production-fdbs=${FDB_DIRS} --outexp=0001"
else
    echo "Not a production run. The experiment id in the FDB will be ${EXPID}."
    flags_fdb="--keepfdb --multio-production-fdbs=${FDB_DIRS} --outexp=${EXPID}"
fi

io_flags=""

io_flags="--ionodes=${IFS_IO_NODES} --io-ppn=${IFS_IO_PPN} --fesom-multio-server-nodes=${FESOM_IO_NODES} --fesom-multio-server-ppn=${FESOM_IO_PPN}"

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

ifsMASTER=""

nproma=${nproma:-32}
depth=${depth:-$omp}
ht=${ht:-$(htset.pl "$SLURM_NTASKS_PER_NODE" "$SLURM_CPUS_PER_TASK")}

echo "Model run starts"

hres \
    -p "$mpi" -t "$omp" -h "$ht" \
    --ppn $SLURM_NTASKS_PER_NODE \
    -j "$jobid" -J "$jobname" \
    -d "$yyyymmddzz" -e "$expver" -L "$label" \
    -T "$gtype" -r "$resol" -l "$levels" -f "$fclen" \
    -x "$ifsMASTER" \
    -N "$nproma" \
    -H "$host" -n "$nodes" -C "$compiler" ${other:-} ${flags_fdb} ${io_flags}

echo "The model ran successfully."
