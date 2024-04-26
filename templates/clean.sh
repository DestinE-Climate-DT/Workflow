#!/bin/bash

# This script is used to clean up data and log files for a specific job chunk in a workflow.

# INTERFACE
# The script accepts the following parameters:
# - HPC_PROJ: The path to the current HPC project directory.
# - EXPID: The experiment ID.
# - HPCROOTDIR: The root directory of the HPC system.
# - START_DATE: The start date of the job chunk.
# - CURRENT_ARCH: The current architecture.
# - PROJDEST: The destination directory for the project.
# - FDB_PROD: The current FDB production directory.
# - FDB_DIR: The current FDB directory.
# - PRODUCTION: Flag indicating if the job is in production mode.
# - HPC_FDB_HOME: The current FDB production directory.
# - CLEAN_JOBNAME: The name of the clean job.
# - CHUNK_END_IN_DAYS: The number of days until the end of the chunk.
# - CHUNKSIZE: The size of each chunk.
# - CHUNKSIZEUNIT: The unit of the chunk size (e.g., day, month, year).
# - CHUNK: The current chunk number.
# - MODEL_NAME: The name of the model being used.
# - RAPS_EXPERIMENT: The RAPS experiment configuration.
# - CHUNK_SECOND_TO_LAST_DATE: The second-to-last date of the chunk.

# The script performs the following steps:
# 1. Sets up the necessary environment variables and directories.
# 2. Loads FDB modules and FDB5 configuration file.
# 3. Checks the model being used and loads DGOV keys.
# 4. Converts the YAML profile to a flat request file.
# 5. Purges data using the FDB purge command.
# 6. Compresses and archives job log files for the current chunk.
# 7. Compresses and archives old rundirs.

# INTERFACE

HPC_PROJ=${1:-%CURRENT_HPC_PROJECT_DIR%}
EXPID=${2:-%DEFAULT.EXPID%}
HPCROOTDIR=${3:-%HPCROOTDIR%}
START_DATE=${4:-%SDATE%}
CURRENT_ARCH=${5:-%CURRENT_ARCH%}
PROJDEST=${6:-%PROJECT.PROJECT_DESTINATION%}
FDB_PROD=${7:-%CURRENT_FDB_PROD%}
FDB_DIR=${8:-%CURRENT_FDB_DIR%}
PRODUCTION=${7:-%RUN.PRODUCTION%}
HPC_FDB_HOME=${8:-%CURRENT_FDB_PROD%}
CLEAN_JOBNAME=${9:-%JOBNAME%}
CHUNK_START_DATE=${10:-%CHUNK_START_DATE%}
CHUNK_END_IN_DAYS=${11:-%CHUNK_END_IN_DAYS%}
CHUNKSIZE=${12:-%EXPERIMENT.CHUNKSIZE%}
CHUNKSIZEUNIT=${13:-%EXPERIMENT.CHUNKSIZEUNIT%}
CHUNK=${14:-%CHUNK%}
MODEL_NAME=${15:-%MODEL.NAME%}
RAPS_EXPERIMENT=${16:-%CONFIGURATION.RAPS_EXPERIMENT%}
CHUNK_SECOND_TO_LAST_DATE=${17:-%CHUNK_SECOND_TO_LAST_DATE%}

LIBDIR="${HPCROOTDIR}/${PROJDEST}"/lib
HPC=$(echo ${CURRENT_ARCH} | cut -d- -f1)

LOG_DIR="${HPCROOTDIR}/LOG_${EXPID}"

# LOAD FDB MODULES & FDB5 CONFIG FILE
. "${LIBDIR}/${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh
load_environment_gsv ${FDB_DIR} ${EXPID}

if [ ${PRODUCTION,,} = "true" ]; then
    FDB_DIR_HEALPIX="${FDB_PROD}"
    FDB_DIR_LATLON="${FDB_PROD}/latlon"
    FDB_DIR_NATIVE="${FDB_PROD}/native"
    EXPID_FDB="0001"
    unset FDB5_CONFIG_FILE
    export FDB_HOME=${HPC_FDB_HOME}
else
    FDB_DIR_NATIVE="${FDB_DIR}/${EXPID}/fdb/NATIVE_grids"
    FDB_DIR_HEALPIX="${FDB_DIR}/${EXPID}/fdb/HEALPIX_grids"
    FDB_DIR_LATLON="${FDB_DIR}/${EXPID}/fdb/REGULARLL_grids"
    EXPID_FDB=${EXPID}
    export FDB5_CONFIG_FILE="${FDB_DIR_HEALPIX}/etc/fdb/config.yaml"
fi

# Run FDB purge
profile_file="${LIBDIR}/runscript/FDB/general_request.yaml"
FLAT_REQ_NAME="$(basename $profile_file | cut -d. -f1)_${CHUNK}_request.flat"

# Check model being used and load DGOV keys
if [ ${MODEL_NAME} == "icon" ]; then
    # Get ICON workflow configuration
    export EXPERIMENT="%SIMULATION.DATA_GOV.EXPERIMENT%"
    export ACTIVITY="%SIMULATION.DATA_GOV.ACTIVITY%"

elif [ ${MODEL_NAME%%-*} == "ifs" ]; then
    # Get RAPS configuration
    export_MULTIO_variables "${RAPS_EXPERIMENT}"
    export EXPERIMENT="${MULTIO_EXPERIMENT}"
    export ACTIVITY="${MULTIO_ACTIVITY}"
else
    echo "Error: Incorrect model name"
    exit 1
fi

# Convert YAML profile to flat request file
python "${LIBDIR}/runscript/FDB/yaml_to_flat_request.py" --file="${profile_file}" --expver="${EXPID_FDB}" --startdate="${START_DATE}" --experiment="${EXPERIMENT}" --enddate="${CHUNK_SECOND_TO_LAST_DATE}" --chunk="${CHUNK}" --model="${MODEL_NAME^^}" --activity="${ACTIVITY}" --omit-keys="time,levelist,param,levtype,type"

# Purge data using FDB purge command
fdb purge --ignore-no-data --minimum-keys class,dataset,experiment,activity,expver,model,generation,realization,stream,date "$(<${FLAT_REQ_NAME})"

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
