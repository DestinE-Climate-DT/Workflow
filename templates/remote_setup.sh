#!/bin/bash
#
# This step loads the necessary enviroment and then compiles the diferent models
set -xuve 

# Interface
HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL_NAME=${3:-%MODEL.NAME%}
CURRENT_ARCH=${4:-%CURRENT_ARCH%}
MODEL_VERSION=${5:-%RUN.MODEL_VERSION%}
ENVIRONMENT=${6:-%RUN.ENVIRONMENT%}
HPCARCH=${7:-%HPCARCH%}

export MODEL_VERSION
export ENVIRONMENT
export HPCARCH

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

# Main Code

#Functions

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
    cd "${HPCROOTDIR}"/"${PROJDEST}"/"${MODEL_NAME}"/flexbuild
    set -xve +u
    source initbm "${IFS_COMPILING_SCRIPT}" SINGLE=yes NEMO=yes RAPS_SUPPORT=yes RAPSHARED=no ODB=no OOPS=no NCPUS="${NUMPROC}" TMPDIR=/dev/shm/IFS-NEMO40-BUILD
    make 2>&1 | tee raps_make.log
}

#####################################################
# Compiles & generates the ICON binaries
# The use of 8 jobs is recomended by ICON developers
# Globals:
#
# Arguments:
######################################################
function compile_icon() {
    # Make ICON binaries
    # ICON Documentation recommends 8 jobs
    make -j8
}

# Compile
if [ ! -d "${PRECOMP_MODEL_PATH}" ]; then
    load_compile_env_"${ATM_MODEL}"
    compile_"${MODEL_NAME}"
else
    # If compilation path is given skip compilation
    echo "Path to a compiled model provided: PRECOMP_MODEL_PATH=${PRECOMP_MODEL_PATH}"
    echo "Skipping compilation"
fi
