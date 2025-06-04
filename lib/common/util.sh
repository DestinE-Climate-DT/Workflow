#!/bin/bash

#####################################################
# In platforms where internet connection is not
# available, we need to download raps dependencies
# in the local setup
# This function will be overwritten in platforms
# without internet access.
# Globals:
# Arguments:
#
#####################################################

function pre-configuration-ifs() {
    true
}

#####################################################
# Function used as a default. Overloaded
# by platform dependent functions in lib/HPCARCH
# Globals:
# Arguments:
#
#####################################################
function pre-configuration-icon() {
    true
}

#####################################################
# Function used as a default. Overloaded
# by platform dependent functions in lib/HPCARCH
# Globals:
# Arguments:
#
#####################################################
function pre-configuration-nemo() {
    true
}

#####################################################
# Function used as a default. Overloaded
# by platform dependent functions in lib/HPCARCH
# Globals:
# Arguments:
#
#####################################################
function checker_nemo() {
    if [ "${COMPILE,,}" == "true" ]; then
        # compilation is currently not working for NEMO
        echo "Please set COMPILE to False and use a pre-compiled version for NEMO."
        exit 1
    else
        true
    fi
}

#####################################################
# Passes the SLURM variables onto variables used
# in hres for IFS-based models.
#####################################################
function load_variables_ifs() {
    export nodes=${SLURM_JOB_NUM_NODES}
    export mpi=${SLURM_NPROCS}
    export omp=${SLURM_CPUS_PER_TASK}

    export jobid=${SLURM_JOB_ID}
    export jobname=${SLURM_JOB_NAME}
}

#####################################################
# Deletes IFS rundir in the INI step for a clean run
# Globals:
#    HPCROOTDIR
# Arguments:
#
#####################################################
function rm_rundir_ifs() {
    rm -rf "$HPCROOTDIR"/rundir
}

#####################################################
# Deletes ICON rundir in the INI step for a clean run
# Globals:
#    HPCROOTDIR
# Arguments:
#
#####################################################
function rm_rundir_icon() {
    true
}

#####################################################
# Computes the member number, taking the list from
# %EXPERIMENT.MEMBERS% and %MEMBER%
# Globals:
# Arguments:
# MEMBERS_LIST
# MEMBER
#
#####################################################
function get_member_number() {
    MEMBERS_LIST=$1
    MEMBER=$2

    # Split MEMBERS_LIST into an array
    read -r -a MEMBERS_ARRAY <<<"$MEMBERS_LIST"

    # Find the index of the MEMBER in MEMBERS_ARRAY
    MEMBER_NUMBER=0
    for i in "${!MEMBERS_ARRAY[@]}"; do
        if [ "${MEMBERS_ARRAY[$i]}" == "$MEMBER" ]; then
            MEMBER_NUMBER=$((i + 1))
            break
        fi
    done

    # Print or use the computed MEMBER_NUMBER as needed
    if [ "$MEMBER_NUMBER" -ne 0 ]; then
        echo $MEMBER_NUMBER
    else
        echo "Member not found in the list."
        exit 1
    fi
}

#####################################################
# Function to print fdb related information
# Globals:
#   EXPVER
# Returns:
#   - None
#####################################################

