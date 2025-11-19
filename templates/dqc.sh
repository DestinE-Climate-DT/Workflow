#!/bin/bash

set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
MODEL=${2:-%REQUEST.MODEL%}
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
CHECK_NEGATIVE_SPACE=${13:-%CURRENT_CHECK_NEGATIVE_SPACE%}
EXPERIMENT=${14:-%REQUEST.EXPERIMENT%}
ACTIVITY=${15:-%REQUEST.ACTIVITY%}
DQC_PROFILE_PATH=${16:-%CONFIGURATION.DQC_PROFILE_PATH%}
EXPVER=${17:-%REQUEST.EXPVER%}
CLASS=${18:-%REQUEST.CLASS%}
GENERATION=${19:-%REQUEST.GENERATION%}
HPC_CONTAINER_DIR=${20:-%CURRENT_CONTAINER_DIR%}
GSV_VERSION=${21:-%GSV.VERSION%}
LIBDIR=${22:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${23:-%CONFIGURATION.SCRIPTDIR%}
HPC_SCRATCH=${24:-%CONFIGURATION.PROJECT_SCRATCH%}
FDB_INFO_FILE_PATH=${25:-%REQUEST.INFO_FILE_PATH%}
FDB_INFO_FILE_NAME=${26:-%REQUEST.INFO_FILE_NAME%}
CHUNK_END_DATE=${27:-%CHUNK_END_DATE%}
BASE_VERSION=${28:-%BASE.VERSION%}
JOBNAME=${29:-%JOBNAME%}
OPERATIONAL_PROJECT_SCRATCH=${30:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${31:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}
LOCAL_DIR=${32:-%CURRENT_LOCAL_DIR%}
SCRATCH_DIR=${33:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${34:-%CURRENT_HPC_PROJECT_ROOT%}
PROJECT_ROOTDIR=${35:-%CONFIGURATION.PROJECT_ROOTDIR%}
CREATE_FDB_INFO_FILE=${36:-%CONFIGURATION.CREATE_FDB_INFO_FILE%}

# END_HEADER

HPC=$(echo ${CURRENT_ARCH} | cut -d- -f1)

function run_DQC_prod() {
    # Run DQC script
    singularity exec --cleanenv --no-home \
        --env "FDB_HOME=$(realpath ${FDB_HOME})" \
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
        ${bindings} \
        "$HPC_CONTAINER_DIR"/gsv/gsv_${GSV_VERSION}.sif \
        bash -c \
        ' set -xuve
          python3 ${SCRIPTDIR}/dqc/run_dqc.py --expver "${EXPVER}" --date "${DATE}" --model "${MODEL}" --profile_path "${DQC_PROFILE_PATH}" \
        --experiment "${EXPERIMENT}" --activity "${ACTIVITY}" --realization "${REALIZATION}" --generation "${GENERATION}" --n_proc "${N_PROC}" \
        --check_standard_compliance "${CHECK_STANDARD_COMPLIANCE}" --check_spatial_completeness "${CHECK_SPATIAL_COMPLETENESS}" \
        --check_spatial_consistency "${CHECK_SPATIAL_CONSISTENCY}" --check_physical_plausibility "${CHECK_PHYSICAL_PLAUSIBILITY}" \
        --dqc_output_file "${DQC_OUTPUT_FILE}" '
}

function run_negative_space_checker() {
    # Run DQC script
    singularity exec --cleanenv --no-home \
        --env "FDB_HOME=$(realpath ${FDB_HOME})" \
        --env "EXPVER=${1}" \
        --env "CHUNK_START_DATE=${2}" \
        --env "MODEL=${3}" \
        --env "DQC_PROFILE_PATH=${4}" \
        --env "EXPERIMENT=${5}" \
        --env "ACTIVITY=${6}" \
        --env "REALIZATION=${7}" \
        --env "GENERATION=${8}" \
        --env "CHUNK_SECOND_TO_LAST_DATE=${9}" \
        --env "SCRIPTDIR=${SCRIPTDIR}" \
        --env "PROJECT_ROOTDIR=${PROJECT_ROOTDIR}" \
        --env "DQC_OUTPUT_DIR=${10}" \
        ${bindings} \
        "$HPC_CONTAINER_DIR"/gsv/gsv_${GSV_VERSION}.sif \
        bash -c \
        ' set -xuve
          CHECK_FAILED=0
          MESSAGE_COUNT_JSON=$(PYTHONPATH=${PROJECT_ROOTDIR}:${PYTHONPATH} python3 ${SCRIPTDIR}/FDB/count_messages_by_levtype.py --profiles-path "${DQC_PROFILE_PATH}" \
        --expver "${EXPVER}" --experiment ${EXPERIMENT} --activity ${ACTIVITY} --realization ${REALIZATION} \
        --generation ${GENERATION} --model ${MODEL} --startdate ${CHUNK_START_DATE} --enddate ${CHUNK_SECOND_TO_LAST_DATE})
	NEGATIVE_CHECK_DIR="${DQC_OUTPUT_DIR}/negative_check_files"
	mkdir -p ${NEGATIVE_CHECK_DIR}
	# Use generic request files instead of relying on run-generated profiles
	sample_file_clte=${SCRIPTDIR}/FDB/general_request_clte.yaml
	sample_file_clmn=${SCRIPTDIR}/FDB/general_request_clmn.yaml

	printf "\n"
	echo "### Negative Space Checker report ###"
	for levtype in sfc pl o2d o3d hl sol; do
		# Check clte messages
		EXPECTED_MESSAGES=$(python3 -c "import json,sys; data=json.loads(sys.stdin.read()); print(data[\"clte\"].get(\"$levtype\", 0))" <<< "${MESSAGE_COUNT_JSON}")

		FLAT_REQ_NAME="${NEGATIVE_CHECK_DIR}/${levtype}_clte.flat"
                python3 "${SCRIPTDIR}/FDB/yaml_to_flat_request.py" --file="${sample_file_clte}" \
                  --expver="${EXPVER}" --startdate="${CHUNK_START_DATE}" --experiment="${EXPERIMENT,,}" \
                  --enddate="${CHUNK_SECOND_TO_LAST_DATE}" --model="${MODEL}" \
                  --activity="${ACTIVITY,,}" --generation="${GENERATION}" --realization="${REALIZATION}" \
                  --omit-keys "time,levelist,param,resolution,levtype" --request_name="${FLAT_REQ_NAME}"

                FDB_LIST_OUTPUT="${NEGATIVE_CHECK_DIR}/${levtype}_clte_list.log"
                fdb-list --raw --porcelain "$(<${FLAT_REQ_NAME}),levtype=${levtype}" >"${FDB_LIST_OUTPUT}"
                LISTED_MESSAGES=$(cat ${FDB_LIST_OUTPUT} | wc -l)
		if [ ${LISTED_MESSAGES} != ${EXPECTED_MESSAGES}  ]; then
			result="NEGATIVE CHECKER FAILED: Unexpected number of ${levtype} clte messages. Expected: ${EXPECTED_MESSAGES}, FOUND: ${LISTED_MESSAGES}"
			echo ${result} | sed -e "s/FAILED/\x1b[1;31mFAILED\x1b[0m/"
			CHECK_FAILED=1
		else
			result="NEGATIVE CHECKER PASSED: Correct number of messages for levtype: ${levtype} clte: ${LISTED_MESSAGES}"
			echo ${result} | sed -e "s/PASSED/\x1b[1;32mPASSED\x1b[0m/"
		fi

		# Check clmn messages
                EXPECTED_MESSAGES=$(python3 -c "import json,sys; data=json.loads(sys.stdin.read()); print(data[\"clmn\"].get(\"$levtype\", 0))" <<< "${MESSAGE_COUNT_JSON}")

                FLAT_REQ_NAME="${NEGATIVE_CHECK_DIR}/${levtype}_clmn.flat"
                python3 "${SCRIPTDIR}/FDB/yaml_to_flat_request.py" --file="${sample_file_clmn}" \
                  --expver="${EXPVER}" --startdate="${CHUNK_START_DATE}" --experiment="${EXPERIMENT,,}" \
                  --enddate="${CHUNK_SECOND_TO_LAST_DATE}" --model="${MODEL}" \
                  --activity="${ACTIVITY,,}" --generation="${GENERATION}" --realization="${REALIZATION}" \
                  --omit-keys "time,levelist,param,resolution,levtype" --request_name="${FLAT_REQ_NAME}"

                FDB_LIST_OUTPUT="${NEGATIVE_CHECK_DIR}/${levtype}_clmn_list.log"
                fdb-list --raw --porcelain "$(<${FLAT_REQ_NAME}),levtype=${levtype}" >"${FDB_LIST_OUTPUT}"
                LISTED_MESSAGES=$(cat ${FDB_LIST_OUTPUT} | wc -l)
                if [ ${LISTED_MESSAGES} != ${EXPECTED_MESSAGES}  ]; then
                        result="NEGATIVE CHECKER FAILED: Unexpected number of ${levtype} clmn messages. Expected: ${EXPECTED_MESSAGES}, FOUND: ${LISTED_MESSAGES}"
			echo ${result} | sed -e "s/FAILED/\x1b[1;31mFAILED\x1b[0m/"
                        CHECK_FAILED=1
                else
                        result="NEGATIVE CHECKER PASSED: Correct number of messages for levtype: ${levtype} clmn: ${LISTED_MESSAGES}"
			echo ${result} | sed -e "s/PASSED/\x1b[1;32mPASSED\x1b[0m/"
                fi

	done

	# Force failing if checker did not succeed
        if [ ${CHECK_FAILED} -ne 0 ]; then
                exit 1
        fi '
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

# Recover the first one before merging
ADDITIONAL_BINDINGS=("${DQC_OUTPUT_DIR}" "$(realpath ${FDB_HOME})")
# lib/common/util.sh (setup_additional_binds) (auto generated comment)
bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")

run_DQC_prod "${EXPVER}" "${DATE}" "${MODEL,,}" "${DQC_PROFILE_PATH}" "${EXPERIMENT,,}" "${ACTIVITY,,}" \
    "${REALIZATION}" "${GENERATION}" "${N_PROC}" "${CHECK_STANDARD_COMPLIANCE}" \
    "${CHECK_SPATIAL_COMPLETENESS}" "${CHECK_SPATIAL_CONSISTENCY}" "${CHECK_PHYSICAL_PLAUSIBILITY}" \
    "${DQC_OUTPUT_FILE}"

if [ "${CHECK_NEGATIVE_SPACE,,}" == "true" ]; then
    run_negative_space_checker "${EXPVER}" "${CHUNK_START_DATE}" "${MODEL,,}" "${DQC_PROFILE_PATH}" \
        "${EXPERIMENT,,}" "${ACTIVITY,,}" "${REALIZATION}" "${GENERATION}" "${CHUNK_SECOND_TO_LAST_DATE}" \
        "${DQC_OUTPUT_DIR}"
fi

if [ "${CREATE_FDB_INFO_FILE,,}" == "true" ]; then
    # Add additional bindings adding the FDB_INFO_FILE_PATH
    ADDITIONAL_BINDINGS=("${FDB_INFO_FILE_PATH}" "$(realpath ${FDB_INFO_FILE_PATH})")
    # lib/common/util.sh (setup_additional_binds) (auto generated comment)
    bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")
    # lib/common
    singularity exec \
        --env "SCRIPTDIR=${SCRIPTDIR}" \
        --env "FDB_INFO_FILE_NAME=${FDB_INFO_FILE_NAME}" \
        --env "HPCROOTDIR=${HPCROOTDIR}" \
        --env "EXPVER=${EXPVER}" \
        --env "MODEL=${MODEL}" \
        --env "CHUNK_END_DATE=${CHUNK_END_DATE}" \
        ${bindings} \
        "${HPC_CONTAINER_DIR}"/gsv/gsv_${GSV_VERSION}.sif \
        bash -c \
        ' python3 ${SCRIPTDIR}/FDB/update_fdb_info.py \
		--file ${FDB_INFO_FILE_NAME} --data_end_date ${CHUNK_END_DATE} '
fi
