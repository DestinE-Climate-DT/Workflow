#!/bin/bash
#
# This step loads the necessary enviroment and then compiles the diferent models
set -xuve

# Interface
HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL_NAME=${3:-%MODEL.NAME%}
CURRENT_ARCH=${4:-%CURRENT_ARCH%}
MODEL_VERSION=${5:-%MODEL.VERSION%}
ENVIRONMENT=${6:-%RUN.ENVIRONMENT%}
HPCARCH=${7:-%HPCARCH%}
ATM_GRID=${8:-%MODEL.GRID_ATM%}
PU=${9:-%RUN.PROCESSOR_UNIT%}
HPC_PROJECT=${10:-%CURRENT_HPC_PROJECT_DIR%}
EXPID=${11:-%DEFAULT.EXPID%}
INPUTS=${12:-%CONFIGURATION.INPUTS%}
INSTALL=${13:-%CONFIGURATION.INSTALL%} #local (default) or shared
FDB_DIR=${14:-%CURRENT_FDB_DIR%}
WORKFLOW=${15:-%RUN.WORKFLOW%}
APP=${16:-%APP.NAMES%}
READ_EXPID=${17:-%APP.READ_EXPID%}
PRODUCTION=${18:-%RUN.PRODUCTION%} # true or false
FDB_PROD=${19:-%CURRENT_FDB_PROD%}
RUN_TYPE=${21:-%RUN.TYPE%}

export MODEL_VERSION
export ENVIRONMENT
export HPCARCH
export HPCROOTDIR
export INPUTS
export PROJDEST

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

