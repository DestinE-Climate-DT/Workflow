#!/bin/bash

# Utils functions for remote_setup.sh

function post_compilation_ifs-nemo() {
    true
}

function post_compilation_icon() {
    true
}

function post_compilation_nemo() {
    true
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

###################################################
# Prints the commits and the versions of the
# used modules in ifs-bundle
###################################################
function print_rev_all {
    echo "path" "commit" "ref" "tag"
    echo "----" "------" "---" "---"
    for d in $(find source -maxdepth 1 -type d); do print_rev "$d"; done
}

#####################################################
# Compiles IFS-Nemo model using RAPS
# Globals:
#   INSTALL_DIR
# Arguments:
#   arch
#   add_flags
######################################################
function compile_ifs-nemo() {

    arch=$1
    add_flags=${2:-""}

    cd "${MODEL_PATH}"/
    ./ifs-bundle create -j4 --shallow

    # Start the bundle build process
    if [ ! -d "${BUNDLE_BUILD_DIR}" ]; then
        ./ifs-bundle build --arch ${arch} --with-single-precision \
            --with-double-precision-nemo --nemo-version=V40 \
            --nemo-grid-config=eORCA1_GO8_Z75 --nemo-ice-config=SI3 \
            --with-multio-for-nemo-sglexe --dry-run \
            --nemovar-grid-config=ORCA1_Z42 --nemovar-ver=DEV ${add_flags}

        cd ${BUNDLE_BUILD_DIR}
        ./configure.sh
    fi

    if [ ! -f "${BUNDLE_BUILD_DIR}/bin/ifsMASTER.SP" ]; then
        cd "${BUNDLE_BUILD_DIR}"
        source env.sh
        make -j 20 VERBOSE=1 | tee raps_make.log

    fi

    if [ -f "${BUNDLE_BUILD_DIR}/bin/ifsMASTER.SP" ]; then
        echo "Compilation sucessful"
    else
        echo "Compilation failed. There is no ifsMASTER.SP"
        exit 1
    fi

    cd "${BUNDLE_BUILD_DIR}/raps"
    set +e
    source initbm
    set -e

    # Print the versions of the used modules
    cd "${BUNDLE_BUILD_DIR}"
    print_rev_all | column -t >"bundle_versions"

}

#######################################################
# Function to generate the NEMO environment file
# Currently unused.
# Globals:
#   ARCH_NAME
#   NEMO_NETCDF_FORTRAN_PATH
#   NEMO_NETCDF_C_PATH
#   NEMO_HDF5_PATH
#   NEMO_XIOS_PATH
#   NEMO_CPP
#   NEMO_CC
#   NEMO_FC
#   NEMO_FCFLAGS
#   NEMO_LDFLAGS
#   NEMO_FPPFLAGS
# Arguments:
#######################################################
function generate_nemo_env_file() {
    cat >arch/arch-$ARCH_NAME.fcm <<EOF
%NCDF_INC            -I$NEMO_NETCDF_FORTRAN_PATH/include
%NCDF_LIB            -L$NEMO_NETCDF_FORTRAN_PATH/lib -L$NEMO_NETCDF_C_PATH/lib -L$NEMO_HDF5_PATH/lib -lhdf5 -lhdf5_hl -lnetcdf -lnetcdff
%XIOS_INC            -I$NEMO_XIOS_PATH/inc
%XIOS_LIB            -L$NEMO_XIOS_PATH/lib -lxios -lstdc++
%CPP                 $NEMO_CPP
%CC                  $NEMO_CC
%FC                  $NEMO_FC
%FCFLAGS             $NEMO_FCFLAGS
%FFLAGS              %FCFLAGS
%LD                  %FC
%LDFLAGS             $NEMO_LDFLAGS
%FPPFLAGS            $NEMO_FPPFLAGS
%AR                  ar
%ARFLAGS             rs
%MK                  gmake
%USER_INC            %NCDF_INC %XIOS_INC
%USER_LIB            %NCDF_LIB %XIOS_LIB
EOF

}

######################################################
# Function to compile NEMO standalone.
# Currently unused.
# Globals:
#   INSTALL_DIR
#   CURRENT_ARCH
#   ENVIRONMENT
#   DNB_FILE
# Arguments:
######################################################
function compile_nemo() {

    echo "Starting compilation now..."

    cd "${INSTALL_DIR}/make/${CURRENT_ARCH}-${ENVIRONMENT}/"
    generate_nemo_env_file

    NEMO_CFG="ORCA2"
    NEMO_MAKE_PARALLEL_LEVEL=16
    NEMO_SUBCOMPONENTS="OCE ICE"
    NEMO_KEYS_TO_DELETE="key_top"
    NEMO_KEYS_TO_ADD="key_asminc key_netcdf4 key_sms key_xios2 key_nosignedzero"

    ln -sf ${DNB_FILE} machine.yaml
    # This is a download phase of the build process.
    ./dnb.sh :du
    # Build
    ./dnb.sh :bi
}

#####################################################
# Compiles IFS-Fesom model using RAPS
# Globals:
#   HPCROOTDIR
#   PROJDEST
#   MODEL_NAME
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
# Compiles the ICON model differentiating between PU's
# Globals:
#   HPCROOTDIR
#   PROJDEST
#   PU
# Arguments:
######################################################
function compile_icon() {
    # Path to model
    local ICON_PATH=${HPCROOTDIR}/${PROJDEST}/icon-mpim
    # Load environment and create Makefile
    cd "${ICON_PATH}"
    # Compile CPU/GPU Binaries
    compile_icon_"${PU}"
}

############################################
# Loads the fdb config for ifs-based models
# Globals:
#   MODEL_VERSION
#   HPCROOTDIR
#   PROJDEST
#   MODEL_NAME
#   MODEL_PATH
#   FDB_HOME
# Arguments:
#   None
############################################
function load_fdb_ifs() {
    # Directory definition
    if [ -z "${MODEL_VERSION}" ]; then
        RAPS_BIN="${HPCROOTDIR}/${PROJDEST}/${MODEL_NAME}/source/raps/bin"
    else
        RAPS_BIN="${MODEL_PATH}/source/raps/bin"
    fi

    mkdir -p ${FDB_HOME}
    cd ${FDB_HOME}
    FDB_DIRS=("native" "." "latlon")

    for FDB in "${FDB_DIRS[@]}"; do
        FDB_DIR_PATH="${FDB_HOME}/${FDB}"
        mkdir -p "${FDB_DIR_PATH}/etc/fdb"
        chmod -R 750 "${FDB_DIR_PATH}"

        FDB_prefix="${FDB//./}"

        cp "${HPCROOTDIR}/LOG_${EXPID}/config${FDB_prefix,,}_${START_DATE}_REMOTE_SETUP" "${FDB_DIR_PATH}/etc/fdb/config.yaml"
        cp "${SCRIPTDIR}/FDB/schema" "${FDB_DIR_PATH}/etc/fdb/schema"
    done
}

#####################################################
# Loads the fdb config for icon-based models
# Globals:
#   HPCROOTDIR
#   RUN_TYPE
#   FDB_DIR
#   CHUNK_START_DATE
# Arguments:
######################################################
function load_fdb_icon() {

    mkdir -p "${FDB_HOME}/etc/fdb"

    cp "${HPCROOTDIR}/LOG_${EXPID}/config_${START_DATE}_REMOTE_SETUP" "${FDB_HOME}/etc/fdb/config.yaml"
    cp "${SCRIPTDIR}/FDB/schema" "${FDB_HOME}/etc/fdb/schema"
}

############################################################
# Function to install AQUA
# Globals:
#   HPCARCH-short
#   HPCROOTDIR
#   PROJDEST
#   CATALOG_NAME
#   AQUA
#   EXPID
#   EXPVER
#   MODEL
#   DATA_PORTFOLIO
#   START_DATE
#   AQUA_CONTAINER
# Arguments:
############################################################
function install_aqua() {
    if [ -d ${HPCROOTDIR}/.aqua ]; then
        mv ${HPCROOTDIR}/.aqua ${HPCROOTDIR}/.aqua_$(date "+%Y%m%d%H%M%S")
    fi
    singularity exec \
        --cleanenv \
        --env PYTHONPATH=/opt/conda/lib/python3.10/site-packages \
        --env ESMFMKFILE=/opt/conda/lib/esmf.mk \
        --env PYTHONPATH=$AQUA \
        --env AQUA=$AQUA \
        --env AQUA_REGENCAT=$AQUA_REGENCAT \
        --env HPCARCH_short=$HPCARCH_short \
        --env HPCROOTDIR=$HPCROOTDIR \
        --env PROJDEST=$PROJDEST \
        --env CATALOG_NAME=$CATALOG_NAME \
        --env EXPID=$EXPID \
        --env EXPVER=$EXPVER \
        --env MODEL=$MODEL \
        --env DATA_PORTFOLIO=$DATA_PORTFOLIO \
        --env START_DATE=$START_DATE \
        --env AUTHOR=$USER \
        --bind=${HPCROOTDIR} \
        $AQUA_CONTAINER \
        bash -c \
        '
    set -xuve

    # Install AQUA
    yes n | aqua install ${HPCARCH_short} -p "${HPCROOTDIR}/.aqua"
    export AQUA_CONFIG="${HPCROOTDIR}/.aqua"

    # Install the working catalog
    if [ ! -d "${AQUA_CONFIG}/catalogs/${CATALOG_NAME}" ]; then
        aqua add "${CATALOG_NAME}" -e "${HPCROOTDIR}/${PROJDEST}/catalog/catalogs/${CATALOG_NAME}"
    else
        # its a re-run
	    echo "${CATALOG_NAME} is already installed"
    fi

    # Install the obs catalog
    if [ ! -d "${AQUA_CONFIG}/catalogs/obs" ]; then
        aqua add obs -e "${HPCROOTDIR}/${PROJDEST}/catalog/catalogs/obs"
    else
        echo "Obs catalog is already installed"
    fi

    CATALOG_DIR="${AQUA_CONFIG}/catalogs/${CATALOG_NAME}/catalog/${MODEL}/"
    CATALOG_FILE="${HPCROOTDIR}/${PROJDEST}/catalog/catalogs/${CATALOG_NAME}/catalog/${MODEL}/${EXPVER}.yaml"

    # Create catalog directory with -p (if it doesnt exist)
    mkdir -p ${CATALOG_DIR}

    # Regenerate depending on regen_cat key
    if [ "${AQUA_REGENCAT,,}" = "true" ] || [ ! -f "${CATALOG_FILE}" ]; then
        # Remove existing catalog if regenerating
        if [ "${AQUA_REGENCAT,,}" = "true" ] && [ -f "${CATALOG_FILE}" ]; then
            echo "Removing existing catalog file as key REGENERATE_CATALOGS is TRUE."
            rm "${CATALOG_FILE}"
        fi

        echo "Generating catalog..."
        aqua catgen -p "${DATA_PORTFOLIO}" -c "${HPCROOTDIR}/LOG_${EXPID}/config_catalog_${START_DATE}_REMOTE_SETUP"
    else
        echo "The catalog entry for your experiment already exists."
    fi
    '
}

#####################################################
# Function to check out the inputs
# Globals:
#    HPCROOTDIR
#    PROJDEST
# Arguments:
#    DVC_INPUTS_CACHE
#####################################################
function inputs_dvc_checkout() {
    DVC_PATH="$HPCROOTDIR/$PROJDEST/dvc-cache-de340"
    cache_dir=$1
    singularity exec \
        --cleanenv --no-home --bind "$DVC_PATH" \
        --bind "$cache_dir" --env cache_dir="$cache_dir" \
        --env HPC_CONTAINER_DIR="$HPC_CONTAINER_DIR" \
        --env DVC_VERSION="$DVC_VERSION" \
        --env DVC_PATH="$DVC_PATH" \
        "${HPC_CONTAINER_DIR}"/dvc/dvc_${DVC_VERSION}.sif \
        bash -c \
        "set -xuve && cd ${DVC_PATH} && dvc config cache.dir ${cache_dir} && dvc checkout"
}

#####################################################
# Selects the arch based on the PU
# Globals:
#   None
# Arguments:
#   PU
#   ARCH_CPU
#   ARCH_GPU
#####################################################
function get_arch_compilation_flags() {
    # Input
    PU=$1
    ARCH_CPU="$2"
    ARCH_GPU="$3"
    ADDITIONAL_COMPILATION_FLAGS_CPU="$4"
    ADDITIONAL_COMPILATION_FLAGS_GPU="$5"

    case $PU in
    cpu)
        arch=$ARCH_CPU
        add_flags=${ADDITIONAL_COMPILATION_FLAGS_CPU:-""}
        ;;
    gpu)
        arch=$ARCH_GPU
        add_flags=${ADDITIONAL_COMPILATION_FLAGS_GPU:-""}
        ;;
    *)
        echo "ERROR: Unknown PU=$PU in $0::${FUNCNAME[0]}"
        exit 1
        ;;
    esac

    # Return
    echo "$arch" "$add_flags"
}
