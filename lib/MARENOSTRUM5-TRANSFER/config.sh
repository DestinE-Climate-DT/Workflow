#!/bin/bash
#
# Configuration for BSC platform

function load_singularity() {
    true
}

#####################################################
# Retrieves and creates the requests for the FDB transfer.
# Globals:
#   CONTAINER_COMMAND
#   FDB_HOME
#   EXPVER
#   START_DATE
#   CHUNK
#   SECOND_TO_LAST_DATE
#   EXPERIMENT
#   MODEL_NAME
#   ACTIVITY
#   REALIZATION
#   GENERATION
#   LIBDIR
#   GRIB_FILE_NAME
#   SCRIPTDIR
#   BASE_NAME
#   CHUNK_SECOND_TO_LAST_DATE
#   TRANSFER_REQUESTS_PATH
#   TRANSFER_MONTHLY
#   SCRATCH_DIR
#   HPC
#   MARS_BINARY
# Arguments:
#   profile_file
######################################################
function fdb_transfer() {

    profile_file=$1

    export PATH="${MARS_BINARY}":$PATH
    retrieve_and_create_requests ${profile_file}
}
