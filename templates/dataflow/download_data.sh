#!/bin/bash
#

# This step downloads data from the Data Bridge.

set -xuve

# HEADER

CURRENT_ARCH=${1:-%CURRENT_ARCH%}
EXPID=${2:-%DEFAULT.EXPID%}
HPC_CONTAINER_DIR=${3:-%CURRENT_CONTAINER_DIR%}
LIBDIR=${4:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${5:-%CONFIGURATION.SCRIPTDIR%}
GSV_VERSION=${6:-%GSV.VERSION%}
FDB_CONFIG_GATEWAY=${7:-%CONFIGURATION.FDB_CONFIG_GATEWAY%}
CONTAINER_COMMAND=${8:-%CURRENT_CONTAINER_COMMAND%}
CURRENT_ROOTDIR=${9:-%CURRENT_ROOTDIR%}
FDB_COPY_BIN=${10:-%CURRENT_FDB_COPY_BIN%}
FDB_CONFIG_DATABRIDGE=${11:-%CONFIGURATION.FDB_CONFIG_DATABRIDGE%}
FDB_CONFIG_HPC=${12:-%CONFIGURATION.FDB_CONFIG_HPC%}
YEAR=${13:-%SPLIT_START_YEAR%}
MONTH=${14:-%SPLIT_START_MONTH%}
DAY=${15:-%SPLIT_START_DAY%}
SCRATCH_DIR=${16:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${17:-%CURRENT_HPC_PROJECT_ROOT%}
JOBNAME=${18:-%JOBNAME%}
EXPVER=${19:-%REQUEST.EXPVER%}
START_DATE=${20:-%SPLIT_START_DATE%}
EXPERIMENT=${21:-%REQUEST.EXPERIMENT%}
SECOND_TO_LAST_DATE=${22:-%SPLIT_SECOND_TO_LAST_DATE%}
MODEL_NAME=${23:-%REQUEST.MODEL%}
ACTIVITY=${24:-%REQUEST.ACTIVITY%}
GENERATION=${25:-%REQUEST.GENERATION%}
REALIZATION=${26:-%REQUEST.REALIZATION%}
FDB_LIST_BIN=${27:-%CURRENT_FDB_LIST_BIN%}
start_date=${28:-%SPLIT_START_DATE%}
chunk_start_date=${29:-%CHUNK_START_DATE%}
chunk_end_date=${30:-%CHUNK_SECOND_TO_LAST_DATE%}
splits=${31:-%SPLITS%}
split=${32:-%SPLIT%}
split_second_to_last_date=${33:-%SPLIT_SECOND_TO_LAST_DATE%}
# END_HEADER
# THE FOLLOWING LINES ARE DUE TO AN Autosubmit bug: https://github.com/BSC-ES/autosubmit/issues/2866

if [ "$split" -eq "$splits" ]; then
    # Last split in chunk → end at the chunk boundary
    end_date=$chunk_end_date
else
    # Regular split → end at SECOND_TO_LAST_DATE
    end_date=$split_second_to_last_date
fi

# END_HEADER

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture
LOGDIR=${CURRENT_ROOTDIR}/LOG_${EXPID}

REQUESTS_DIR=${CURRENT_ROOTDIR}/requests/generated
JOBNAME_WITHOUT_EXPID=$(echo ${JOBNAME} | sed 's/^[^_]*_//')

# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh
source "${LIBDIR}"/"${HPC}-TRANSFER"/config.sh
source "${LIBDIR}"/common/util.sh

function download_data() {
    base_dir=${1}

    ADDITIONAL_BINDINGS=("$(realpath $PWD)" ${base_dir} ${FDB_CONFIG_GATEWAY})
    # lib/common/util.sh (setup_additional_binds) (auto generated comment)
    bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")

    ${CONTAINER_COMMAND} exec --cleanenv --no-home \
        --env "SCRIPTDIR=${SCRIPTDIR}" \
        --env "base_dir=${base_dir}" \
        --env "jobname=${JOBNAME_WITHOUT_EXPID}" \
        --env "EXPVER=${EXPVER}" \
        --env "START_DATE=${START_DATE}" \
        --env "EXPERIMENT=${EXPERIMENT}" \
        --env "SECOND_TO_LAST_DATE=${SECOND_TO_LAST_DATE}" \
        --env "MODEL_NAME=${MODEL_NAME}" \
        --env "ACTIVITY=${ACTIVITY}" \
        --env "GENERATION=${GENERATION}" \
        --env "REALIZATION=${REALIZATION}" \
        --env FDB_CONFIG_GATEWAY=${FDB_CONFIG_GATEWAY} \
        ${bindings} \
        "$HPC_CONTAINER_DIR"/gsv/gsv_${GSV_VERSION}.sif \
        bash -c \
        '
        set -xuve

        mkdir -p ${base_dir}/requests/flat/
        for request in ${base_dir}/*.yaml; do
            python3 "${SCRIPTDIR}/FDB/preprocess_requests_dataflow.py" \
                    --file="$request" \
                    --omit-keys grid,method,area \
                    --output-dir="${base_dir}/requests/formatted" \
                    --jobname=${jobname}
        done
        for request in ${base_dir}/requests/formatted/*.yaml; do
            echo "Processing request: $request"
			# Count the messages that should be in the FDB if the data is downloaded already
			EXPECTED_MESSAGES=$(python3 "${SCRIPTDIR}/FDB/count_expected_messages.py" \
				--file="$request" --expver="${EXPVER}" --startdate="${START_DATE}" \
				--experiment="${EXPERIMENT,,}" --enddate="${SECOND_TO_LAST_DATE}" \
				--model="${MODEL_NAME}" --activity="${ACTIVITY,,}" \
				--generation="${GENERATION}" --realization="${REALIZATION}")

            filename=$(basename "$request")
            variable=${filename%%_*}
			BASE_NAME=request_${jobname}_${variable}
            FLAT_REQ_NAME="${BASE_NAME}.flat"
			FLAT_REQ="${base_dir}/requests/flat/${FLAT_REQ_NAME}"
            # Convert YAML to flat request
            python3 "${SCRIPTDIR}/FDB/yaml_to_flat_request.py" \
                --file="$request" --request_name="${FLAT_REQ}"
			echo ${EXPECTED_MESSAGES} > ${FLAT_REQ}_expected.log
		done
        '

    jobname=${JOBNAME_WITHOUT_EXPID}
    for FLAT_REQ_NAME in ${base_dir}/requests/flat/request_${jobname}_*.flat; do
        FDB_LIST_OUTPUT="${FLAT_REQ_NAME}_list.log"
        ${FDB_LIST_BIN} --raw --porcelain --config=${FDB_CONFIG_GATEWAY} "$(<${FLAT_REQ_NAME})" >"${FDB_LIST_OUTPUT}"
        LISTED_MESSAGES=$(cat ${FDB_LIST_OUTPUT} | wc -l)

        EXPECTED_MESSAGES=$(<${FLAT_REQ_NAME}_expected.log)

        # Download the data when are less messages than expected
        if [ "$LISTED_MESSAGES" -lt "$EXPECTED_MESSAGES" ]; then
            echo "Not all messages found in HPC"
            echo "Downloading messages for ${FLAT_REQ_NAME}"
            ${FDB_COPY_BIN} --sort --from-list \
                --source ${FDB_CONFIG_DATABRIDGE} \
                --target ${FDB_CONFIG_GATEWAY} \
                "$(<${FLAT_REQ_NAME})"
        else
            echo "All messages found in HPC"
        fi
    done

}

# load singularity
# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

start_date_formatted=$(echo "${start_date}" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')
chunk_start_date_formatted=$(echo "${chunk_start_date}" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')
# convert CHUNK_END_DATE (YYYYMMDD) to YYYY-MM-DD format
end_date_formatted=$(echo "${end_date}" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')
chunk_end_date_formatted=$(echo "${chunk_end_date}" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')

# determine request folder depending on whether start and end dates differ
if [[ "${chunk_start_date_formatted}" == "${chunk_end_date_formatted}" ]]; then
    date="${chunk_start_date_formatted}"
else
    date="${start_date_formatted}_to_${end_date_formatted}"
fi

echo "Using date: ${date}"

date_directory=${REQUESTS_DIR}/${date}

download_data "${date_directory}"
