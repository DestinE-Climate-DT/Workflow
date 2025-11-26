#!/bin/bash

set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
EXPID=${3:-%DEFAULT.EXPID%}
HPC_PROJECT=${4:-%CONFIGURATION.HPC_PROJECT_DIR%}
CONTAINER_VERSION=${5:-%AQUA.CONTAINER_VERSION%}
MODEL=${6:-%REQUEST.MODEL%}
EXPVER=${7:-%REQUEST.EXPVER%}
CATALOG=${8:-%HPCCATALOG_NAME%}
APP_OUTPATH=${9:-%APP.OUTPATH%}
CURRENT_ARCH=${10:-%CURRENT_ARCH%}
HPC_SCRATCH=${11:-%CONFIGURATION.PROJECT_SCRATCH%}
DATA_DIR=${12:-%CURRENT_DATA_DIR%}
HPC_CONTAINER_DIR=${13:-%CONFIGURATION.CONTAINER_DIR%}
OPERATIONAL_PROJECT_SCRATCH=${14:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${15:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}

# END_HEADER

AQUA="/app/AQUA"

SOURCE="lra-r100-monthly"

AQUA_CONTAINER="${HPC_CONTAINER_DIR}/aqua/aqua_${CONTAINER_VERSION}.sif"
AQUA_CONFIG="${HPCROOTDIR}/.aqua"

OUTPATH=${APP_OUTPATH}/aqua-analysis

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
    --env AQUA_CONFIG=$AQUA_CONFIG \
    --env MODEL=$MODEL \
    --env EXPVER=$EXPVER \
    --env SOURCE=$SOURCE \
    --env OUTPATH=$OUTPATH \
    --env CATALOG=$CATALOG \
    --bind=${HPCROOTDIR} \
    --bind=$(realpath ${HPC_PROJECT}) \
    --bind=${HPC_PROJECT} \
    --bind=${HPC_SCRATCH} \
    --bind "${DEVELOPMENT_PROJECT_SCRATCH}" \
    --bind "${OPERATIONAL_PROJECT_SCRATCH}" \
    --bind=${DATA_DIR} \
    --bind=$(realpath ${DATA_DIR}) \
    $AQUA_CONTAINER \
    bash -c \
    "
    python $AQUA/cli/aqua-analysis/aqua-analysis.py -l debug -m $MODEL -e $EXPVER -s $SOURCE -d $OUTPATH -c $CATALOG --parallel
    "

# Check if the PDF plots were generated or not (structure is ${OUTPATH}/${CATALOG}/${MODEL}/${EXPVER}/${diagnostic}/*.pdf)
# Look for PDF files that were modified in the last 5 minutes
if find "${OUTPATH}/${CATALOG}/${MODEL}/${EXPVER}" -type f -name "*.pdf" -mmin -5 | grep -q .; then
    echo "PDF plots were generated successfully"
else
    echo "PDF plots were not generated"
    exit 1
fi
