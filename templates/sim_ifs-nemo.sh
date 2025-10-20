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
HPC_CONTAINER_DIR=${37:-%CONFIGURATION.CONTAINER_DIR%}
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

input_expver=${58:-%CONFIGURATION.IFS.EXPVER%}
label=${59:-%CONFIGURATION.IFS.LABEL%}
gtype=${60:-%CONFIGURATION.IFS.GTYPE%}
resol=${61:-%CONFIGURATION.IFS.RESOL%}
levels=${62:-%CONFIGURATION.IFS.LEVELS%}
IFS_START_DATE=${63:-%CONFIGURATION.IFS.START_DATE%}

RAPS_BIN=${64:-%MODEL.RAPS_BIN%}
BUNDLE_BUILD_DIR=${65:-%MODEL.BUNDLE_BUILD_DIR%}
PRE_RESTART_DIR=${66:-%CONFIGURATION.PRE_RESTART_DIR%}
RESTART_DIR=${67:-%CONFIGURATION.RESTART_DIR%}
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

export BUNDLE_BUILD_DIR
export PATH=${RAPS_BIN}:$PATH

export OUTROOT=${RUNDIR_PATH}

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

if [ ! -z "$MULTIO_ATM_PLANS" ]; then
    export MULTIO_IFSIO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ifsio-config-${MULTIO_ATM_PLANS}.yaml
fi

if [ ! -z "$MULTIO_OCEAN_PLANS" ]; then
    export MULTIO_NEMO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-nemo-${MULTIO_OCEAN_PLANS}.yaml
fi

# Defines the host as RAPS_HOST_CPU or RAPS_HOST_GPU depending on the PU
# lib/common/utils/sim_utils.sh (get_host_for_raps) (auto generated comment)
host=$(get_host_for_raps "${PU}" "${RAPS_HOST_CPU}" "${RAPS_HOST_GPU}")
# Exports mpilib for RAPS
export mpilib=${RAPS_MPILIB}

load_experiment_"${ATM_MODEL}"

# lib/common/utils/sim_utils.sh (check_rundir_name) (auto generated comment)
check_rundir_name

export LD_LIBRARY_PATH=$BUNDLE_BUILD_DIR/ifs_sp:$LD_LIBRARY_PATH

# lib/common/utils/sim_utils.sh (run_experiment_ifs) (manually generated comment)
run_experiment_"${ATM_MODEL}"

echo "The model ran successfully."
echo "Moving the restart files to the next chunk folder to use them in the following chunk"

# lib/common/utils/sim_utils.sh (restarts_moving) (auto generated comment)
restarts_moving
