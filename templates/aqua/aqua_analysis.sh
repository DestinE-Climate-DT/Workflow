#!/bin/bash

set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
EXPID=${3:-%DEFAULT.EXPID%}
HPC_PROJECT=${4:-%CONFIGURATION.HPC_PROJECT_DIR%}
CONTAINER_VERSION=${5:-%AQUA.CONTAINER_VERSION%}
MODEL=${6:-%REQUEST.MODEL_NAME_UPPER%}
RESOLUTION=${7:-%MODEL.RESOLUTION%}
EXPVER=${8:-%REQUEST.EXPVER%}
EXPERIMENT_NAME=${9:-%AQUA.EXPERIMENT_NAME%}
CATALOG=${10:-%HPCCATALOG_NAME%}
APP_OUTPATH=${11:-%APP.OUTPATH%}
CURRENT_ARCH=${12:-%CURRENT_ARCH%}
HPC_SCRATCH=${13:-%CONFIGURATION.PROJECT_SCRATCH%}
AQUA_SEARCH_TIME=${14:-%AQUA.SEARCH_TIME%}
RUN_LRA_GENERATOR=${15:-%CONFIGURATION.ADDITIONAL_JOBS.LRA%}
PREV_AQUA_EXP=${16:-%AQUA.PREV_EXP%}
DATA_DIR=${17:-%CURRENT_DATA_DIR%}
HPC_CONTAINER_DIR=${18:-%CURRENT_CONTAINER_DIR%}
OPERATIONAL_PROJECT_SCRATCH=${19:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${20:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}
HPC_PROJECT_ROOT=${21:-%CURRENT_HPC_PROJECT_ROOT%}
SCRATCH_DIR=${22:-%CURRENT_SCRATCH_DIR%}
LOCAL_DIR=${23:-%CURRENT_LOCAL_DIR%}
MEMBER=${24:-%MEMBER%}
MEMBER_LIST=${25:-%EXPERIMENT.MEMBERS%}
AQUA_CONFIG=${26:-%AQUA.INSTALL_DIR%}
CARTOPY_DATA_DIR=${27:-%AQUA.CARTOPY_DATA_DIR%}
AQUA_ANALYSIS_CONFIG=${28:-%AQUA.ANALYSIS_CONFIG%}
SOURCE=${29:-%AQUA.CATALOG_SOURCE%}

# END_HEADER

AQUA="/app/AQUA"
MODEL_AND_RES="${MODEL}-${RESOLUTION}"

AQUA_CONTAINER="${HPC_CONTAINER_DIR}/aqua/aqua_${CONTAINER_VERSION}.sif"

OUTPATH=${APP_OUTPATH}/aqua-analysis

# if LRA generator was skipped and a previous AQUA experiment name was entered
# we must be analyzing data from an older experiment
if [ "${RUN_LRA_GENERATOR,,}" != "true" ] && [ -n "${PREV_AQUA_EXP}" ]; then
    EXPVER="${PREV_AQUA_EXP}"
    EXPERIMENT_NAME="${PREV_AQUA_EXP}"
fi

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib    # Path to the lib directory
HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture
# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh

# lib/common/util.sh (get_member_number) (auto generated comment)
REALIZATION=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity
ADDITIONAL_BINDINGS=(
    "$(realpath ${DEVELOPMENT_PROJECT_SCRATCH})" "${DEVELOPMENT_PROJECT_SCRATCH}"
    "$(realpath ${OPERATIONAL_PROJECT_SCRATCH})" "${OPERATIONAL_PROJECT_SCRATCH}"
    "$(realpath ${HPC_PROJECT})" "${DATA_DIR}" "$(realpath ${DATA_DIR})"
)
# lib/common/util.sh (setup_additional_binds) (auto generated comment)
bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")

singularity exec \
    --cleanenv \
    --env PYTHONPATH=/opt/conda/lib/python3.10/site-packages \
    --env ESMFMKFILE=/opt/conda/lib/esmf.mk \
    --env PYTHONPATH=$AQUA \
    --env AQUA=$AQUA \
    --env AQUA_CONFIG=$AQUA_CONFIG \
    --env MODEL_AND_RES="${MODEL_AND_RES}" \
    --env EXPVER=$EXPVER \
    --env EXPERIMENT_NAME=$EXPERIMENT_NAME \
    --env SOURCE=$SOURCE \
    --env OUTPATH=$OUTPATH \
    --env CATALOG=$CATALOG \
    --env REALIZATION=$REALIZATION \
    --env AQUA_ANALYSIS_CONFIG=$AQUA_ANALYSIS_CONFIG \
    ${bindings} \
    --no-mount /etc/localtime \
    --env CARTOPY_DATA_DIR=$CARTOPY_DATA_DIR \
    $AQUA_CONTAINER \
    bash -c \
    "
    aqua analysis --loglevel debug --model $MODEL_AND_RES --exp $EXPERIMENT_NAME --source $SOURCE --outputdir $OUTPATH --catalog $CATALOG --realization r$REALIZATION --config $AQUA_ANALYSIS_CONFIG --parallel
    "

# Check if the PDF plots were generated or not (structure is ${OUTPATH}/${CATALOG}/${MODEL}/${EXPVER}/${diagnostic}/*.pdf)
# Look for PDF files that were modified in the last 5 minutes
if find "${OUTPATH}/${CATALOG}/${MODEL_AND_RES}/${EXPERIMENT_NAME}/r${REALIZATION}" -type f -name "*.pdf" -mmin -${AQUA_SEARCH_TIME} \
    -print -quit | read -r _; then
    echo "PDF plots were generated successfully"
else
    echo "PDF plots were not generated"
    exit 1
fi
