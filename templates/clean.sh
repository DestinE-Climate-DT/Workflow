#!/bin/bash

# This script is used to clean up data and log files for a specific job chunk in a workflow.

# HEADER

HPC_PROJECT=${1:-%CONFIGURATION.HPC_PROJECT_DIR%}
EXPID=${2:-%DEFAULT.EXPID%}
HPCROOTDIR=${3:-%HPCROOTDIR%}
START_DATE=${4:-%SDATE%}
CURRENT_ARCH=${5:-%CURRENT_ARCH%}
FDB_HOME=${6:-%REQUEST.FDB_HOME%}
CLEAN_JOBNAME=${7:-%JOBNAME%}
CHUNK_START_DATE=${8:-%CHUNK_START_DATE%}
CHUNK_END_IN_DAYS=${9:-%CHUNK_END_IN_DAYS%}
CHUNKSIZE=${10:-%EXPERIMENT.CHUNKSIZE%}
CHUNKSIZEUNIT=${11:-%EXPERIMENT.CHUNKSIZEUNIT%}
CHUNK=${12:-%CHUNK%}
MODEL_NAME=${13:-%MODEL.NAME%}
CHUNK_SECOND_TO_LAST_DATE=${14:-%CHUNK_SECOND_TO_LAST_DATE%}
EXPERIMENT=${15:-%REQUEST.EXPERIMENT%}
ACTIVITY=${16:-%REQUEST.ACTIVITY%}
EXPVER=${17:-%REQUEST.EXPVER%}
GENERATION=${18:-%REQUEST.GENERATION%}
SCRATCH_DIR=${19:-%CURRENT_SCRATCH_DIR%}
HPC_CONTAINER_DIR=${20:-%CONFIGURATION.CONTAINER_DIR%}
GSV_VERSION=${21:-%GSV.VERSION%}
LIBDIR=${22:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${23:-%CONFIGURATION.SCRIPTDIR%}
MEMBER=${24:-%MEMBER%}
MEMBER_LIST=${25:-%EXPERIMENT.MEMBERS%}

# END_HEADER

set -xuve

HPC=$(echo ${CURRENT_ARCH} | cut -d- -f1)

LOG_DIR="${HPCROOTDIR}/LOG_${EXPID}"

# LOAD FDB MODULES & FDB5 CONFIG FILE
. "${LIBDIR}/${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

# lib/common/util.sh (get_member_number) (auto generated comment)
MEMBER_NUMBER=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

# Define paths for the request
profile_file="${SCRIPTDIR}/FDB/general_request.yaml"
FLAT_REQ_NAME="$(basename $profile_file | cut -d. -f1)_${CHUNK}_${MEMBER_NUMBER}_request.flat"

CLEAN_DIR=${HPCROOTDIR}/clean_requests/
mkdir -p ${CLEAN_DIR}

export FDB_HOME=${FDB_HOME}

# Convert YAML profile to flat request file
# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity
singularity exec --cleanenv --no-home \
    --env "FDB_HOME=$(realpath ${FDB_HOME})" \
    --env "SCRIPTDIR=${SCRIPTDIR}" \
    --env "EXPVER=${EXPVER}" \
    --env "CHUNK_START_DATE=${CHUNK_START_DATE}" \
    --env "CHUNK_SECOND_TO_LAST_DATE=${CHUNK_SECOND_TO_LAST_DATE}" \
    --env "EXPERIMENT=${EXPERIMENT}" \
    --env "CHUNK=${CHUNK}" \
    --env "MODEL_NAME=${MODEL_NAME}" \
    --env "ACTIVITY=${ACTIVITY}" \
    --env "GENERATION=${GENERATION}" \
    --env "REALIZATION=${MEMBER_NUMBER}" \
    --env "FLAT_REQ_NAME=${FLAT_REQ_NAME}" \
    --env "profile_file=${profile_file}" \
    --env "CLEAN_DIR=${CLEAN_DIR}" \
    --bind "$(realpath ${HPCROOTDIR})" \
    --bind "$(realpath ${FDB_HOME})" \
    --bind "$(realpath ${SCRATCH_DIR})" \
    --bind "$(realpath ${CLEAN_DIR})" \
    "${HPC_CONTAINER_DIR}"/gsv/gsv_${GSV_VERSION}.sif \
    bash -c \
    '
    set -xuve
    cd ${CLEAN_DIR}
    python3 "${SCRIPTDIR}/FDB/yaml_to_flat_request.py" \
    --file="${profile_file}" --expver="${EXPVER}" --startdate="${CHUNK_START_DATE}" \
    --experiment="${EXPERIMENT}" --generation="${GENERATION}" \
    --realization="${REALIZATION}" --enddate="${CHUNK_SECOND_TO_LAST_DATE}" \
    --chunk="${CHUNK}" --model="${MODEL_NAME^^}" --activity="${ACTIVITY}" \
    --request_name="${FLAT_REQ_NAME}" --omit-keys="time,levelist,param,levtype,type"
    # Purge data using FDB purge command
    fdb purge --doit --ignore-no-data --minimum-keys class,dataset,experiment,activity,expver,model,generation,realization,stream,date "$(<${FLAT_REQ_NAME})"
    '

# Compress and archive job log files for the current chunk
SIM_JOBNAME=${CLEAN_JOBNAME//CLEAN/SIM}
timestamp=$(date +"%Y%m%d%H%M%S")
tar -czf "${LOG_DIR}/${SIM_JOBNAME}_${timestamp}.tar.gz" "${LOG_DIR}/${SIM_JOBNAME}"*
for file in "${LOG_DIR}/${SIM_JOBNAME}"*; do
    if [ -f "$file" ] && [[ "$file" != *.tar.gz ]] && [[ "$file" != *COMPLETED* ]]; then
        rm "$file"
    fi
done

# Compress and archive old rundirs
if [ "${CHUNKSIZEUNIT}" == "month" ] || [ "${CHUNKSIZEUNIT}" == "year" ]; then
    runlength=${CHUNK_END_IN_DAYS}
    CHUNKSIZEUNIT=day
else
    runlength=$((CHUNK * CHUNKSIZE))
fi

find_results=$(find "${HPCROOTDIR}" -type d \( -name "h$(($runlength * 24))*${SIM_JOBNAME}*" -o -name "run_${CHUNK_START_DATE}*" \) -print)
while IFS= read -r rundir; do
    if [ -n "${rundir}" ]; then
        tar -czf "${rundir}.tar.gz" "${rundir}" && rm -rf "${rundir}"
    fi
done <<<"$find_results"