ATM_MODEL=${MODEL_NAME%%-*}
OCEAN_MODEL=${MODEL_NAME##*-}

# PROBABLY HAS TO BE REFACTORED
if [ "${RUN_TYPE}" == "PRODUCTION" ]; then
    READ_EXPID="0001"
elif [ "${WORKFLOW}" == "end-to-end" ]; then
    READ_EXPID="$EXPID"
fi

# Main code
cd "$HPCROOTDIR"

# If tarfile exists in remote filesystem it's uncompressed
# Untar
if [ -f "${PROJDEST}".tar.gz ]; then
    tar xf "${PROJDEST}".tar.gz
fi

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh

load_model_dir
load_inproot_precomp_path

# MODEL functions
if [ -n "${INPUTS}" ]; then
    inputs_dvc_checkout
fi

#Functions

#####################################################
# Sets up files to enable running Maestro workflows
# out-of-the-box
# Globals:
#   HPCROOTDIR
#   PROJDEST
# Arguments:
######################################################
function bootstrap_maestro() {
    MSTRO_BOOT_DIR="${HPCROOTDIR}"/"${PROJDEST}"/conf/model/ifs-nemo/multio_maestro_bootstrap/
    CONF_DIR="${HPCROOTDIR}"/"${PROJDEST}"/conf/
    MSTRO_REQUEST="${CONF_DIR}/mstro_request.yml"
    if [ "${WORKFLOW}" == "maestro-apps" ]; then
        if [ ! -f "${MSTRO_REQUEST}" ]; then
            cp "${MSTRO_BOOT_DIR}/mstro_request_apps.yml" "${MSTRO_REQUEST}"
        fi
    fi
    if [ "${WORKFLOW}" == "maestro-end-to-end" ]; then
        if [ ! -f "${MSTRO_REQUEST}" ]; then
            cp "${MSTRO_BOOT_DIR}/mstro_request_end-to-end.yml" "${MSTRO_REQUEST}"
        fi

        # Need a specific bundle.yml file for the right MultIO
        # branch, until it is merged
        IFS_NEMO_DIR="${HPCROOTDIR}"/"${PROJDEST}"/ifs-nemo
        cp "${MSTRO_BOOT_DIR}"/bundle.yml "${IFS_NEMO_DIR}"
    fi
}
function bootstrap_maestro_workflow() {
    # Picks up some pre-defined MultIO config files with
    # Maestro backend, to help run Maestro workflows a little
    # more out-of-the-box
    MULTIO_CONF_DIR="${HPCROOTDIR}"/"${PROJDEST}"/conf/model/ifs-nemo/multio_maestro_bootstrap/multio_config
    echo "MULTIO_CONF_DIR=${MULTIO_CONF_DIR}"
    RAPS_MULTIO_YAML_DIR="${HPCROOTDIR}"/"${PROJDEST}"/ifs-nemo/source/raps/multio_yaml/General_Plans
    echo "$RAPS_MULTIO_YAML_DIR"
    echo "Copy experimental configuration files to: ${RAPS_MULTIO_YAML_DIR}"
    cp "${MULTIO_CONF_DIR}"/*.yaml "${RAPS_MULTIO_YAML_DIR}"
}

#####################################################
# Compiles IFS-Nemo model using RAPS
# Globals:
#   HPCROOTDIR
#   PROJDEST
#   MODEL
#   NUMPROC
# Arguments:
######################################################
function compile_ifs-nemo() {

    cd "${INSTALL_DIR}"/
    ./ifs-bundle create

    if [ "${WORKFLOW}" == "maestro-end-to-end" ]; then
        bootstrap_maestro_workflow
    fi

    # Start the bundle build process
    if [ ! -d "build" ]; then
        ./ifs-bundle build --arch ${ARCH} --with-single-precision --with-double-precision-nemo --nemo-version=V40 --nemo-grid-config=eORCA1_GO8_Z75 --nemo-ice-config=SI3 --with-multio-for-nemo-sglexe --dry-run --verbose --nemovar-grid-config=ORCA1_Z42 --nemovar-ver=DEV ${OTHERS} ${MAESTRO_FLAG}
        cd build
        if [ "${WORKFLOW}" == "maestro-end-to-end" ]; then
            export MAESTRO_ROOT="/scratch/project_465000454/chaine/maestro-core/install"
            ./configure.sh CFLAGS="-DMAESTRO_PATH=${MAESTRO_ROOT}"
        else
            ./configure.sh
        fi
    fi

    if [ ! -f "${INSTALL_DIR}/build/bin/ifsMASTER.SP" ]; then
        cd "${INSTALL_DIR}"/build
        source env.sh
        make -j 20 VERBOSE=1 | tee raps_make.log

    fi

    if [ -f "${INSTALL_DIR}/build/bin/ifsMASTER.SP" ]; then
        make install
        echo "Compilation sucessful"
    else
        echo "Compilation failed. There is no ifsMASTER.SP"
        exit 1
    fi

    cd "${INSTALL_DIR}/source/raps"
    set +e
    source initbm
    set -e

    cd "${INSTALL_DIR}"
    print_rev_all | column -t >"bundle_versions"
}

###################################################
# Prints the commits and the versions of the
# used modules in ifs-bundle
###################################################
function print_rev {
    _prev_dir=$PWD
    cd "$1" && echo "$1" "$(git rev-parse HEAD)" "$(git rev-parse --symbolic-full-name HEAD)" "$(git --no-pager tag --points-at HEAD)"
    cd "$_prev_dir"
}

function print_rev_all {
    echo "path" "commit" "ref" "tag"
    echo "----" "------" "---" "---"
    for d in $(find source -maxdepth 1 -type d); do print_rev "$d"; done
}

#####################################################
# Compiles IFS-Fesom model using RAPS
# Globals:
#   HPCROOTDIR
#   PROJDEST
#   MODEL
#   NUMPROC
# Arguments:
######################################################
function compile_ifs-fesom() {
    cd "${HPCROOTDIR}"/"${PROJDEST}"/"${MODEL_NAME}"/flexbuild
    set -xve +u
    source initbm "${IFS_COMPILING_SCRIPT}" SINGLE=yes FESOM=yes RAPS_SUPPORT=yes RAPSHARED=no ODB=no OOPS=no NCPUS="${NUMPROC}"
    make 2>&1 | tee raps_make.log
}

######################################################
# Compiles the ICON model differenciating between PU's
# Globals:
#   HPCROOTDIR
#   PROJDEST
#   PU
# Arguments:
######################################################
function compile_icon() {
    # Path to model
    local ICON_PATH=${HPCROOTDIR}/${PROJDEST}/icon-mpim
    # Load enviroment and create Makefile
    cd "${ICON_PATH}"
    # Compile CPU/GPU Binaries
    compile_icon_"${PU}"
}

#####################################################
# installs maestro-core (not used for now)
# Globals:
#       HPCROOTDIR
#       PROJDEST
# Arguments:
######################################################
function install_maestro() {
    export MAESTRO_ROOT=${HPCROOTDIR}/${PROJDEST}/maestro-core/install
    pushd ${HPCROOTDIR}/${PROJDEST}/maestro-core
    if [ ! -d "install" ]; then
        mkdir install
    fi
    if [ ! -d "tmp" ]; then
        mkdir tmp
    fi

    autoreconf -ifv
    ./configure CC=cc --prefix=${MAESTRO_ROOT}
    make
    make check TESTS=
    make install
    popd
}

#####################################################
# Checks if the PRECOMP_MODEL_PATH exists and has input data inside
# Globals:
#
# Arguments:
######################################################
function checker_precompiled_model() {
    if [ ! -z "${MODEL_VERSION}" ]; then
        if [ ! -d "${PRECOMP_MODEL_PATH}" ]; then
            echo "The MODEL_VERSION introduced doesn't exist. Introduce a valid MODEL_VERSION in main.yml"
            echo "If you want to compile the model using the workflow, use MODEL_VERSION: '' "
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
    if [ ! -d "${INPROOT}" ]; then
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
    IFS_EXPVER=%CONFIGURATION.IFS.EXPVER%
    IFS_LABEL=%CONFIGURATION.IFS.LABEL%
    DATELIST=%EXPERIMENT.DATELIST%
    YEAR=${DATELIST::4}
    ICMCL=%ICMCL%
    ICMCL=${ICMCL:-ICMCL_%CONFIGURATION.IFS.RESOL%_${YEAR}_extra}
    cd "${INPROOT}"
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

    # Load ICON grid identifiers
    ATM_GID="%CONFIGURATION.ICON.ATM_GID%"
    OCE_GID="%CONFIGURATION.ICON.OCE_GID%"
    # Load ICON grid res
    ATM_GRID_REF="%CONFIGURATION.ICON.ATM_REF%"
    OCE_GRID_REF="%CONFIGURATION.ICON.OCE_REF%"
    # Load datelist
    DATELIST="%EXPERIMENT.DATELIST%"

    cd "${INPROOT}"/grids/public/mpim/

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
    if [ ! -d initial_condition ]; then
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
    cd "${INPROOT}"/grids/public/mpim/

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

    # Check for ocean restart files
    # TODO Check for individual year files
    if [ ! -d ocean/restart ]; then
        echo "ICON ocean initialisation files missing"
        exit 1
    fi

    #--------------------------
    # Checks for LAND Component
    #--------------------------
    cd "${INPROOT}"/grids/public/mpim/

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

# Functions to install APPLICATIONS

#####################################################
# installs AQUA application
# Globals:
# Arguments:
######################################################
function install_AQUA() {
    #install OBS application from local clone into the project
    echo "this installs nothing"
}

#####################################################
# installs ENERGY_OFFSHORE application
# Globals:
#       HPCROOTDIR
#       PROJDEST
# Arguments:
######################################################
function install_ENERGY_ONSHORE() {
    #install OBS application from local clone into the project
    echo "this installs nothing"
}

#####################################################
# installs ENERGY_OFFSHORE application
# Globals:
#       HPCROOTDIR
#       PROJDEST
# Arguments:
######################################################
function install_ENERGY_OFFSHORE() {
    #install OBS application from local clone into the project
    echo "this installs nothing"
}

#####################################################
# installs HYDROMET application
# Globals:
# Arguments:
######################################################
function install_HYDROMET() {
    #install OBS application from local clone into the project
    echo "This installs nothing"
}

#####################################################
# installs MHM application
# Globals:
#       LIBDIR
# Arguments:
######################################################
function install_MHM() {
    # copying up mHM re-start file for EXPID
    cp "/projappl/project_465000454/models/mhm/mHM_restart_001.nc" \
        "${LIBDIR}/runscript/run_mhm/input/restart/mHM_restart_001.nc"

    # copying up mRM re-start files for EXPID
    cp -rf /projappl/project_465000454/models/mrm/restart_files/* ${LIBDIR}/runscript/run_mrm/restart_files
}

#####################################################
# installs WILDFIRES_WISE application
# Globals:
# Arguments:
######################################################
function install_WILDFIRES_WISE() {
    #install OBS application from local clone into the project
    echo "This installs nothing"
}

#####################################################
# installs WILDFIRES_FWI application
# Globals:
# Arguments:
######################################################
function install_WILDFIRES_FWI() {
    # Install WILDFIRES_FWI application from local clone into the project
    # Not needed as it uses containarized version
    echo "This installs nothing"
}

#####################################################
# installs WILDFIRES_SPITFIRE application
# Globals:
# Arguments:
######################################################
function install_WILDFIRES_SPITFIRE() {
    # Install WILDFIRES_FWI application from local clone into the project
    # Not needed as it uses containarized version
    echo "This installs nothing"
}

#####################################################
# installs OBS application
# Globals:
# Arguments:
######################################################
function install_OBS() {
    #install OBS application from local clone into the project
    echo "This installs nothing"
}

###################################
# Loads the fdb config for ifs-nemo
###################################

function load_fdb_ifs() {
    # Directory definition
    if [ -z "${MODEL_VERSION}" ]; then
        RAPS_BIN="${HPCROOTDIR}/${PROJDEST}/${MODEL_NAME}/source/raps/bin"
    else
        RAPS_BIN="${PRECOMP_MODEL_PATH}/source/raps/bin"
    fi

    if [[ $FDB_TYPE != "PROD" ]]; then

        FDB_DIRS=("NATIVE_grids" "HEALPIX_grids" "REGULARLL_grids")

        for FDB in "${FDB_DIRS[@]}"; do
            FDB_DIR_PATH="${FDB_DIR}/${EXPID}/fdb/${FDB}"
            mkdir -p "${FDB_DIR_PATH}/etc/fdb"

            FDB_prefix="${FDB%%_*}"

            cp "${HPCROOTDIR}/LOG_${EXPID}/config${FDB_prefix,,}_REMOTE_SETUP" "${FDB_DIR_PATH}/etc/fdb/config.yaml"

            if [ -f "${RAPS_BIN}/../fdb5/schema" ]; then
                cp "${RAPS_BIN}/../fdb5/schema" "${FDB_DIR_PATH}/etc/fdb/schema"
            elif [ -f "${RAPS_BIN}/../etc/fdb/schema" ]; then
                cp "${RAPS_BIN}/../etc/fdb/schema" "${FDB_DIR_PATH}/etc/fdb/schema"
            else
                echo "ERROR: where is your schema file?"
                exit 1
            fi
        done
    fi
}

function load_fdb_icon() {

    if [[ $FDB_TYPE != "PROD" ]]; then

        FDB_DIR_PATH="${FDB_DIR}/${EXPID}/fdb/HEALPIX_grids"
        mkdir -p "${FDB_DIR_PATH}/etc/fdb"

        cp "${HPCROOTDIR}/LOG_${EXPID}/confighealpix_REMOTE_SETUP" "${FDB_DIR_PATH}/etc/fdb/config.yaml"
        cp "${FDB_PROD}/etc/fdb/schema" "${FDB_DIR_PATH}/etc/fdb/schema"
    fi
}

########################
# Install applications
########################
function format_input_app_string() {
    APP=${APP#\[} # Removing the leading '['
    APP=${APP%\]} # Removing the trailing ']'

    # Convert a comma-separated string to an array
    IFS=', ' read -ra APP_ARRAY <<<"$APP"
}

########################
# MAIN CODE
########################

MAESTRO_FLAG=""
# FIXME Phase 2: We are assuming here Maestro is already installed on the target. We need a better plan, and a fallback to a Maestro we would install ourselves from local/remote setup.
if [ "${WORKFLOW}" == "maestro-end-to-end" ]; then
    load_environment_maestro_end_to_end
    MAESTRO_FLAG="--cmake='ENABLE_MAESTRO=ON'"
fi
if [ "${WORKFLOW}" == "maestro-apps" ]; then
    load_environment_maestro_apps
fi
if [ "${WORKFLOW}" == "maestro-apps" ] || [ "${WORKFLOW}" == "maestro-end-to-end" ]; then
    bootstrap_maestro
fi

# MODEL MAIN CODE

if [ "${INSTALL}" = "shared" ]; then
    # Installs de model in the shared directory
    cd "${HPCROOTDIR}/${PROJDEST}"
    INSTALL_DIR=${PRECOMP_MODEL_PATH}
    mkdir -p "${INSTALL_DIR}"
    if [ ! -d "${INSTALL_DIR}/build" ]; then
        tar -czvf "${MODEL_NAME}".tar.gz "${MODEL_NAME}"
        mv "${MODEL_NAME}".tar.gz "${INSTALL_DIR}"
        cd "${INSTALL_DIR}"
        tar xf "${MODEL_NAME}".tar.gz --strip-components=1
        ln -fs "${HPC_MODEL_DIR}"/inidata "${HPC_MODEL_DIR}"/"${MODEL_VERSION}"/inidata
    else
        echo "There is already a MODEL_VERSION that contains a build with the same name"
        echo "You can't overwrite a MODEL_VERSION"
        exit 1
    fi
else
    INSTALL_DIR="${HPCROOTDIR}/${PROJDEST}/${MODEL_NAME}"
fi

# Checker
checker_precompiled_model

if [ "${WORKFLOW}" != "apps" ] && [ "${WORKFLOW}" != "aqua" ] && [ "${WORKFLOW}" != "maestro-apps" ]; then
    checker_inproot_"${MODEL_NAME}"
    # Check if a version of the model is provided
    # Compile model sources if not
    if [ -z "${MODEL_VERSION}" ] || [ "${INSTALL}" = "shared" ] || [ "${WORKFLOW}" = "maestro-end-to-end" ]; then
        load_compile_env_"${ATM_MODEL}"_"${PU}"
        compile_"${MODEL_NAME}"
    else
        # If compilation path is given skip compilation
        echo "Path to a compiled model provided: PRECOMP_MODEL_PATH=${PRECOMP_MODEL_PATH}"
        echo "Skipping compilation"
    fi
    # Creates fake production fdb if not in production
    set_data_gov ${RUN_TYPE}

    if [[ $FDB_TYPE != "PROD" ]]; then
        load_fdb_"${ATM_MODEL}"
        ln -sf "${FDB_DIR}"/"${EXPID}"/fdb/HEALPIX_grids/etc/fdb/config.yaml "${FDB_DIR}"/"${EXPID}"/fdb/config.yaml
    fi
fi

# APPLICATIONS MAIN CODE
if [ "${WORKFLOW}" == "apps" ] || [ "${WORKFLOW}" == "end-to-end" ]; then
    load_environment_gsv "${FDB_DIR}" "${READ_EXPID}"
fi
if [ "${WORKFLOW}" == "maestro-apps" ] || [ "${WORKFLOW}" == "maestro-end-to-end" ]; then
    load_environment_maestro_gsv
fi
install_GSV_INTERFACE

if [ "${WORKFLOW}" != "model" ] && [ "${WORKFLOW}" != "aqua" ]; then
    # Install OPA
    # load_environment_opa (currently env gsv_interface is the same as opa)
    install_OPA

    if [ "${WORKFLOW}" != "maestro-apps" ] && [ "${WORKFLOW}" != "maestro-end-to-end" ]; then
        format_input_app_string
        for APPLICATION in "${APP_ARRAY[@]}"; do
            echo "Installing APP: ${APPLICATION}"
            load_environment_"${APPLICATION^^}"
            install_"${APPLICATION^^}"
        done
    fi
fi
