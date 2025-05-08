#!/bin/bash

#####################################################
# Checks if the MODEL_PATH exists and has input data inside
# Globals:
#
# Arguments:
######################################################
function checker_precompiled_model() {
    if [ "${COMPILE}" == "False" ]; then
        if [ ! -d "${MODEL_PATH}" ]; then
            echo "The MODEL_VERSION introduced doesn't exist. Introduce a valid MODEL_VERSION in main.yml"
            echo "If you want to compile the model using the workflow, use MODEL.COMPILE: 'True' "
            exit 1
        else
            echo "The pre-compiled version ${MODEL_VERSION} of the model will be used."
            checker_inproot
        fi
    fi
}

#####################################################
# Checks if INPROOT directory exists for the current MODEL_VERSION
# Globals:
#
# Arguments:
######################################################
function checker_inproot() {
    if [ ! -d "${MODEL_INPUTS}" ]; then
        echo "Inputs missing in your MODEL_VERSION directory."
        exit 1
    fi
}

#####################################################
# Checks if the inputs and the ICMCL file exists for the current MODEL_VERSION, RESOLUTION and START_YEAR
# Globals:
#
# Arguments:
######################################################
function checker_inproot_ifs-nemo() {

    cd "${MODEL_INPUTS}"
    if [ -d "${ATM_GRID}" ]; then
        cd "${ATM_GRID}"
    else
        echo "Inputs missing for the current atmosphere resolution: ${ATM_GRID}, or ATM_GRID undefined"
        exit 1
    fi

    if [ -d "$IFS_EXPVER" ] && [ -n "$IFS_EXPVER" ]; then
        cd $IFS_EXPVER
    else
        echo "Inputs missing for the current atmosphere expver: ${IFS_EXPVER}, or IFS_EXPER undefined"
        exit 1
    fi
    if [ -d "$IFS_LABEL" ] && [ -n "$IFS_LABEL" ]; then
        cd $IFS_LABEL
    else
        echo "Inputs missing for the current atmosphere label: ${IFS_LABEL}"
        exit 1
    fi

    if [ -d ${DATELIST}00 ]; then
        cd ${DATELIST}00
    else
        echo "Inputs missing for the current start date: ${DATELIST}00"
        exit 1
    fi

    cd ifsINIT
    # TO-DO: check all the icmcl files not just the ones for the 1st year
    # TO-DO: be able to check all the types of ICMCLs (probably worth waiting for them to be uniformed)
    if [ ! -f "${ICMCL}" ]; then
        echo "WARNING: ICMCL missing for this resolution/year"
        #exit 1
    fi
}

#####################################################
# TODO: Implement this function
#####################################################