function print_data_gov() {
    singularity exec --cleanenv --no-home \
        --env "FDB_HOME=$(realpath ${FDB_HOME})" \
        --env "EXPVER=${EXPVER}" \
        --bind "${HPCROOTDIR}" \
        --bind "${HPC_SCRATCH}" \
        --bind "${DEVELOPMENT_PROJECT_SCRATCH}" \
        --bind "${OPERATIONAL_PROJECT_SCRATCH}" \
        --bind "$(realpath ${FDB_HOME})" \
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

#####################################################
# Compiles IFS-Nemo model using RAPS
# Globals:
#   HPCROOTDIR
#   PROJDEST
#   MODEL
#   NUMPROC
# Arguments:
#   arch
#   add_flags
######################################################
function compile_ifs-nemo() {

    arch=$1
    add_flags=${2:-""}

    cd "${INSTALL_DIR}"/
    ./ifs-bundle create -j4 --shallow

    # Start the bundle build process
    if [ ! -d "build" ]; then
        ./ifs-bundle build --arch ${arch} --with-single-precision \
            --with-double-precision-nemo --nemo-version=V40 \
            --nemo-grid-config=eORCA1_GO8_Z75 --nemo-ice-config=SI3 \
            --with-multio-for-nemo-sglexe --dry-run \
            --nemovar-grid-config=ORCA1_Z42 --nemovar-ver=DEV ${add_flags}

        cd build
        ./configure.sh
    fi

    if [ ! -f "${INSTALL_DIR}/build/bin/ifsMASTER.SP" ]; then
        cd "${INSTALL_DIR}"/build
        source env.sh
        make -j 20 VERBOSE=1 | tee raps_make.log

    fi

    if [ -f "${INSTALL_DIR}/build/bin/ifsMASTER.SP" ]; then
        echo "Compilation sucessful"
    else
        echo "Compilation failed. There is no ifsMASTER.SP"
        exit 1
    fi

    cd "${INSTALL_DIR}/source/raps"
    set +e
    source initbm
    set -e

    # Print the versions of the used modules
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

############################################
# Loads the fdb config for ifs-based models
# Globals:
#   FDB_HOME
#   EXPID
#   HPCROOTDIR
#   MODEL_NAME
#   RUN_TYPE
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

        cp "${HPCROOTDIR}/LOG_${EXPID}/config${FDB_prefix,,}_REMOTE_SETUP" "${FDB_DIR_PATH}/etc/fdb/config.yaml"
        cp "${SCRIPTDIR}/FDB/schema" "${FDB_DIR_PATH}/etc/fdb/schema"
    done
}

#####################################################
# Loads the fdb config for icon-based models
# Globals:
#   HPCROOTDIR
#   RUN_TYPE
#   FDB_DIR
# Arguments:
######################################################

function load_fdb_icon() {

    mkdir -p "${FDB_HOME}/etc/fdb"

    cp "${HPCROOTDIR}/LOG_${EXPID}/config_REMOTE_SETUP" "${FDB_HOME}/etc/fdb/config.yaml"
    cp "${SCRIPTDIR}/FDB/schema" "${FDB_HOME}/etc/fdb/schema"
}

###############################################################################
# Function to check the input directories for NEMO standalone
# TODO
###############################################################################
function checker_inproot_nemo() {
    true
}

###############################################################################
# Function to compile NEMO standalone
# Globals:
#   INSTALL_DIR
# Arguments:
###############################################################################
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

###############################################################################
# Function to check the environment variables for NEMO
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
###############################################################################
function check_nemo_env_vars() {
    [ -z "$ARCH_NAME" ] && {
        echo "Error: ARCH_NAME not set in env. Check env file"
        exit 1
    }
    [ -z "$NEMO_NETCDF_FORTRAN_PATH" ] && {
        echo "Error: NEMO_NETCDF_FORTRAN_PATH not set in env. Check env file"
        exit 1
    }
    [ -z "$NEMO_NETCDF_C_PATH" ] && {
        echo "Error: NEMO_NETCDF_C_PATH not set in env. Check env file"
        exit 1
    }
    [ -z "$NEMO_HDF5_PATH" ] && {
        echo "Error: NEMO_HDF5_PATH not set in env. Check env file"
        exit 1
    }
    [ -z "$NEMO_XIOS_PATH" ] && {
        echo "Error: NEMO_XIOS_PATH not set in env. Check env file"
        exit 1
    }
    [ -z "$NEMO_CPP" ] && {
        echo "Error: NEMO_CPP not set in env. Check env file"
        exit 1
    }
    [ -z "$NEMO_CC" ] && {
        echo "Error: NEMO_CC not set in env. Check env file"
        exit 1
    }
    [ -z "$NEMO_FC" ] && {
        echo "Error: NEMO_FC not set in env. Check env file"
        exit 1
    }
    [ -z "$NEMO_FCFLAGS" ] && {
        echo "Error: NEMO_FCFLAGS not set in env. Check env file"
        exit 1
    }
    [ -z "$NEMO_LDFLAGS" ] && {
        echo "Error: NEMO_LDFLAGS not set in env. Check env file"
        exit 1
    }
    [ -z "$NEMO_FPPFLAGS" ] && {
        echo "Error: NEMO_FPPFLAGS not set in env. Check env file"
        exit 1
    }
}

###############################################################################
# Function to generate the NEMO environment file
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
###############################################################################
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

############################################################
# Function to install AQUA
# Globals:
#   HPCARCH-short
#   HPCROOTDIR
#   PROJDEST
#   CATALOG-NAME
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
        aqua catgen -p "${DATA_PORTFOLIO}" -c "${HPCROOTDIR}/LOG_${EXPID}/config_catalog_REMOTE_SETUP"
    else
        echo "The catalog entry for your experiment already exists."
    fi
    '
}

