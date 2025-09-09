#!/bin/bash
#

set -xuve

# HEADER

SCRATCH_DIR=${1:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${2:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${3:-%CURRENT_LOCAL_DIR%}
FDB_HOME=${4:-%REQUEST.FDB_HOME%}
LIBDIR=${5:-%CONFIGURATION.LIBDIR%}
DQC_PROFILE_PATH=${6:-%CONFIGURATION.DQC_PROFILE_PATH%}
EXPVER=${7:-%REQUEST.EXPVER%}
EXPERIMENT=${8:-%REQUEST.EXPERIMENT%}
ACTIVITY=${9:-%REQUEST.ACTIVITY%}
GENERATION=${10:-%REQUEST.GENERATION%}
MEMBER=${11:-%MEMBER%}
MEMBER_LIST=${12:-%EXPERIMENT.MEMBERS%}
MODEL=${13:-%REQUEST.MODEL%}
START_DATE=${14:-%CHUNK_START_DATE%}
END_DATE=${15:-%CHUNK_END_DATE%}
CHUNK=${16:-%CHUNK%}
HPCROOTDIR=${17:-%HPCROOTDIR%}
SCRIPTDIR=${18:-%CONFIGURATION.SCRIPTDIR%}
GSV_VERSION=${19:-%GSV.VERSION%}
CURRENT_ARCH=${20:-%CURRENT_ARCH%}
HPC_CONTAINER_DIR=${21:-%CONFIGURATION.CONTAINER_DIR%}

# END_HEADER

set -xuve

# Source libraries
HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)
. "${LIBDIR}"/common/util.sh
. "${LIBDIR}"/"${HPC}"/config.sh

# lib/common/util.sh (get_member_number) (auto generated comment)
MEMBER_NUMBER=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

ADDITIONAL_BINDINGS=("$(realpath ${FDB_HOME})")
# lib/common/util.sh (setup_additional_binds) (auto generated comment)
bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")

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
    ${bindings} \
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