function checker_inproot_ifs-fesom() {
    true
}
#####################################################
# General check for ICON input file availability
# Globals:
#
# Arguments:
######################################################
function checker_inproot_icon() {

    cd "${MODEL_INPUTS}"/grids/public/mpim/

    #--------------------------
    # Checks for ATM Component
    #--------------------------
    if [ -d $ATM_GID ]; then
        cd ${ATM_GID}
    else
        echo "Inputs missing for the current atmosphere resolution: ${ATM_GID}"
        exit 1
    fi

    # Check NTCDF Atmosphere Grid file
    GRIDA_NC=icon_grid_"${ATM_GID}"_R02B0"${ATM_GRID_REF: -1}"_G.nc

    if [ ! -f "${GRIDA_NC}" ]; then
        echo "ICON atmosphere grid file missing: ${GRIDA_NC}"
        exit 1
    fi

    # Check for intital conditions
    if [ ! -d initial_conditions ]; then
        echo "ICON initial_conditions folder missing for atmosphere"
        exit 1
    fi

    # Check for aerosols files
    # TODO Check for individual year files
    if [ ! -d aerosol_kinne ]; then
        echo "ICON aerosol files missing for atmosphere"
        exit 1
    fi

    # Check for ozone files
    # TODO Check for individual year files
    if [ ! -d ozone ]; then
        echo "ICON ozone files missing for atmosphere"
        exit 1
    fi

    # Check for sst_and_seaice files
    # TODO Check for individual year files
    if [ ! -d sst_and_seaice ]; then
        echo "ICON sst_and_seaice files missing for atmosphere"
        exit 1
    fi

    #--------------------------
    # Checks for OCE Component
    #--------------------------
    cd "${MODEL_INPUTS}"/grids/public/mpim/

    if [ -d $OCE_GID ]; then
        cd ${OCE_GID}
    else
        echo "Inputs missing for the current ocean resolution: ${OCE_GID}"
        exit 1
    fi

    # Check NTCDF ocean Grid file
    GRIDO_NC=icon_grid_"${OCE_GID}"_R02B0"${OCE_GRID_REF: -1}"_O.nc

    if [ ! -f "${GRIDO_NC}" ]; then
        echo "ICON ocean grid file missing: ${GRIDO_NC}"
        exit 1
    fi

    #--------------------------
    # Checks for LAND Component
    #--------------------------
    cd "${MODEL_INPUTS}"/grids/public/mpim/

    LAND_DIR="${ATM_GID}"-"${OCE_GID}"

    if [ -d $LAND_DIR ]; then
        cd ${LAND_DIR}
    else
        echo "Inputs missing for land (JSBACH) component: ${LAND_DIR}"
        exit 1
    fi

    # Check for land files
    # TODO Check for individual year files
    if [ ! -d land ]; then
        echo "ICON land files missing"
        exit 1
    fi
}

#####################################################
# Checks that RUN.TYPE is defined and is `production`
# `research`, `test` or `pre-production`
# Globals:
# Arguments: RUN_TYPE
#####################################################
function checker_run_type() {
    RUN_TYPE=$1
    if [ -z "${RUN_TYPE}" ]; then
        echo "RUN_TYPE is not defined. Please define it in main.yml"
        exit 1
    fi

    if [ "${RUN_TYPE}" == "production" ] || [ "${RUN_TYPE}" == "research" ] || [ "${RUN_TYPE}" == "test" ] || [ "${RUN_TYPE}" == "pre-production" ]; then
        echo "RUN_TYPE is ${RUN_TYPE}"
    else
        echo "RUN_TYPE is not valid. Please choose between production, research, test or pre-production"
        exit 1
    fi
}

#####################################################
# Checks that each needed submodule has been cloned
# correctly in local setup before launching the apps job.
# Globals:
# Arguments:
#####################################################
function checker_submodules() {

    declare -a ERROR_LIST
    cd ${ROOTDIR}/proj/${PROJDEST}

    if [ "${WORKFLOW,,}" == "model" ] || [ "${WORKFLOW,,}" == "end-to-end" ]; then

        # if the directory is empty
        if [ -z "$(ls -A 'data-portfolio')" ]; then
            ERROR_LIST+="The data-portfolio submodule for the workflow has failed to clone. "
        fi

        if [ -z "$(ls -A ${MODEL_NAME})" ] && [ "${COMPILE,,}" == "true" ]; then
            ERROR_LIST+="The ${MODEL_NAME} submodule has failed to clone. "
        fi

    fi

    if [ "${AQUA_ON,,}" == "true" ]; then

        if [ -z "$(ls -A 'catalog')" ]; then
            ERROR_LIST+="The catalog submodule has failed to clone. "
        fi

        if [ -z "$(ls -A 'data-portfolio')" ]; then
            ERROR_LIST+="The data-portfolio submodule for AQUA has failed to clone. "
        fi

    fi

    if [ "${DVC_INPUTS_BRANCH}" ] && [ -z "$(ls -A 'dvc-cache-de340')" ]; then
        ERROR_LIST+="The DVC cache submodule has failed to clone."
    fi

    # if there were any submodule cloning errors, let the user know and exit
    if [ ! -z "${ERROR_LIST[@]}" ]; then
        for error in "${ERROR_LIST[@]}"; do
            echo -n "${error}"
        done
        exit 1
    fi

}