###############################################################################
# Function to fix first day missing in constant variables
# Globals:
#   HPCROOTDIR
#   SCRIPTDIR
# Arguments:
#   LIBDIR
#   DQC_PROFILE_PATH
#   EXPVER
#   EXPERIMENT
#   ACTIVITY
#   MODEL_NAME
#   FIRST_DATE
#   LAST_DATE
#   CHUNK
#   FDB_HOME
#   GENERATION
###############################################################################
function fix_constant_variables() {
    LIBDIR=$1
    DQC_PROFILE_PATH=$2
    EXPVER=$3
    EXPERIMENT=$4
    ACTIVITY=$5
    MODEL_NAME=$6
    FIRST_DATE=$7
    LAST_DATE=$8
    CHUNK=$9
    FDB_HOME=${10}
    REALIZATION=${11:-1}
    GENERATION=${12:-1}

    cd "${HPCROOTDIR}"
    export FDB_HOME="${FDB_HOME}"

    if [ "${CHUNK}" = "1" ]; then
        for PROFILE in ${DQC_PROFILE_PATH}/sfc_daily_*.yaml; do
            if [ -f "${PROFILE}" ]; then
                echo "Fixing missing first date in profile ${PROFILE}"

                # Name of resulting GRIB file
                GRIB_FILE_NAME="$(basename "${PROFILE}" ".yaml")_chunk_${CHUNK}.grb"

                # Retrieve GRIB file from a profile YAML file
                python3 "${SCRIPTDIR}/FDB/yaml_to_mars_retrieve.py" --file="${PROFILE}" \
                    --expid="${EXPVER}" --experiment="${EXPERIMENT,,}" --activity="${ACTIVITY,,}" \
                    --model="${MODEL_NAME,,}" --realization="${REALIZATION}" \
                    --startdate="${LAST_DATE}" --enddate="${LAST_DATE}" --generation="${GENERATION}" \
                    --chunk="${CHUNK}" --grib_file_name="${GRIB_FILE_NAME}"

                # Set date of first date of CHUNK
                grib_set -s date="${FIRST_DATE}" "${GRIB_FILE_NAME}" fixed.grb

                # Write date-fixed file in FDB
                fdb-write fixed.grb

                # Remove tempfiles
                rm "${GRIB_FILE_NAME}" fixed.grb
            fi
        done
    fi
}

#####################################################
# Function to prepare the transfer of a profile
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
#   REALIZATION
#   MARS_BINARY
# Arguments:
#   profile_file
#####################################################
function prepare_transfer() {

    profile_file=$1

    if [ ! -f "${BASE_NAME}_COMPLETED" ]; then

        python3 "${SCRIPTDIR}/FDB/yaml_to_mars_retrieve.py" --file="$profile_file" \
            --expid="${EXPVER}" --startdate="${START_DATE}" --experiment="${EXPERIMENT,,}" \
            --realization="${REALIZATION}" --enddate="${SECOND_TO_LAST_DATE}" --chunk="${CHUNK}" \
            --model="${MODEL_NAME,,}" --activity="${ACTIVITY,,}" --generation="${GENERATION}" \
            --grib_file_name="${GRIB_FILE_NAME}"

        python3 "${SCRIPTDIR}/FDB/yaml_to_mars_archive.py" --file="$profile_file" \
            --expid="${EXPVER}" --startdate="${START_DATE}" --experiment="${EXPERIMENT,,}" \
            --enddate="${SECOND_TO_LAST_DATE}" --chunk="${CHUNK}" --realization="${REALIZATION}" \
            --generation="${GENERATION}" --model="${MODEL_NAME,,}" --activity="${ACTIVITY,,}" \
            --grib_file_name="${GRIB_FILE_NAME}" --databridge_database="${DATABRIDGE_DATABASE}"

    fi

}

