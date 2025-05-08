#!/bin/bash
#
# This step loads the necessary enviroment and then compiles the diferent models
set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL_NAME=${3:-%MODEL.NAME%}
MODEL_ROOT_PATH=${4:-%MODEL.ROOT_PATH%}
CURRENT_ARCH=${5:-%CURRENT_ARCH%}
MODEL_VERSION=${6:-%MODEL.VERSION%}
ENVIRONMENT=${7:-%RUN.ENVIRONMENT%}
HPCARCH=${8:-%HPCARCH%}
ATM_GRID=${9:-%MODEL.GRID_ATM%}
PU=${10:-%RUN.PROCESSOR_UNIT%}
HPC_PROJECT=${11:-%CONFIGURATION.HPC_PROJECT_DIR%}
EXPID=${12:-%DEFAULT.EXPID%}
DVC_INPUTS_BRANCH=${13:-%MODEL.DVC_INPUTS_BRANCH%}
INSTALL=${14:-%CONFIGURATION.INSTALL%} #local (default) or shared
WORKFLOW=${15:-%RUN.WORKFLOW%}
APP=${16:-%APP.NAMES%}
RUN_TYPE=${17:-%RUN.TYPE%}
IFS_EXPVER=${18:-%CONFIGURATION.IFS.EXPVER%}
IFS_LABEL=${19:-%CONFIGURATION.IFS.LABEL%}
DATELIST=${20:-%EXPERIMENT.DATELIST%}
ICMCL=${21:-%MODEL.ICMCL_PATTERN%}
CATALOG_NAME=${22:-%CURRENT_CATALOG_NAME%}
AQUA_ON=${23:-%CONFIGURATION.ADDITIONAL_JOBS.AQUA%}
AQUA_REGENCAT=${24:-%AQUA.REGENERATE_CATALOGS%}
HPCARCH_short=${25:-%CURRENT_HPCARCH_SHORT%}
DQC_ACTIVE=${26:-%CONFIGURATION.ADDITIONAL_JOBS.DQC%}
DQC_PROFILE=${27:-%CONFIGURATION.DQC_PROFILE%}
DATA_PORTFOLIO=${28:-%CONFIGURATION.DATA_PORTFOLIO%}
DQC_PROFILE_ROOT=${29:-%CONFIGURATION.DQC_PROFILE_ROOT%}
GSV_VERSION=${30:-%GSV.VERSION%}
MODEL_PATH=${31:-%MODEL.PATH%}
MODEL_INPUTS=${32:-%MODEL.INPUTS%}
COMPILE=${33:-%MODEL.COMPILE%}

# Load ICON grid identifiers
ATM_GID=${34:-%CONFIGURATION.ICON.ATM_GID%}
OCE_GID=${35:-%CONFIGURATION.ICON.OCE_GID%}
# Load ICON grid res
ATM_GRID_REF=${36:-%CONFIGURATION.ICON.ATM_REF%}
OCE_GRID_REF=${37:-%CONFIGURATION.ICON.OCE_REF%}

SCRATCH=${38:-%CURRENT_SCRATCH_DIR%}
PROJECT=${39:-%CURRENT_PROJECT%}
HPC_PROJECT=${40:-%CONFIGURATION.HPC_PROJECT_DIR%}
FDB_HOME=${41:-%REQUEST.FDB_HOME%}
EXPVER=${42:-%REQUEST.EXPVER%}
CLASS=${43:-%REQUEST.CLASS%}
MODEL=${44:-%REQUEST.MODEL%}

CONTAINER_VERSION=${45:-%AQUA.CONTAINER_VERSION%}
HPC_SCRATCH=${46:-%CONFIGURATION.PROJECT_SCRATCH%}
HPC_CONTAINER_DIR=${47:-%CONFIGURATION.CONTAINER_DIR%}

LIBDIR=${48:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${49:-%CONFIGURATION.SCRIPTDIR%}
DVC_INPUTS_CACHE=${50:-%CURRENT_DVC_INPUTS_CACHE%}
DVC_VERSION=${51:-%DVC.VERSION%}

ARCH_GPU=${52:-%CURRENT_ARCH_GPU%}
ARCH_CPU=${53:-%CURRENT_ARCH_CPU%}
ADDITIONAL_COMPILATION_FLAGS_CPU=${54:-%CURRENT_ADDITIONAL_COMPILATION_FLAGS_CPU%}
ADDITIONAL_COMPILATION_FLAGS_GPU=${55:-%CURRENT_ADDITIONAL_COMPILATION_FLAGS_GPU%}

FDB_INFO_FILE_PATH=${56:-%REQUEST.INFO_FILE_PATH%}
FDB_INFO_FILE_NAME=${57:-%REQUEST.INFO_FILE_NAME%}
BASE_VERSION=${58:-%BASE.VERSION%}
AQUA_START_DATE=${59:-%AQUA.START_DATE%}

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
    # lib/common/util.sh (manually added comment!)
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
    # Creates fake production fdb if not in production
    if [[ ${RUN_TYPE,,} != "production" ]] && [[ ${RUN_TYPE,,} != "research" ]]; then
        if [[ ${MODEL_NAME,,} != "nemo" ]]; then
            load_fdb_"${ATM_MODEL}"
        fi
    fi
fi

if [ "${MODEL_NAME,,}" != "nemo" ]; then
    if [ "${DQC_ACTIVE,,}" == "true" ]; then
        DATA_PORTFOLIO_PATH="${HPCROOTDIR}"/"${PROJDEST}"/"data-portfolio"
        cd ${DATA_PORTFOLIO_PATH}
        DATA_PORTFOLIO_VERSION=$(git describe --exact-match --tags)
        # lib/LUMI/config.sh (load_singularity) (auto generated comment)
        # lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
        load_singularity
        mkdir -p ${DQC_PROFILE_ROOT}
        singularity exec --cleanenv --no-home \
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
    # lib/common/util.sh (get_arch_compilation_flags) (auto generated comment)
    read arch add_flags <<<$(get_arch_compilation_flags "${PU}" "${ARCH_CPU}" "${ARCH_GPU}" "${ADDITIONAL_COMPILATION_FLAGS_CPU}" "${ADDITIONAL_COMPILATION_FLAGS_GPU}")
    compile_"${MODEL_NAME}" $arch $add_flags
    post_compilation_"${MODEL_NAME}"
else
    # If compilation path is given skip compilation
    echo "Path to a compiled model is given: ${MODEL_PATH}"
    echo "Skipping compilation"
fi
