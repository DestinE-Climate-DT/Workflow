#!/bin/bash

# INTERFACE
set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
CURRENT_ARCH=${2:-%CURRENT_ARCH%}
CHUNK=${3:-%CHUNK%}
START_DATE=${4:-%SPLIT_START_DATE%}
SPLIT_SECOND_TO_LAST_DATE=${5:-%SPLIT_SECOND_TO_LAST_DATE%}
MODEL_NAME=${6:-%MODEL.NAME%}
EXPERIMENT=${7:-%REQUEST.EXPERIMENT%}
ACTIVITY=${8:-%REQUEST.ACTIVITY%}
DQC_PROFILE_PATH=${9:-%CONFIGURATION.DQC_PROFILE_PATH%}
FDB_HOME=${10:-%REQUEST.FDB_HOME%}
EXPVER=${11:-%REQUEST.EXPVER%}
SCRATCH_DIR=${12:-%CURRENT_SCRATCH_DIR%}
HPC_CONTAINER_DIR=${13:-%CONFIGURATION.CONTAINER_DIR%}
GSV_VERSION=${14:-%GSV.VERSION%}
LIBDIR=${15:-%CONFIGURATION.LIBDIR%}
MEMBER=${16:-%MEMBER%}
MEMBER_LIST=${17:-%EXPERIMENT.MEMBERS%}
GENERATION=${18:-%REQUEST.GENERATION%}
SCRIPTDIR=${19:-%CONFIGURATION.SCRIPTDIR%}
FDB_PROD=${20:-%CURRENT_FDB_PROD%}
DATABRIDGE_FDB_HOME=${21:-%CURRENT_DATABRIDGE_FDB_HOME%}
FDB_INFO_FILE_PATH=${22:-%REQUEST.INFO_FILE_PATH%}
FDB_INFO_FILE_NAME=${23:-%REQUEST.INFO_FILE_NAME%}
SPLIT_FIRST=${24:-%SPLIT_FIRST%}
CHUNK_SECOND_TO_LAST_DATE=${25:-%CHUNK_SECOND_TO_LAST_DATE%}
SPLITS=${26:-%SPLITS%}
EXPID=${27:-%DEFAULT.EXPID%}
SIMULATION_START_DATE=${28:-%SDATE%}
SPLIT_END_DATE=${29:-%SPLIT_END_DATE%}

# END_HEADER

HPC=$(echo ${CURRENT_ARCH} | cut -d- -f1)

# LOAD FDB MODULES & FDB5 CONFIG FILE
. "${LIBDIR}/${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

export METKIT_PARAM_RAW=1

FDB_DIR_HEALPIX="${FDB_HOME}"
FDB_DIR_LATLON="${FDB_HOME}/latlon"
FDB_DIR_NATIVE="${FDB_HOME}/native"

export FDB_HOME=${FDB_DIR_HEALPIX}

if [ -d "${DQC_PROFILE_PATH}" ]; then
    echo "Transfering profiles in ${DQC_PROFILE_PATH}"
else
    echo "ERROR: The path ${DQC_PROFILE_PATH} does not exist."
    exit 1
fi

TRANSFER_REQUESTS_PATH=${HPCROOTDIR}/transfer_requests
mkdir -p ${TRANSFER_REQUESTS_PATH}
cd ${TRANSFER_REQUESTS_PATH}

# lib/common/util.sh (get_member_number) (auto generated comment)
REALIZATION=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

# Call the function and assign the result to TRANSFER_MONTHLY
# lib/common/util.sh (enable_process_monthly) (auto generated comment)
TRANSFER_MONTHLY=$(enable_process_monthly "$START_DATE" "$SPLIT_END_DATE")

