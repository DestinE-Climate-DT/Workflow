#!/bin/bash
#
# This step loads the necessary enviroment and then compiles the diferent models
set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
CURRENT_ROOTDIR=${2:-%CURRENT_ROOTDIR%}
PROJDEST=${3:-%PROJECT.PROJECT_DESTINATION%}
MODEL_NAME=${4:-%MODEL.NAME%}
MODEL_ROOT_PATH=${5:-%MODEL.ROOT_PATH%}
CURRENT_ARCH=${6:-%CURRENT_ARCH%}
MODEL_VERSION=${7:-%MODEL.VERSION%}
ENVIRONMENT=${8:-%RUN.ENVIRONMENT%}
HPCARCH=${9:-%HPCARCH%}
ATM_GRID=${10:-%MODEL.GRID_ATM%}
PU=${11:-%RUN.PROCESSOR_UNIT%}
HPC_PROJECT=${12:-%CONFIGURATION.HPC_PROJECT_DIR%}
EXPID=${13:-%DEFAULT.EXPID%}
DVC_INPUTS_BRANCH=${14:-%MODEL.DVC_INPUTS_BRANCH%}
INSTALL=${15:-%CONFIGURATION.INSTALL%} #local (default) or shared
WORKFLOW=${16:-%RUN.WORKFLOW%}
APP=${17:-%APP.NAMES%}
RUN_TYPE=${18:-%RUN.TYPE%}
IFS_EXPVER=${19:-%CONFIGURATION.IFS.EXPVER%}
IFS_LABEL=${20:-%CONFIGURATION.IFS.LABEL%}
DATELIST=${21:-%EXPERIMENT.DATELIST%}
ICMCL=${22:-%MODEL.ICMCL_PATTERN%}
CATALOG_NAME=${23:-%HPCCATALOG_NAME%}
AQUA_ON=${24:-%CONFIGURATION.ADDITIONAL_JOBS.AQUA%}
AQUA_REGENCAT=${25:-%AQUA.REGENERATE_CATALOGS%}
HPCARCH_short=${26:-%CURRENT_HPCARCH_SHORT%}
DQC_ACTIVE=${27:-%CONFIGURATION.ADDITIONAL_JOBS.DQC%}
DQC_PROFILE=${28:-%CONFIGURATION.DQC_PROFILE%}
DATA_PORTFOLIO=${29:-%CONFIGURATION.DATA_PORTFOLIO%}
DQC_PROFILE_ROOT=${30:-%CONFIGURATION.DQC_PROFILE_ROOT%}
GSV_VERSION=${31:-%GSV.VERSION%}
MODEL_PATH=${32:-%MODEL.PATH%}
MODEL_INPUTS=${33:-%MODEL.INPUTS%}
COMPILE=${34:-%MODEL.COMPILE%}

# Load ICON grid identifiers
ATM_GID=${35:-%CONFIGURATION.ICON.ATM_GID%}
OCE_GID=${36:-%CONFIGURATION.ICON.OCE_GID%}

# Load ICON grid res
ATM_GRID_REF=${37:-%CONFIGURATION.ICON.ATM_REF%}
OCE_GRID_REF=${38:-%CONFIGURATION.ICON.OCE_REF%}

SCRATCH=${39:-%CURRENT_SCRATCH_DIR%}
PROJECT=${40:-%CURRENT_PROJECT%}
HPC_PROJECT=${41:-%CONFIGURATION.HPC_PROJECT_DIR%}
FDB_HOME=${42:-%REQUEST.FDB_HOME%}
EXPVER=${43:-%REQUEST.EXPVER%}
CLASS=${44:-%REQUEST.CLASS%}
MODEL=${45:-%REQUEST.MODEL%}

CONTAINER_VERSION=${46:-%AQUA.CONTAINER_VERSION%}
HPC_SCRATCH=${47:-%CONFIGURATION.PROJECT_SCRATCH%}
HPC_CONTAINER_DIR=${48:-%CONFIGURATION.CONTAINER_DIR%}
CONTAINER_COMMAND=${49:-%CURRENT_CONTAINER_COMMAND%}

