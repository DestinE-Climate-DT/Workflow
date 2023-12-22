#!/bin/bash
#
# This step loads the necessary enviroment and then compiles the diferent models
set -xuve 

# Interface
HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL_NAME=${3:-%RUN.MODEL%}
CURRENT_ARCH=${4:-%CURRENT_ARCH%}
MODEL_VERSION=${5:-%RUN.MODEL_VERSION%}
ENVIRONMENT=${6:-%RUN.ENVIRONMENT%}
HPCARCH=${7:-%HPCARCH%}
ATM_GRID=${8:-%RUN.GRID_ATM%}
PU=${9:-%RUN.PROCESSOR_UNIT%}

export MODEL_VERSION
export ENVIRONMENT
export HPCARCH

APP=${8:-%RUN.APP%}
EXPID=${9:-%DEFAULT.EXPID%}
READ_EXPID=${10:-%RUN.READ_EXPID%}

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$( echo "${CURRENT_ARCH}" | cut -d- -f1 )

ATM_MODEL=${MODEL_NAME%%-*}
OCEAN_MODEL=${MODEL_NAME##*-}

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
    cd "${HPCROOTDIR}"/"${PROJDEST}"/"${MODEL_NAME}"/
    if [ ! -d "build" ]; then
        ./ifs-bundle create
        ./ifs-bundle build --arch ${ARCH} --with-single-precision --with-double-precision-nemo --nemo-version=V40 --nemo-grid-config=eORCA1_GO8_Z75 --nemo-ice-config=SI3 --with-multio-for-nemo-sglexe --dry-run --verbose --nemovar-grid-config=ORCA1_Z42 --nemovar-ver=DEV ${OTHERS}
        cd build
        ./configure.sh
        source env.sh
        make -j 48 VERBOSE=1 | tee raps_make.log
    fi

    cd "${HPCROOTDIR}"/"${PROJDEST}"/raps
    set +e
    source initbm
    set -e  
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

    # Compile CPU Binaries
    if [ "${PU}" = "cpu" ]; then
        # Check if CPU Binaries exist
        # Compile if necessary
        compile_icon_cpu
    fi
    # Check if GPU binaries exist
    if [ "${PU}" = "gpu_gpu" ]; then 
            # Check if GPU Binaries exist
            # Compile if necessary
            compile_icon_gpu_gpu
    fi
}

#####################################################
# Checks if the PRECOMP_MODEL_PATH exists and has input data inside
# Globals:
#
# Arguments:
######################################################
function checker_precompiled_model(){
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
function checker_inproot(){
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
function checker_inproot_ifs(){
     IFS_EXPVER=%CONFIGURATION.IFS.EXPVER%
     IFS_LABEL=%CONFIGURATION.IFS.LABEL%
     DATELIST=%EXPERIMENT.DATELIST%
     YEAR=${DATELIST::4}
     ICMCL=ICMCL_%CONFIGURATION.IFS.RESOL%_${YEAR}_extra
     cd $INPROOT
     if [ -d $ATM_GRID ]; then
         cd $ATM_GRID
     else
         echo "Inputs missing for the current atmosphere resolution: ${ATM_GRID}"
             exit 1
     fi

     if [ -d $IFS_EXPVER ]; then
         cd $IFS_EXPVER
     else
             echo "Inputs missing for the current atmosphere expver: ${IFS_EXPVER}"
             exit 1
     fi
     if [ -d $IFS_LABEL ]; then
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
     if [ ! -f $ICMCL ]; then
         echo "ICMCL missing for this resolution/year"
         exit 1
     fi
}

#####################################################
# General check for ICON input file availability
# Globals:
#
# Arguments:
######################################################
function checker_inproot_icon(){

    # Load ICON grid identifiers
    ATM_GID="%CONFIGURATION.ICON.ATM_GID%"
    OCE_GID="%CONFIGURATION.ICON.OCE_GID%"
    # Load ICON grid res
    GRID_RES="%RUN.GRID_ATM%"
    # Load datelist
    DATELIST="%EXPERIMENT.DATELIST%"

    cd $INPROOT/grids/public/mpim/

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
    GRIDA_NC=icon_grid_"${ATM_GID}"_R02B0"${GRID_RES: -1}"_G.nc

    if [ ! -f ${GRIDA_NC} ]; then
        echo "ICON atmosphere grid file missing: ${GRIDA_NC}"
        exit 1
    fi

    # Check for intital conditions
    if [ ! -d initial_condition ]; then
        echo "ICON initial_conditions folder missing for atmosphere"
        exit 1
    else
        cd initial_condition
        INI_R2BX=ifs2icon_"${DATELIST}"00_R02B0"${GRID_RES: -1}"_G.nc
        if [ ! -f ${INI_R2BX} ]; then
            echo "ICON initial_conditions ${GRID_RES} ifs2icon file missing for atmosphere"
            exit 1  
        fi
       cd ..    
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
    cd $INPROOT/grids/public/mpim/

    if [ -d $OCE_GID ]; then
        cd ${OCE_GID}
    else
        echo "Inputs missing for the current ocean resolution: ${OCE_GID}"
        exit 1
    fi

    # Check NTCDF ocean Grid file
    GRIDO_NC=icon_grid_"${OCE_GID}"_R02B0"${GRID_RES: -1}"_O.nc

    if [ ! -f ${GRIDO_NC} ]; then
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
    cd $INPROOT/grids/public/mpim/

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

    # Check for fractional mask files
    # TODO Check for individual year files 
    if [ ! -d fractional_mask ]; then
        echo "ICON fractional mask files missing"
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
  echo "This installs nothing"
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
  cp -rf "/projappl/project_465000454/models/mrm/restart_files/*" \
  "${LIBDIR}/runscript/run_mrm/restart_files"
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


########################
# MAIN CODE
########################

# MODEL MAIN CODE

# Checker
checker_precompiled_model
checker_inproot_"${ATM_MODEL}"

# Check if a version of the model is provided
# Compile model sources if not
if [ -z "${MODEL_VERSION}" ]; then
    load_compile_env_"${ATM_MODEL}"_${PU}
    compile_"${MODEL_NAME}"
else
    # If compilation path is given skip compilation
    echo "Path to a compiled model provided: PRECOMP_MODEL_PATH=${PRECOMP_MODEL_PATH}"
    echo "Skipping compilation"
fi

# APPLICATIONS MAIN CODE

# install gsv interface
load_dirs
load_environment_gsv $HPC_PROJECT $READ_EXPID
install_GSV_INTERFACE

# Install OPA
# load_environment_opa (currently env gsv_interface is the same as opa)
install_OPA

# Install applications
function format_input_app_string() {
  APP=${APP#\[}  # Removing the leading '['
  APP=${APP%\]}  # Removing the trailing ']'

  # Convert a comma-separated string to an array
  IFS=',' read -ra APP_ARRAY <<< "$APP"
}

format_input_app_string

for APPLICATION in "${APP_ARRAY[@]}"
do
    echo "Installing APP: ${APPLICATION}"
    load_environment_${APPLICATION^^}
    install_${APPLICATION^^}
done
