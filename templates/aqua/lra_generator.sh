#!/bin/bash

set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
EXPID=${2:-%DEFAULT.EXPID%}
HPC_PROJECT=${3:-%CONFIGURATION.HPC_PROJECT_DIR%}
CONTAINER_VERSION=${4:-%AQUA.CONTAINER_VERSION%}
CATALOG_NAME=${5:-%CURRENT_CATALOG_NAME%}
EXPVER=${6:-%REQUEST.EXPVER%}
CHUNK_END_DATE=${7:-%CHUNK_END_DATE%}
MODEL=${8:-%REQUEST.MODEL%}
SDATE=${9:-%SDATE%}
PROJDEST=${10:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${11:-%CURRENT_ARCH%}
JOBNAME=${12:-%JOBNAME%}
HPC_SCRATCH=${13:-%CONFIGURATION.PROJECT_SCRATCH%}
DATABRIDGE_FDB_HOME=${14:-%CURRENT_DATABRIDGE_FDB_HOME%}
DATA_DIR=${15:-%CURRENT_DATA_DIR%}
HPC_CONTAINER_DIR=${16:-%CONFIGURATION.CONTAINER_DIR%}
OPERATIONAL_PROJECT_SCRATCH=${17:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${18:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}
FDB_HOME=${19:-%REQUEST.FDB_HOME%}

# END_HEADER

AQUA="/app/AQUA"

AQUA_CONTAINER="${HPC_CONTAINER_DIR}/aqua/aqua_${CONTAINER_VERSION}.sif"
ONLY_LRA_PATH="${HPCROOTDIR}/LOG_${EXPID}/only_lra_$(echo ${JOBNAME} | sed 's/^[^_]*_//')"
AQUA_CONFIG="${HPCROOTDIR}/.aqua"

ENTRY_PATH="${HPCROOTDIR}/${PROJDEST}/catalog/catalogs/${CATALOG_NAME}/catalog/${MODEL}/${EXPVER}.yaml"

sed -i "s/data_end_date: .*/data_end_date: ${CHUNK_END_DATE}T2300/" "$ENTRY_PATH"

sed -i "s/ date: .*/ date: ${SDATE}\/to\/${CHUNK_END_DATE}/" "$ENTRY_PATH"

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib    # Path to the lib directory
HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture
# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

singularity exec \
    --cleanenv \
    --env PYTHONPATH=/opt/conda/lib/python3.10/site-packages \
    --env ESMFMKFILE=/opt/conda/lib/esmf.mk \
    --env PYTHONPATH=$AQUA \
    --env AQUA=$AQUA \
    --env ONLY_LRA_PATH=$ONLY_LRA_PATH \
    --env AQUA_CONFIG=$AQUA_CONFIG \
    --env CATALOG_NAME=$CATALOG_NAME \
    --bind "${HPCROOTDIR}" \
    --bind "$(realpath ${HPC_PROJECT})" \
    --bind "${HPC_PROJECT}" \
    --bind "${HPC_SCRATCH}" \
    --bind "${DEVELOPMENT_PROJECT_SCRATCH}" \
    --bind "${OPERATIONAL_PROJECT_SCRATCH}" \
    --bind "${DATABRIDGE_FDB_HOME}" \
    --bind "${DATA_DIR}" \
    --bind "$(realpath ${DATA_DIR})" \
    --bind "${FDB_HOME}" \
    $AQUA_CONTAINER \
    bash -c \
    "
    aqua set ${CATALOG_NAME}
    aqua lra -c $ONLY_LRA_PATH -d
    "
