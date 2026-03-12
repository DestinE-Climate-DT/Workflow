#!/bin/bash

set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
MODEL=${2:-%MODEL.NAME%}
CURRENT_ARCH=${3:-%CURRENT_ARCH%}
CHUNK_START_DATE=${4:-%CHUNK_START_DATE%}
CHUNK_SECOND_TO_LAST_DATE=${5:-%CHUNK_SECOND_TO_LAST_DATE%}
FDB_HOME=${6:-%REQUEST.FDB_HOME%}
MEMBER=${7:-%MEMBER%}
MEMBER_LIST=${8:-%EXPERIMENT.MEMBERS%}
CHECK_STANDARD_COMPLIANCE=${9:-%CURRENT_CHECK_STANDARD_COMPLIANCE%}
CHECK_SPATIAL_COMPLETENESS=${10:-%CURRENT_CHECK_SPATIAL_COMPLETENESS%}
CHECK_SPATIAL_CONSISTENCY=${11:-%CURRENT_CHECK_SPATIAL_CONSISTENCY%}
CHECK_PHYSICAL_PLAUSIBILITY=${12:-%CURRENT_CHECK_PHYSICAL_PLAUSIBILITY%}
EXPERIMENT=${13:-%REQUEST.EXPERIMENT%}
ACTIVITY=${14:-%REQUEST.ACTIVITY%}
DQC_PROFILE_PATH=${15:-%CONFIGURATION.DQC_PROFILE_PATH%}
EXPVER=${16:-%REQUEST.EXPVER%}
CLASS=${17:-%REQUEST.CLASS%}
GENERATION=${18:-%REQUEST.GENERATION%}
HPC_CONTAINER_DIR=${19:-%CONFIGURATION.CONTAINER_DIR%}
GSV_VERSION=${20:-%GSV.VERSION%}
LIBDIR=${21:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${22:-%CONFIGURATION.SCRIPTDIR%}
HPC_SCRATCH=${23:-%CONFIGURATION.PROJECT_SCRATCH%}
FDB_INFO_FILE_PATH=${24:-%REQUEST.INFO_FILE_PATH%}
FDB_INFO_FILE_NAME=${25:-%REQUEST.INFO_FILE_NAME%}
CHUNK_END_DATE=${26:-%CHUNK_END_DATE%}
BASE_VERSION=${27:-%BASE.VERSION%}
JOBNAME=${28:-%JOBNAME%}
OPERATIONAL_PROJECT_SCRATCH=${29:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${30:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}

# END_HEADER

HPC=$(echo ${CURRENT_ARCH} | cut -d- -f1)

function run_DQC_prod() {
    # Run DQC script
    singularity exec --cleanenv --no-home \
        --env "FDB_HOME=${FDB_HOME}" \
        --env "EXPVER=${1}" \
        --env "DATE=${2}" \
        --env "MODEL=${3}" \
        --env "DQC_PROFILE_PATH=${4}" \
        --env "EXPERIMENT=${5}" \
        --env "ACTIVITY=${6}" \
        --env "REALIZATION=${7}" \
        --env "GENERATION=${8}" \
        --env "N_PROC=${9}" \
        --env "SCRIPTDIR=${SCRIPTDIR}" \
        --env "CHECK_STANDARD_COMPLIANCE=${10}" \
        --env "CHECK_SPATIAL_COMPLETENESS=${11}" \
        --env "CHECK_SPATIAL_CONSISTENCY=${12}" \
        --env "CHECK_PHYSICAL_PLAUSIBILITY=${13}" \
        --env "DQC_OUTPUT_FILE=${14}" \
        --bind "${HPC_SCRATCH}" \
        --bind "${DEVELOPMENT_PROJECT_SCRATCH}" \
        --bind "${OPERATIONAL_PROJECT_SCRATCH}" \
        --bind "${FDB_HOME}" \
        --bind "${DQC_OUTPUT_DIR}" \
        "$HPC_CONTAINER_DIR"/gsv/gsv_${GSV_VERSION}.sif \
        bash -c \
        ' set -xuve
          python3 ${SCRIPTDIR}/dqc/run_dqc.py --expver "${EXPVER}" --date "${DATE}" --model "${MODEL}" --profile_path "${DQC_PROFILE_PATH}" \
        --experiment "${EXPERIMENT}" --activity "${ACTIVITY}" --realization "${REALIZATION}" --generation "${GENERATION}" --n_proc "${N_PROC}" \
        --check_standard_compliance "${CHECK_STANDARD_COMPLIANCE}" --check_spatial_completeness "${CHECK_SPATIAL_COMPLETENESS}" \
        --check_spatial_consistency "${CHECK_SPATIAL_CONSISTENCY}" --check_physical_plausibility "${CHECK_PHYSICAL_PLAUSIBILITY}" \
        --dqc_output_file "${DQC_OUTPUT_FILE}" '
}

# Source libraries
source "${LIBDIR}"/"${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

# Load GSV
# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

# lib/common/util.sh (get_member_number) (auto generated comment)
MEMBER_NUMBER=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

export FDB_HOME=${FDB_HOME}

# Compute Date key
DATE="${CHUNK_START_DATE}/to/${CHUNK_SECOND_TO_LAST_DATE}"

# This should be changed to take specific profiles for each configurations

export REALIZATION=${MEMBER_NUMBER}
export N_PROC=${SLURM_JOB_CPUS_PER_NODE}

# Create directory for FDB outputs if needed
DQC_OUTPUT_DIR="${HPCROOTDIR}/dqc_output"
mkdir -p "${DQC_OUTPUT_DIR}"
export DQC_OUTPUT_DIR=${DQC_OUTPUT_DIR}

# Set path for DQC output file
DQC_OUTPUT_FILE="${DQC_OUTPUT_DIR}/${JOBNAME}_${SLURM_JOB_ID}.out"

run_DQC_prod "${EXPVER}" "${DATE}" "${MODEL,,}" "${DQC_PROFILE_PATH}" "${EXPERIMENT,,}" "${ACTIVITY,,}" \
    "${REALIZATION}" "${GENERATION}" "${N_PROC}" "${CHECK_STANDARD_COMPLIANCE}" \
    "${CHECK_SPATIAL_COMPLETENESS}" "${CHECK_SPATIAL_CONSISTENCY}" "${CHECK_PHYSICAL_PLAUSIBILITY}" \
    "${DQC_OUTPUT_FILE}"

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity
export SINGULARITY_BIND="${SCRIPTDIR},${FDB_INFO_FILE_PATH},${HPCROOTDIR}"
export SINGULARITYENV_SCRIPTDIR="${SCRIPTDIR}"
export SINGULARITYENV_FDB_INFO_FILE_NAME="${FDB_INFO_FILE_NAME}"
export SINGULARITYENV_HPCROOTDIR="${HPCROOTDIR}"
export SINGULARITYENV_EXPVER="${EXPVER}"
export SINGULARITYENV_MODEL="${MODEL}"
export SINGULARITYENV_CHUNK_END_DATE="${CHUNK_END_DATE}"
singularity exec "${HPC_CONTAINER_DIR}"/gsv/gsv_${GSV_VERSION}.sif \
    bash -c ' python3 ${SCRIPTDIR}/FDB/update_fdb_info.py \
    --file ${FDB_INFO_FILE_NAME} --data_end_date ${CHUNK_END_DATE} '