#####################################################
# Function to check the number of messages in the
# profile file
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
        --enddate="${SECOND_TO_LAST_DATE}" --chunk="${CHUNK}" --model="${MODEL_NAME,,}" \
        --activity="${ACTIVITY,,}" --generation="${GENERATION}" --realization="${REALIZATION}" \
        --omit-keys "time,levelist" --request_name="${FLAT_REQ_NAME}"

    FDB_LIST_OUTPUT="$(basename $profile_file | cut -d. -f1)_${CHUNK}_list.log"
    fdb-list --raw --porcelain "$(<${FLAT_REQ_NAME})" >"${FDB_LIST_OUTPUT}"
    LISTED_MESSAGES=$(cat ${FDB_LIST_OUTPUT} | wc -l)

    EXPECTED_MESSAGES=$(python3 "${SCRIPTDIR}/FDB/count_expected_messages.py" \
        --file="$profile_file" --expver="${EXPVER}" --startdate="${START_DATE}" \
        --experiment="${EXPERIMENT,,}" --enddate="${SECOND_TO_LAST_DATE}" \
        --chunk="${CHUNK}" --model="${MODEL_NAME,,}" --activity="${ACTIVITY,,}" \
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

    python3 "${SCRIPTDIR}/FDB/yaml_to_flat_request.py" --file="${GENERAL_REQUEST}" \
        --expver="${EXPVER}" --startdate="${START_DATE}" --experiment="${EXPERIMENT,,}" \
        --enddate="${SECOND_TO_LAST_DATE}" --chunk="${CHUNK}" --model="${MODEL_NAME,,}" \
        --activity="${ACTIVITY,,}" --generation="${GENERATION}" --realization="${REALIZATION}" \
        --request_name="${FLAT_REQ_NAME}" --omit-keys="time,levelist,param,levtype,resolution"
    wipe_command="fdb-wipe --minimum-keys ${MINIMUM_KEYS}"
    if [ ${WIPE_DOIT,,} == "true" ]; then
        wipe_command+=" --doit"
    fi
    wipe_command+=" $(<${FLAT_REQ_NAME})"
    $wipe_command
}

#####################################################
# Selects the host based on the PU
# Globals:
#   None
# Arguments:
#   PU
#   RAPS_HOST_CPU
#   RAPS_HOST_GPU
#####################################################
function get_host_for_raps() {
    # Input
    PU=$1
    RAPS_HOST_CPU=$2
    RAPS_HOST_GPU=$3

    case $PU in
    cpu)
        host=$RAPS_HOST_CPU
        ;;
    gpu)
        host=$RAPS_HOST_GPU
        ;;
    *)
        echo "ERROR: Unknown PU=$PU in $0::${FUNCNAME[0]}"
        exit 1
        ;;
    esac

    # Return
    echo $host
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

#####################################################
# Translates ISO8601 time duration format to its
# equivalent in seconds.
# Globals:
# Arguments:
#  iso8601 time duration
######################################################
iso8601_to_seconds() {
    duration=$1
    seconds=0

    # Check if "M" (months) and/or "Y" (years) unit is present
    if [[ $"${duration%%T*}" =~ ('Y'|'M') ]]; then
        echo "Error: Yearly and/or monthly durations are not supported. Exiting."
        return 1
    fi

    # Extracting components (days, hours, minutes, seconds)
    for unit in D H M S; do
        value=$(echo $duration | grep -oP "\d+$unit" | sed "s/$unit//")
        if [ -n "$value" ]; then
            case $unit in
            D) ((seconds += value * 86400)) ;;
            H) ((seconds += value * 3600)) ;;
            M) ((seconds += value * 60)) ;;
            S) ((seconds += value)) ;;
            esac
        fi
    done

    echo $seconds
}

