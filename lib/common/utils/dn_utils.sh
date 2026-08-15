#!/bin/bash

# Utils functions for dn.sh

#####################################################
# Function to print fdb related information
# Globals:
#   EXPVER
#   FDB_HOME
#   HPC_CONTAINER_DIR
#   GSV_VERSION
# Arguments:
#####################################################
function print_data_gov() {
    ADDITIONAL_BINDINGS=("$(realpath ${FDB_HOME})")
    bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")
    singularity exec --cleanenv --no-home \
        --env "FDB_HOME=$(realpath ${FDB_HOME})" \
        --env "EXPVER=${EXPVER}" \
        ${bindings} \
        "${HPC_CONTAINER_DIR}"/gsv/gsv_${GSV_VERSION}.sif \
        bash -c \
        '
    set -xuve
    echo "The experiment id in the FDB will be ${EXPVER}. The class will be d1. d2 class is work in progress"

    echo "printing fdb-schema..."
    fdb-schema

    echo "printing fdb-info..."
    fdb-info --all
    '
}
