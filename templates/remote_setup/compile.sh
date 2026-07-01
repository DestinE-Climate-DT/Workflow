#!/bin/bash

# This step compiles the model, if needed.

# HEADER

CURRENT_ARCH=${1:-%CURRENT_ARCH%}
LIBDIR=${2:-%CONFIGURATION.LIBDIR%}
COMPILE=${3:-%MODEL.COMPILE%}
HPCROOTDIR=${4:-%HPCROOTDIR%}
PROJDEST=${5:-%PROJECT.PROJECT_DESTINATION%}

MODEL_PATH=${6:-%MODEL.PATH%}
MODEL_ROOT_PATH=${7:-%MODEL.ROOT_PATH%}
MODEL_VERSION=${8:-%MODEL.VERSION%}
MODEL_NAME=${9:-%MODEL.NAME%}

# get_arch_compilation_flags variables
PU=${10:-%RUN.PROCESSOR_UNIT%}
ARCH_CPU=${11:-%CURRENT_ARCH_CPU%}
ARCH_GPU=${12:-%CURRENT_ARCH_GPU%}
ADDITIONAL_COMPILATION_FLAGS_CPU=${13:-%CURRENT_ADDITIONAL_COMPILATION_FLAGS_CPU%}
ADDITIONAL_COMPILATION_FLAGS_GPU=${14:-%CURRENT_ADDITIONAL_COMPILATION_FLAGS_GPU%}

# compile_"${MODEL_NAME}" variables
BUNDLE_BUILD_DIR=${15:-%MODEL.BUNDLE_BUILD_DIR%}
BUNDLE_SOURCE_DIR=${16:-%MODEL.BUNDLE_SOURCE_DIR%}

# post_compilation_"${MODEL_NAME}" variables
HPC_PROJECT=${17:-%CONFIGURATION.HPC_PROJECT_DIR%}

# END_HEADER

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/utils/remote_setup_utils.sh

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

if [ "${MODEL_NAME,,}" == "nemo" ]; then
    # compilation is currently not working for NEMO and blocked in local setup
    # lib/MARENOSTRUM5/config.sh (load_compile_env_nemo_intel) (auto generated comment)
    load_compile_env_nemo_intel
    # lib/common/utils/remote_setup_utils.sh (manually generated comment)
    compile_"${MODEL_NAME}"
else
    # lib/common/util.sh (get_arch_compilation_flags) (auto generated comment)
    # lib/common/utils/remote_setup_utils.sh (get_arch_compilation_flags) (auto generated comment)
    read arch add_flags <<<$(get_arch_compilation_flags "${PU}" "${ARCH_CPU}" "${ARCH_GPU}" "${ADDITIONAL_COMPILATION_FLAGS_CPU}" "${ADDITIONAL_COMPILATION_FLAGS_GPU}")
    # lib/common/utils/remote_setup_utils.sh (manually generated comment)
    compile_"${MODEL_NAME}" "$arch" "$add_flags"
fi
# lib/common/utils/remote_setup_utils.sh (manually generated comment)
# lib/MARENOSTRUM5/config.sh (post_compilation_ifs-nemo) (manually generated comment)
post_compilation_"${MODEL_NAME}"