#####################################################
# Detect if the first day of a month is contained in the split
# Arguments:
#   START_DATE
#   SECOND_TO_LAST_DATE
#   END_MONTH
#   END_YEAR
######################################################

# Function to determine if the first day of the month is within the date range
function enable_process_monthly() {
    local start_date="$1"
    local split_end_date="$2"

    # Get first date of the month corresponding to the start date
    local start_date_month=$(date -d "${start_date}" +'%m')
    local start_date_year=$(date -d "${start_date}" +'%Y')
    local first_day_of_month=$(date -d "${start_date_year}${start_date_month}01" +'%Y%m%d')

    # to avoid issues with the while loop, check that the start date is before the split end date
    # convert both dates to seconds since epoch
    local start_date_epoch=$(date -d "${start_date}" +%s)
    local split_end_date_epoch=$(date -d "${split_end_date}" +%s)
    if [[ $start_date_epoch -gt $split_end_date_epoch ]]; then
        echo "Start date is after split end date. Exiting."
        exit 1
    fi

    # Enable PROCESS_MONTHLY only if the first day of the month is in the date list
    local process_monthly="false"
    local date="$start_date"
    while [[ "$date" != "$split_end_date" ]]; do
        if [[ "$date" == "$first_day_of_month" ]]; then
            process_monthly="true"
            break
        fi
        date=$(date --date="$date + 1 day" +%Y%m%d)
    done

    echo "$process_monthly"
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
#   CONTAINER_DIR
# Arguments:
#   profile_file
######################################################
function retrieve_and_create_requests() {

    cd ${TRANSFER_REQUESTS_PATH}

    profile_file=$1

    ${CONTAINER_COMMAND} exec --cleanenv --no-home \
        --env "FDB_HOME=${FDB_HOME}" \
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
        --env "CHUNK_SECOND_TO_LAST_DATE=${CHUNK_SECOND_TO_LAST_DATE}" \
        --env "TRANSFER_REQUESTS_PATH=${TRANSFER_REQUESTS_PATH}" \
        --env "TRANSFER_MONTHLY=${TRANSFER_MONTHLY}" \
        --env "SCRATCH_DIR=${SCRATCH_DIR}" \
        --env "HPC=${HPC}" \
        --env "MARS_BINARY=${MARS_BINARY}" \
        --env "DATABRIDGE_DATABASE=${DATABRIDGE_DATABASE}" \
        --env "CONTAINER_DIR=${CONTAINER_DIR}" \
        --bind "$(realpath $PWD)" \
        --bind "$(realpath ${SCRATCH_DIR})" \
        --bind "$(realpath ${LIBDIR}/common)" \
        --bind "$(realpath ${SCRIPTDIR}/FDB)" \
        --bind "$(realpath ${DQC_PROFILE_PATH})" \
        --bind "$(realpath ${FDB_HOME})" \
        --bind "${FDB_HOME}" \
        --bind "${DEVELOPMENT_PROJECT_SCRATCH}" \
        --bind "$(realpath ${DEVELOPMENT_PROJECT_SCRATCH})" \
        --bind "${OPERATIONAL_PROJECT_SCRATCH}" \
        "${CONTAINER_DIR}/gsv/gsv_${GSV_VERSION}.sif" \
        bash -c \
        '
        set -xuve

        . "${LIBDIR}"/common/util.sh
        # lib/common/util.sh (prepare_transfer) (auto generated comment)
        prepare_transfer ${profile_file}
        '
}

#####################################################
# Purges duplicated data.
# Globals:
#   CLEAN_DIR
#   SCRIPTDIR
#   EXPVER
#   START_DATE
#   EXPERIMENT
#   GENERATION
#   REALIZATION
#   SECOND_TO_LAST_DATE
#   CHUNK
#   MODEL_NAME
#   ACTIVITY
#   TRANSFER_REQUESTS_PATH
# Arguments:
#   profile_file
######################################################
function purge_duplicated_data() {

    profile_file=$1

    # Run FDB purge
    FLAT_REQ_NAME="$(basename $profile_file | cut -d. -f1)_${CHUNK}_request.flat"

    CLEAN_DIR=${HPCROOTDIR}/clean_requests/
    mkdir -p ${CLEAN_DIR}

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
        # set up for the purge
        FLAT_REQ_NAME="$(basename $profile_file | cut -d. -f1)_${CHUNK}_request.flat"
        CLEAN_DIR="${HPCROOTDIR}/clean_requests/"
        mkdir -p ${CLEAN_DIR}

        MINIMUM_KEYS="class,dataset,experiment,activity,expver,model,generation,realization,stream"
        OMIT_KEYS="time,levelist,param,levtype,type,resolution"
        if [[ "$profile_file" == *monthly* ]]; then
            MINIMUM_KEYS+=",year"
            OMIT_KEYS+=",month"
        else
            MINIMUM_KEYS+=",date"
        fi

        cd ${CLEAN_DIR}
        # Convert YAML profile to flat request file
        python3 "${SCRIPTDIR}/FDB/yaml_to_flat_request.py" \
            --file="${profile_file}" --expver="${EXPVER}" --startdate="${START_DATE}" \
            --experiment="${EXPERIMENT}" --generation="${GENERATION}" \
            --realization="${REALIZATION}" --enddate="${SECOND_TO_LAST_DATE}" \
            --chunk="${CHUNK}" --model="${MODEL_NAME^^}" --activity="${ACTIVITY}" \
            --request_name="${FLAT_REQ_NAME}" --omit-keys="${OMIT_KEYS}"
        # Purge data using FDB purge command
        fdb purge --ignore-no-data --doit --minimum-keys ${MINIMUM_KEYS} "$(<${FLAT_REQ_NAME})" >/dev/null

        '
}

#####################################################
# Check if the profiles exist already. We should generate them in the first transfer that
# runs.
# Globals:
#   CURRENT_ROOTDIR
#   PROJDEST
#   DQC_PROFILE_ROOT
#   CONTAINER_COMMAND
#   DATA_PORTFOLIO
#   DQC_PROFILE
#   HPC_CONTAINER_DIR
#   GSV_VERSION
######################################################
function generate_profiles() {

    DATA_PORTFOLIO_PATH="${CURRENT_ROOTDIR}/${PROJDEST}/data-portfolio"
    cd ${DATA_PORTFOLIO_PATH}
    DATA_PORTFOLIO_VERSION=$(git describe --exact-match --tags)
    mkdir -p ${DQC_PROFILE_ROOT}

    if [ ! -f flag_profiles_generated ]; then
        echo "Generating profiles"
        ${CONTAINER_COMMAND} exec --cleanenv --no-home \
            --env DATA_PORTFOLIO_PATH="${DATA_PORTFOLIO_PATH}" \
            --env DATA_PORTFOLIO="${DATA_PORTFOLIO}" \
            --env DQC_PROFILE="${DQC_PROFILE}" \
            --env DATA_PORTFOLIO_VERSION="${DATA_PORTFOLIO_VERSION}" \
            --env DQC_PROFILE_ROOT="${DQC_PROFILE_ROOT}" \
            --bind "$PWD" \
            --bind "${DQC_PROFILE_ROOT}" \
            "$HPC_CONTAINER_DIR"/gsv/gsv_${GSV_VERSION}.sif \
            bash -c \
            ' set -xuve
            python3 -m gsv.dqc.profiles.scripts.generate_profiles -r "${DATA_PORTFOLIO_PATH}" \
            -p "${DATA_PORTFOLIO}" -c "${DQC_PROFILE}" -t "${DATA_PORTFOLIO_VERSION}" \
            -o "${DQC_PROFILE_ROOT}" '
        touch flag_profiles_generated
    else
        echo "Profiles already generated"
        return 0
    fi

}