LIBDIR=${50:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${51:-%CONFIGURATION.SCRIPTDIR%}
DVC_INPUTS_CACHE=${52:-%CURRENT_DVC_INPUTS_CACHE%}
DVC_VERSION=${53:-%DVC.VERSION%}

ARCH_GPU=${54:-%CURRENT_ARCH_GPU%}
ARCH_CPU=${55:-%CURRENT_ARCH_CPU%}
ADDITIONAL_COMPILATION_FLAGS_CPU=${56:-%CURRENT_ADDITIONAL_COMPILATION_FLAGS_CPU%}
ADDITIONAL_COMPILATION_FLAGS_GPU=${57:-%CURRENT_ADDITIONAL_COMPILATION_FLAGS_GPU%}

FDB_INFO_FILE_PATH=${58:-%REQUEST.INFO_FILE_PATH%}
FDB_INFO_FILE_NAME=${59:-%REQUEST.INFO_FILE_NAME%}
BASE_VERSION=${60:-%BASE.VERSION%}
AQUA_START_DATE=${61:-%AQUA.START_DATE%}
GENERATE_PROFILES=${62:-%CONFIGURATION.GENERATE_PROFILES%}
DNB_FILE=${63:-%CURRENT_DNB_FILE%}

# END_HEADER

YEAR=${DATELIST::4}
ICMCL=${ICMCL:-ICMCL_%CONFIGURATION.IFS.RESOL%_${YEAR}_extra}

export MODEL_VERSION
export ENVIRONMENT
export HPCARCH
export HPCROOTDIR
export PROJDEST

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture

ATM_MODEL=${MODEL_NAME%%-*}
OCEAN_MODEL=${MODEL_NAME##*-}

# Main code
cd "$HPCROOTDIR"

# If tarfile exists in remote filesystem it's uncompressed
# Untar
if [ -f "${PROJDEST}".tar.gz ]; then
    tar xf "${PROJDEST}".tar.gz
fi

function format_input_app_string() {
    APP=${APP#\[} # Removing the leading '['
    APP=${APP%\]} # Removing the trailing ']'

    # Convert a comma-separated string to an array
    IFS=', ' read -ra APP_ARRAY <<<"$APP"
}

# lib/MARENOSTRUM5/config.sh (post_compilation_ifs-nemo) (auto generated comment)
function post_compilation_ifs-nemo() {
    true
}

function post_compilation_icon() {
    true
}

function post_compilation_nemo() {
    true
}

########################
# MAIN CODE
########################

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh
. "${LIBDIR}"/common/checkers.sh

# MODEL functions
if [ -n "${DVC_INPUTS_BRANCH}" ]; then
    # lib/LUMI/config.sh (load_singularity) (auto generated comment)
    # lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
    load_singularity
    # lib/common/util.sh (inputs_dvc_checkout) (auto generated comment)
    inputs_dvc_checkout ${DVC_INPUTS_CACHE}
fi

# MODEL MAIN CODE

if [ "${COMPILE,,}" == "true" ]; then
    # Installs de model in the shared directory
    cd "${HPCROOTDIR}/${PROJDEST}"
    INSTALL_DIR=${MODEL_PATH}
    mkdir -p "${INSTALL_DIR}"
    BUILD_DIR="${INSTALL_DIR}/build"
    if [ ! -d "${BUILD_DIR}" ]; then
        tar -czvf "${MODEL_NAME}".tar.gz "${MODEL_NAME}"
        mv "${MODEL_NAME}".tar.gz "${INSTALL_DIR}"
        cd "${INSTALL_DIR}"
        tar xf "${MODEL_NAME}".tar.gz --strip-components=1
        ln -fs "${MODEL_ROOT_PATH}"/inidata "${MODEL_ROOT_PATH}"/"${MODEL_VERSION}"/inidata
    else
        echo "There is already a MODEL_VERSION that contains a build with the same name"
        echo "You can't overwrite a MODEL_VERSION"
        exit 1
    fi
fi

# Checker
# lib/common/checkers.sh (checker_precompiled_model) (auto generated comment)
checker_precompiled_model

if [ "${WORKFLOW,,}" != "apps" ] && [ "${WORKFLOW,,}" != "simless" ]; then
    checker_inproot_"${MODEL_NAME}"
    # Creates fake production fdb if not in production, research or operational
    if [[ ! ${RUN_TYPE,,} =~ ^(production|research|operational|operational-read)$ ]]; then
        if [[ ${MODEL_NAME,,} != "nemo" ]]; then
            load_fdb_"${ATM_MODEL}"
        fi
    fi
fi

if [ "${MODEL_NAME,,}" != "nemo" ]; then
    if [ "${GENERATE_PROFILES,,}" == "true" ]; then
        # lib/LUMI/config.sh (load_singularity) (auto generated comment)
        # lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
        load_singularity
        # lib/common/util.sh (generate_profiles) (auto generated comment)
        generate_profiles
    fi
fi

if [ "${WORKFLOW,,}" != "model" ] && [ "${WORKFLOW,,}" != "simless" ]; then
    format_input_app_string
    for APPLICATION in "${APP_ARRAY[@]}"; do
        echo "${APPLICATION} is using container so no installation is needed"
    done
fi

if [ "${AQUA_ON,,}" == "true" ]; then
    AQUA="/app/AQUA"
    AQUA_CONTAINER="${HPC_CONTAINER_DIR}/aqua/aqua_${CONTAINER_VERSION}.sif"
    # lib/LUMI/config.sh (load_singularity) (auto generated comment)
    # lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
    load_singularity
    # lib/common/util.sh (install_aqua) (auto generated comment)
    install_aqua
fi

if [ "${WORKFLOW,,}" == "model" ] || [ "${WORKFLOW,,}" == "end-to-end" ]; then
    # NEMO only runs don't need FDB files
    if [ "${MODEL_NAME,,}" != "nemo" ]; then
        # lib/LUMI/config.sh (load_singularity) (auto generated comment)
        # lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
        load_singularity
        # If AQUA_START_DATE is not set, use the default value (DATELIST)
        if [ -z "${AQUA_START_DATE}" ]; then
            AQUA_START_DATE="${DATELIST}"
        fi
        export SINGULARITY_BIND="${SCRIPTDIR},${FDB_INFO_FILE_PATH},${HPCROOTDIR}"
        export SINGULARITYENV_SCRIPTDIR="${SCRIPTDIR}"
        export SINGULARITYENV_FDB_INFO_FILE_NAME="${FDB_INFO_FILE_NAME}"
        export SINGULARITYENV_HPCROOTDIR="${HPCROOTDIR}"
        export SINGULARITYENV_EXPVER="${EXPVER}"
        export SINGULARITYENV_MODEL="${MODEL}"
        export SINGULARITYENV_AQUA_START_DATE="${AQUA_START_DATE}"
        export SINGULARITYENV_EXPVER="${EXPVER}"
        singularity exec --no-home "${HPC_CONTAINER_DIR}"/gsv/gsv_${GSV_VERSION}.sif \
            bash -c 'set -xuve && python3 ${SCRIPTDIR}/FDB/update_fdb_info.py --create --file \
            ${FDB_INFO_FILE_NAME} --expver ${EXPVER} --data_start_date ${AQUA_START_DATE} '
    fi
fi

# Compile model sources if requested
if [ "${COMPILE}" == "True" ]; then
    if [ "${MODEL_NAME,,}" == "nemo" ]; then
        # compilation is currently not working for NEMO and blocked in local setup
        # lib/MARENOSTRUM5/config.sh (load_compile_env_nemo_intel) (auto generated comment)
        load_compile_env_nemo_intel
        compile_"${MODEL_NAME}"
    else
        # lib/common/util.sh (get_arch_compilation_flags) (auto generated comment)
        read arch add_flags <<<$(get_arch_compilation_flags "${PU}" "${ARCH_CPU}" "${ARCH_GPU}" "${ADDITIONAL_COMPILATION_FLAGS_CPU}" "${ADDITIONAL_COMPILATION_FLAGS_GPU}")
        compile_"${MODEL_NAME}" $arch $add_flags
    fi
    post_compilation_"${MODEL_NAME}"
else
    # If compilation path is given skip compilation
    echo "Path to a compiled model is given: ${MODEL_PATH}"
    echo "Skipping compilation"
fi
