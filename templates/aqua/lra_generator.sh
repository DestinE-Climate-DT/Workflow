#!/bin/bash

set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
EXPID=${2:-%DEFAULT.EXPID%}
HPC_PROJECT=${3:-%CONFIGURATION.HPC_PROJECT_DIR%}
CONTAINER_VERSION=${4:-%AQUA.CONTAINER_VERSION%}
CATALOG_NAME=${5:-%HPCCATALOG_NAME%}
EXPVER=${6:-%REQUEST.EXPVER%}
CHUNK_SECOND_TO_LAST_DATE=${7:-%CHUNK_SECOND_TO_LAST_DATE%}
MODEL=${8:-%REQUEST.MODEL%}
SDATE=${9:-%SDATE%}
PROJDEST=${10:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${11:-%CURRENT_ARCH%}
JOBNAME=${12:-%JOBNAME%}
HPC_SCRATCH=${13:-%CONFIGURATION.PROJECT_SCRATCH%}
DATABRIDGE_FDB_HOME=${14:-%CURRENT_DATABRIDGE_FDB_HOME%}
DATA_DIR=${15:-%CURRENT_DATA_DIR%}
HPC_CONTAINER_DIR=${16:-%CURRENT_CONTAINER_DIR%}
OPERATIONAL_PROJECT_SCRATCH=${17:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${18:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}
FDB_HOME=${19:-%REQUEST.FDB_HOME%}
HPC_PROJECT_ROOT=${20:-%CURRENT_HPC_PROJECT_ROOT%}
SCRATCH_DIR=${21:-%CURRENT_SCRATCH_DIR%}
LOCAL_DIR=${22:-%CURRENT_LOCAL_DIR%}
MODEL_NAME_UPPER=${23:-%REQUEST.MODEL_NAME_UPPER%}
MEMBER=${24:-%MEMBER%}
MEMBER_LIST=${25:-%EXPERIMENT.MEMBERS%}
AQUA_CONFIG=${26:-%AQUA.INSTALL_DIR%}
CHUNK_END_DATE=${27:-%CHUNK_END_DATE%}

# END_HEADER

AQUA="/app/AQUA"

AQUA_CONTAINER="${HPC_CONTAINER_DIR}/aqua/aqua_${CONTAINER_VERSION}.sif"
ONLY_LRA_PATH="${HPCROOTDIR}/LOG_${EXPID}/only_lra_$(echo ${JOBNAME} | sed 's/^[^_]*_//')"

ENTRY_PATH="${HPCROOTDIR}/${PROJDEST}/catalog/catalogs/${CATALOG_NAME}/catalog/${MODEL_NAME_UPPER}/${EXPVER}.yaml"

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib    # Path to the lib directory
HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity
ADDITIONAL_BINDINGS=(
    "$(realpath ${DEVELOPMENT_PROJECT_SCRATCH})" "${DEVELOPMENT_PROJECT_SCRATCH}"
    "$(realpath ${OPERATIONAL_PROJECT_SCRATCH})" "${OPERATIONAL_PROJECT_SCRATCH}"
    "$(realpath ${HPC_PROJECT})" "${FDB_HOME}"
)
# lib/common/util.sh (setup_additional_binds) (auto generated comment)
bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")

# lib/common/util.sh (get_member_number) (auto generated comment)
REALIZATION=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

singularity exec \
    --cleanenv \
    --env PYTHONPATH=/opt/conda/lib/python3.10/site-packages \
    --env ESMFMKFILE=/opt/conda/lib/esmf.mk \
    --env PYTHONPATH=$AQUA \
    --env AQUA=$AQUA \
    --env ONLY_LRA_PATH=$ONLY_LRA_PATH \
    --env AQUA_CONFIG=$AQUA_CONFIG \
    --env CATALOG_NAME=$CATALOG_NAME \
    --env REALIZATION=$REALIZATION \
    ${bindings} \
    --no-mount /etc/localtime \
    $AQUA_CONTAINER \
    bash -c \
    "
    aqua set ${CATALOG_NAME}
    aqua drop -c $ONLY_LRA_PATH -d --realization r$REALIZATION --enddate ${CHUNK_END_DATE}
    "