for profile_file in "${DQC_PROFILE_PATH}"/*.yaml; do

    if [[ "$profile_file" == *monthly* ]] && [[ "$TRANSFER_MONTHLY" == false ]]; then
        # Skip the monthly profile if it is not the first chunk
        continue
    fi
    # Run FDB purge
    FLAT_REQ_NAME="$(basename $profile_file | cut -d. -f1)_${CHUNK}_request.flat"

    CLEAN_DIR=${HPCROOTDIR}/clean_requests/
    mkdir -p ${CLEAN_DIR}

    export FDB_HOME=${FDB_DIR_HEALPIX}

    profile_name=$(basename "$profile_file" | cut -d. -f1)
    BASE_NAME=${profile_name}_sdate_${START_DATE}_endate_${SPLIT_SECOND_TO_LAST_DATE}_real_${REALIZATION}
    GRIB_FILE_NAME="${BASE_NAME}.grb"
    MARS_REQUEST_NAME="${BASE_NAME}.mars"

    singularity exec --cleanenv --no-home \
        --env "FDB_HOME=$(realpath ${FDB_HOME})" \
        --env "EXPVER=${EXPVER}" \
        --env "START_DATE=${START_DATE}" \
        --env "CHUNK=${CHUNK}" \
        --env "SECOND_TO_LAST_DATE=${SPLIT_SECOND_TO_LAST_DATE}" \
        --env "EXPERIMENT=${EXPERIMENT}" \
        --env "MODEL_NAME=${MODEL_NAME}" \
        --env "ACTIVITY=${ACTIVITY}" \
        --env "REALIZATION=${REALIZATION}" \
        --env "GENERATION=${GENERATION}" \
        --env "profile_file=${profile_file}" \
        --env "LIBDIR=${LIBDIR}" \
        --env "GRIB_FILE_NAME=${GRIB_FILE_NAME}" \
        --env "SCRIPTDIR=$(realpath ${SCRIPTDIR})" \
        --env "BASE_NAME=${BASE_NAME}" \
        --env "FLAT_REQ_NAME=${FLAT_REQ_NAME}" \
        --env "CHUNK_SECOND_TO_LAST_DATE=${CHUNK_SECOND_TO_LAST_DATE}" \
        --env "CLEAN_DIR=${CLEAN_DIR}" \
        --env "TRANSFER_REQUESTS_PATH=${TRANSFER_REQUESTS_PATH}" \
        --env "TRANSFER_MONTHLY=${TRANSFER_MONTHLY}" \
        --bind "$(realpath $PWD)" \
        --bind "$(realpath ${SCRATCH_DIR})" \
        --bind "$(realpath ${LIBDIR}/common)" \
        --bind "$(realpath ${SCRIPTDIR}/FDB)" \
        --bind "$(realpath ${DQC_PROFILE_PATH})" \
        --bind "$(realpath ${FDB_HOME})" \
        --bind "$(realpath ${CLEAN_DIR})" \
        "$HPC_CONTAINER_DIR"/gsv/gsv_${GSV_VERSION}.sif \
        bash -c \
        '
        set -xuve
        # Convert YAML profile to flat request file
        MINIMUM_KEYS="class,dataset,experiment,activity,expver,model,generation,realization,stream"
        OMIT_KEYS="time,levelist,param,levtype,type,resolution"
        if [[ "$profile_file" == *monthly* ]]; then
            MINIMUM_KEYS+=",year"
            OMIT_KEYS+=",month"
        else
            MINIMUM_KEYS+=",date"
        fi
        cd ${CLEAN_DIR}
        python3 "${SCRIPTDIR}/FDB/yaml_to_flat_request.py" \
        --file="${profile_file}" --expver="${EXPVER}" --startdate="${START_DATE}" \
        --experiment="${EXPERIMENT}" --generation="${GENERATION}" \
        --realization="${REALIZATION}" --enddate="${SECOND_TO_LAST_DATE}" \
        --chunk="${CHUNK}" --model="${MODEL_NAME^^}" --activity="${ACTIVITY}" \
        --request_name="${FLAT_REQ_NAME}" --omit-keys="${OMIT_KEYS}" \
        # Purge data using FDB purge command
        fdb purge --ignore-no-data --doit --minimum-keys ${MINIMUM_KEYS} "$(<${FLAT_REQ_NAME})" > /dev/null

        cd ${TRANSFER_REQUESTS_PATH}
        . "${LIBDIR}"/common/util.sh
# lib/common/util.sh (prepare_transfer) (auto generated comment)
        prepare_transfer
        '
    # Write extracted GRIB data in the DataBridge using the MARS client, if it was not completed before
    if [ ! -f "${BASE_NAME}_COMPLETED" ]; then
        export FDB_HOME=${DATABRIDGE_FDB_HOME}
        if [ -s ${GRIB_FILE_NAME} ]; then
            "${FDB_PROD}"/../bin/mars ${MARS_REQUEST_NAME}
            echo "ARCHIVE OF ${BASE_NAME} SUCCESSFUL"
            touch "${BASE_NAME}_COMPLETED"
        else
            echo "ERROR: ARCHIVE OF ${BASE_NAME} NOT SUCCESSFUL"
            exit 1
        fi
        rm "${GRIB_FILE_NAME}"
    fi
done

export SINGULARITY_BIND="${SCRIPTDIR},${FDB_INFO_FILE_PATH},${HPCROOTDIR}"
export SINGULARITYENV_SCRIPTDIR="${SCRIPTDIR}"
export SINGULARITYENV_FDB_INFO_FILE_NAME="${FDB_INFO_FILE_NAME}"
export SINGULARITYENV_HPCROOTDIR="${HPCROOTDIR}"
export SINGULARITYENV_EXPVER="${EXPVER}"
export SINGULARITYENV_CHUNK="${CHUNK}"
export SINGULARITYENV_SPLIT_SECOND_TO_LAST_DATE="${SPLIT_SECOND_TO_LAST_DATE}"
export SINGULARITYENV_START_DATE="${START_DATE}"
export SINGULARITYENV_SPLIT_FIRST="${SPLIT_FIRST}"
export SINGULARITYENV_CHUNK_SECOND_TO_LAST_DATE="${CHUNK_SECOND_TO_LAST_DATE}"
export SINGULARITYENV_SPLIT_END_DATE="${SPLIT_END_DATE}"

# Only update the YAML file when a full month is transfered
# We check if the current chunk was completely transfered (number of splits - 1 that is the current split)

LOGS_FOLDER="${HPCROOTDIR}/LOG_${EXPID}"

# Count the number of _COMPLETED files in the previous chunk
# They follow the pattern t039_19900101_fc0_1_31_TRANSFER_COMPLETED
# And are located in the LOGS_FOLDER

NUMBER_OF_COMPLETED_SPLITS=$(find "${LOGS_FOLDER}" -type f -name "${EXPID}_${SIMULATION_START_DATE}_${MEMBER}_${CHUNK}_*_TRANSFER_COMPLETED" | wc -l)

if [ "$((NUMBER_OF_COMPLETED_SPLITS + 1))" == "${SPLITS}" ]; then
    singularity exec "${HPC_CONTAINER_DIR}"/gsv/gsv_${GSV_VERSION}.sif \
        bash -c ' set -xuve
            if [ "${CHUNK}" == "1" ] && [ "${SPLIT_FIRST}" == "TRUE" ]; then
                python3 ${SCRIPTDIR}/FDB/update_fdb_info.py --file ${FDB_INFO_FILE_NAME} \
                --bridge_expver ${EXPVER} --bridge_start_date ${START_DATE}
            else
                python3 ${SCRIPTDIR}/FDB/update_fdb_info.py --file ${FDB_INFO_FILE_NAME} \
                --bridge_expver ${EXPVER} --bridge_end_date ${SPLIT_END_DATE}
            fi
        '
fi
