#!/bin/bash

# Utils functions for wipe-check.sh and wipe.sh

#####################################################
# Function to check the number of messages in the
# profile file before wiping.
# Globals:
#   FDB_HOME
#   EXPVER
#   START_DATE
#   CHUNK
#   SECOND_TO_LAST_DATE
#   EXPERIMENT
#   MODEL_NAME
#   ACTIVITY
#   GENERATION
#   LIBDIR
# Arguments:
#   profile_file
#####################################################
function check_messages_wipe() {
    profile_file="${1}"

    export FDB_HOME=${DATABRIDGE_FDB_HOME}
    python3 "${SCRIPTDIR}/FDB/yaml_to_flat_request.py" --file="$profile_file" \
        --expver="${EXPVER}" --startdate="${START_DATE}" --experiment="${EXPERIMENT,,}" \
        --enddate="${SECOND_TO_LAST_DATE}" --model="${MODEL_NAME}" \
        --activity="${ACTIVITY,,}" --generation="${GENERATION}" --realization="${REALIZATION}" \
        --omit-keys "time,levelist" --request_name="${FLAT_REQ_NAME}"

    FDB_LIST_OUTPUT="${BASE_NAME}_list.log"
    fdb-list --raw --porcelain "$(<${FLAT_REQ_NAME})" >"${FDB_LIST_OUTPUT}"
    LISTED_MESSAGES=$(cat ${FDB_LIST_OUTPUT} | wc -l)

    EXPECTED_MESSAGES=$(python3 "${SCRIPTDIR}/FDB/count_expected_messages.py" \
        --file="$profile_file" --expver="${EXPVER}" --startdate="${START_DATE}" \
        --experiment="${EXPERIMENT,,}" --enddate="${SECOND_TO_LAST_DATE}" \
        --model="${MODEL_NAME}" --activity="${ACTIVITY,,}" \
        --generation="${GENERATION}" --realization="${REALIZATION}")

    if [ "$LISTED_MESSAGES" == "$EXPECTED_MESSAGES" ]; then
        echo "Number of messages MATCH ${LISTED_MESSAGES}"
    else
        echo "ERROR Number of messages DO NOT MATCH: Listed:  ${LISTED_MESSAGES}, expected: ${EXPECTED_MESSAGES}"
        exit 1
    fi
}

#####################################################
# Function to execute the wipe
# Globals:
#   FDB_HOME
#   EXPVER
#   START_DATE
#   CHUNK
#   SECOND_TO_LAST_DATE
#   EXPERIMENT
#   MODEL_NAME
#   ACTIVITY
#   LIBDIR
# Arguments:
#   WIPE_DOIT
#####################################################
function exec_wipe() {

    WIPE_DOIT="${1}"
    GENERAL_REQUEST="${2}"
    FLAT_REQ_NAME="${3}"
    local MINIMUM_KEYS="${4}"
    WIPE_UNSAFE="${5}"

    python3 "${SCRIPTDIR}/FDB/yaml_to_flat_request.py" --file="${GENERAL_REQUEST}" \
        --expver="${EXPVER}" --startdate="${START_DATE}" --experiment="${EXPERIMENT,,}" \
        --enddate="${SECOND_TO_LAST_DATE}" --model="${MODEL_NAME,,}" \
        --activity="${ACTIVITY,,}" --generation="${GENERATION}" --realization="${REALIZATION}" \
        --request_name="${FLAT_REQ_NAME}" --omit-keys="time,levelist,param,levtype,resolution"
    wipe_command="fdb-wipe --minimum-keys ${MINIMUM_KEYS}"
    if [ ${WIPE_DOIT,,} == "true" ]; then
        wipe_command+=" --doit"
    fi
    if [ ${WIPE_UNSAFE,,} == "true" ]; then
        wipe_command+=" --unsafe-wipe-all"
    fi
    wipe_command+=" $(<${FLAT_REQ_NAME})"
    $wipe_command
}

#########################################
# Function to check that the expver that
# is checked in the bridge is the same
# as the one in the transfer job.
# Arguments:
#   modify_metadata_transfer
#   modify_metadata_fields
#   bridge_expver
#   expver
#########################################
function check_expver_match() {
    local modify_metadata_transfer="$1"
    local modify_metadata_fields="$2"
    local bridge_expver="$3"
    local expver="$4"

    # Normalize inputs to lowercase
    local transfer_modify__metadata_enabled="${modify_metadata_transfer,,}"
    local fields_lower="${modify_metadata_fields,,}"

    # Case 1: Metadata modification is expected
    if [[ "$transfer_modify__metadata_enabled" == "true" ]]; then
        local has_expver_field=""
        local expver_value=""

        # Check if experimentversionnumber=VALUE exists
        if [[ "$fields_lower" == *"experimentversionnumber="* ]]; then
            has_expver_field="true"
            expver_value=$(echo "$fields_lower" | grep -oP 'experimentversionnumber=\K[0-9]+')
        fi

        if [[ "$has_expver_field" == "true" && -n "$bridge_expver" ]]; then
            if [[ "$expver_value" == "$bridge_expver" ]]; then
                echo "experimentversionnumber matches BRIDGE_EXPVER"
                echo "The TRANSFER job modified the experimentversionnumber field, and it matches the BRIDGE_EXPVER."
            else
                echo "Mismatch: experimentversionnumber=$expver_value, BRIDGE_EXPVER=$bridge_expver"
                echo "The TRANSFER job modified the experimentversionnumber field, but it does not match the BRIDGE_EXPVER."
                exit 1
            fi
        elif [[ "$bridge_expver" == "$expver" ]]; then
            echo "The transfer job is modifying the metadata, but the experimentversionnumber field is not present."
            echo "BRIDGE_EXPVER matches EXPVER."
        else
            echo "experimentversionnumber field is not modified and BRIDGE_EXPVER does not match EXPVER."
            echo "Please check the configuration and ensure that the transfer job is set up correctly."
            exit 1
        fi

    # Case 2: No metadata modification expected
    else
        if [[ "$bridge_expver" == "$expver" ]]; then
            echo "MODIFY_METADATA_TRANSFER is not true, but the BRIDGE_EXPVER matches the experiment EXPVER."
            echo "No metadata modification needed."
        else
            echo "MODIFY_METADATA_TRANSFER is not true, but the BRIDGE_EXPVER does not match the experiment EXPVER."
            echo "Please check the configuration and ensure that the transfer job is set up correctly."
            exit 1
        fi
    fi
}
