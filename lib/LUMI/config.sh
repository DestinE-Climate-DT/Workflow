#!/bin/bash
# Configuration for LUMI platform

#####################################################
# Set the enviroment for compiling IFS in GPUS
# Globals:
# Arguments:
#
######################################################
function load_compile_env_ifs_gpu() {
    # Variables
    export NUMPROC=128
    export ARCH=arch/eurohpc/lumi-g/default
    export OTHERS="--dry-run --keep-going --retry -j32 --with-gpu"
    export IFS_BUNDLE_SKIP_FESOM=1

}

#####################################################
# Set the enviroment for compiling IFS in CPUS
# Globals:
# Arguments:
#
######################################################
function load_compile_env_ifs_cpu() {
    # Variables
    export NUMPROC=128
    export ARCH=arch/eurohpc/lumi-c/default
    export OTHERS=""

}

#####################################################
# Set the enviroment for running IFS in CPUs
# Globals:
#
# Arguments:
#
#####################################################
function load_SIM_env_ifs_cpu() {
    # Variables
    export host=lum-c
    export bin_hpc_name=lumi
    export compiler="cce"
    export mpilib="cray-mpich"

}

#####################################################
# Set the enviroment for running IFS in GPUs
# Globals:
#
# Arguments:
#
#####################################################
function load_SIM_env_ifs_gpu() {
    # Variables
    export host=lum-g
    export bin_hpc_name=lumi
    export compiler="cce"
    export mpilib="cray-mpich"

}

#####################################################
# Deletes IFS restarts in the INI step for a clean run
# Globals:
#    HPCROOTDIR
# Arguments:
#
#####################################################
function rm_restarts_ifs() {
    rm -rf $HPCROOTDIR/restarts
}

#####################################################
# Set the enviroment for the output process YACO
# Currently make use of existing binaries
# Globals:
#    HPCROOTDIR
#    PROJDEST
# Arguments:
#
######################################################
function load_yaco_binaries() {

    local ICON_PATH="${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim
    local YACO_PATH="${HPC_MODEL_DIR}"/yaco_sources/yaco_16.0.1.1_rocm-5.4.1

    cd "${ICON_PATH}"

    # Check if YACO binary exists, if not create a copy of latest version
    # in the experiment folder
    if [ ! -f "${ICON_PATH}"/build/yaco_cpu/yaco ]; then
        cd "${ICON_PATH}"/build && cp -r "${YACO_PATH}" .
    else
        echo "An old version of the YACO exists"
    fi
}

#####################################################
# Set the enviroment for generating the ICON Makefile
# (CPU Only version)
# Globals:
#    HPCROOTDIR
#    PROJDEST
# Arguments:
#
######################################################
function load_compile_env_icon_cpu() {

    local ICON_PATH="${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim
    local CRAY_ENV=/opt/cray/pe/lmod/lmod/init/bash

    local CPU_COMP_WRAPPER="${ICON_PATH}"/config/csc/lumi.cpu.cce-16.0.1.1

    cd "${ICON_PATH}"

    # COMPILATION MAKEFILE FOR CPU BINARY (OCE+ATM)
    # Check if CPU binary exists, if not create Makefile
    if [ ! -f "${ICON_PATH}"/build/icon_cpu/bin/icon ]; then

        mkdir -p build/icon_cpu && cd build/icon_cpu
        "${ICON_PATH}"/scripts/lumi_scripts/build4lumi.sh -c "source ${CRAY_ENV};${CPU_COMP_WRAPPER}"
    else
        echo "An old version of the CPU Makefile exists"
    fi

    # Create a copy of latest YACO binaries
    # in the experiment folder
    load_yaco_binaries
}

#####################################################
# Set the enviroment for generating the ICON Makefile
# (Currently OCE and YACO using cpus from LUMI-G Nodes)
#
#Globals:
#    HPCROOTDIR
#    PROJDEST
# Arguments:
#
######################################################
function load_compile_env_icon_gpu_gpu() {

    local ICON_PATH="${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim
    local CRAY_ENV=/opt/cray/pe/lmod/lmod/init/bash

    local GPU_COMP_WRAPPER="${ICON_PATH}"/config/csc/lumi.gpu.cce-16.0.1.1

    cd "${ICON_PATH}"

    # COMPILATION MAKEFILE FOR CPU BINARY (OCE)
    # Check if CPU binary exists, if not create Makefile
    # Also copies YACO Binaries
    load_compile_env_icon_cpu

    cd "${ICON_PATH}"

    # COMPILATION MAKEFILE FOR GPU BINARY (ATM)
    # Check if GPU binary exists, if not create Makefile
    if [ ! -f "${ICON_PATH}"/build/icon_gpu/bin/icon ]; then

        mkdir -p build/icon_gpu && cd build/icon_gpu

        "${ICON_PATH}"/scripts/lumi_scripts/build4lumi.sh -c ${GPU_COMP_WRAPPER}
    else
        echo "An old version of the GPU Makefile exists"
    fi
}

#####################################################
# Compile ICON with container
#
#Globals:
#    HPCROOTDIR
#    PROJDEST
# Arguments:
#
######################################################
function compile_icon_cpu() {

    local ICON_PATH="${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim

    # Check if binary exists
    # Compile
    if [ ! -f "${ICON_PATH}"/build/icon_cpu/bin/icon ]; then

        cd "${ICON_PATH}"/icon_cpu
        "${ICON_PATH}"/scripts/lumi_scripts/build4lumi.sh -c "make -j 16"

    fi
}

function compile_icon_gpu_gpu() {

    local ICON_PATH="${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim

    # Compilation for the OCE Binary (Currently running on G partition)
    compile_icon_cpu

    # Check if binary exists
    # Compile
    if [ ! -f "${ICON_PATH}"/build/icon_gpu/bin/icon ]; then

        cd "${ICON_PATH}"/build/icon_gpu
        "${ICON_PATH}"/scripts/lumi_scripts/build4lumi.sh -c "make -j 16"

    fi
}

#####################################################
# Loads and sets, most SIM variables needed by the
# ICON run-script. Some settings will be included
# custom confs
# Globals:
# Arguments:
#
######################################################
function load_SIM_env_icon_cpu() {

    # OpenMP environment variables
    # ----------------------------
    export OMP_NUM_THREADS=$((4 * 1))
    export ICON_THREADS=$((4 * 1))

    export OMP_SCHEDULE="guided"
    export OMP_DYNAMIC="false"
    export OMP_STACKSIZE=1G

    export HDF5_USE_FILE_LOCKING=FALSE

    export FI_CXI_OPTIMIZED_MRS="false"
    export FI_MR_CACHE_MONITOR="memhooks" # ticket 2111 seg faults
    export PMI_SHARED_SECRET=""           # _pmi_set_af_in_use:PMI ERROR
}

# Set environment to be able to run DUMMY application
# Globals:
# Arguments:
#
######################################################
function load_environment_DUMMY() {

    # Load env modules
    module load LUMI/22.08
    module load partition/C
    module load PrgEnv-gnu
    module load GObject-Introspection/1.72.0-cpeGNU-22.08-cray-python3.9

}

#####################################################
# Set environment to be able to run gsv interface in lumi
# Globals:
# Arguments:
#  	PROJDIR
#	RUN.READ_EXPID
######################################################
function load_environment_gsv() {
    # TODO: point to the load_modules_lumi from gsv_interface
    #
    #
    set +xuve
    # Load modules
    module purge
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C

    # Load modules
    ml ecCodes/2.33.0-cpeCray-23.03
    ml fdb/5.11.94-cpeCray-23.03
    ml metkit/1.11.0-cpeCray-23.03
    ml eckit/1.25.0-cpeCray-23.03
    ml python-climatedt/3.11.7-cpeCray-23.03

    # temporal?
    export PATH=/users/lrb_465000454_fdb/mars/versions/current/bin:$PATH
    export METKIT_RAW_PARAM=1

    export FDB5_CONFIG_FILE=$1/$2/fdb/config.yaml

    export GSV_WEIGHTS_PATH=/scratch/project_465000454/igonzalez/gsv_weights
    export GSV_TEST_FILES=/scratch/project_465000454/igonzalez/gsv_test_files
    export GRID_DEFINITION_PATH=/scratch/project_465000454/igonzalez/grid_definitions
    set -xuve
}

function load_environment_maestro_gsv() {
    set +xuve
    load_environment_maestro_base
    # Load modules
    module purge
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C

    # Load modules
    ml ecCodes/2.33.0-cpeCray-23.03
    ml fdb/5.11.94-cpeCray-23.03
    ml metkit/1.11.0-cpeCray-23.03
    ml eckit/1.25.0-cpeCray-23.03

    # temporal?
    export PATH=/users/lrb_465000454_fdb/mars/versions/current/bin:$PATH
    export METKIT_RAW_PARAM=1

    export FDB5_CONFIG_FILE=/projappl/project_465000454/experiments/hz9n/config.yaml

    export GSV_WEIGHTS_PATH=/scratch/project_465000454/igonzalez/gsv_weights
    export GSV_TEST_FILES=/scratch/project_465000454/igonzalez/gsv_test_files
    export GRID_DEFINITION_PATH=/scratch/project_465000454/igonzalez/grid_definitions
    load_environment_maestro_python

    set -xuve
}

function load_environment_maestro_python() {
    # Paths for running scripts with both gsv-interface and maestro-core packages
    export PATH=/projappl/project_465000454/devaraju/softwares/LUMI23.03/python3.12-climatedt/bin/:$PATH
    export PYTHONPATH=$PYTHONPATH:/scratch/project_465000454/chaine/maestro-core/install/lib/python3.11/site-packages/maestro_core
    export PYTHONPATH=$PYTHONPATH:/scratch/project_465000454/chaine/gsv_interface
    export PYTHONPATH=$PYTHONPATH:/scratch/project_465000454/chrishaine/a190/git_project/one_pass
    export PARAMDB=/scratch/project_465000454/chaine/gsv_interface/gsv/dqc/profiles/config/variables.yaml
}

function load_environment_maestro_apps() {
    set +xuve
    load_environment_maestro_base
    export MSTRO_LIBRARIAN_PATH=/scratch/project_465000454/chaine/maestro-core/examples/
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/projappl/project_465000454/devaraju/softwares/LUMI23.03/fdb-5.11.94/lib64
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/projappl/project_465000454/devaraju/softwares/LUMI23.03/eccodes-2.33.0/lib64
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/scratch/project_465000454/chaine/inst/lib64
    export ECCODES_DIR=/projappl/project_465000454/devaraju/softwares/LUMI23.03/eccodes-2.33.0/
    export ECCODES_DEFINITION_PATH=${ECCODES_DIR}/share/eccodes/definitions
    export MSTRO_SCHEMA_PATH=${MSTRO_LIBRARIAN_PATH}
    export MSTRO_SCHEMA_LIST="gsv.yaml;fdb_request_schema.yaml"
    set -xuve
}

function load_environment_maestro_end_to_end() {
    set +xuve
    load_environment_maestro_base
    # IFS/MultIO looks for this explicitly
    export MAESTRO_ROOT=${MSTRO_DIR}/install
    export LD_LIBRARY_PATH=${MSTRO_DIR}/install/lib:$LD_LIBRARY_PATH

    export MSTRO_DROP_UNKNOWN_ATTRIBUTES=1
    set -xuve
}

function load_environment_maestro_base() {
    export MSTRO_DIR=/scratch/project_465000454/chaine/maestro-core/
    export MSTRO_SCHEMA_PATH="${MSTRO_DIR}"/examples
    export MSTRO_SCHEMA_LIST="gsv.yaml"
    export MSTRO_OFI_PROVIDER="tcp"
    export FI_LOG_LEVEL=debug
    export FDB5_CONFIG_FILE=/projappl/project_465000454/experiments/hz9n/config.yaml
}

#####################################################
# Set environment to be able to run opa in lumi
# Globals:
# Arguments:
#
######################################################
function load_environment_opa() {
    # Load modules
    set +xuve
    true
    set -xuve
}

#####################################################
# Set environment to be able to run AQUA application
# Globals:
# Arguments:
#
######################################################
function load_environment_AQUA() {
    set +xuve
    #module purge
    set -xuve
}

#####################################################
# Set environment to be able to run ENERGY_ONSHORE application
# Globals:
# Arguments:
#
######################################################
function load_environment_ENERGY_ONSHORE() {
    set +xuve
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C

    # Load modules
    ml ecCodes/2.33.0-cpeCray-23.03
    ml fdb/5.11.94-cpeCray-23.03
    ml metkit/1.11.0-cpeCray-23.03
    ml eckit/1.25.0-cpeCray-23.03
    ml python-climatedt/3.11.7-cpeCray-23.03
    set -xuve
}

#####################################################
# Loads and sets, most SIM variables needed by the
# ICON run-script. Some settings will be included
# custom confs
# Globals:
# Arguments:
#
######################################################
function load_SIM_env_icon_gpu_gpu() {

    # OpenMP environment variables
    # ----------------------------
    export OMP_SCHEDULE="guided"
    export OMP_DYNAMIC="false"

    export HDF5_USE_FILE_LOCKING=FALSE
    export FI_CXI_OPTIMIZED_MRS="false"
    export FI_MP_CACHE_MONITOR="memhooks"

    export MPICH_ALLREDUCE_NO_SMP=1
    export MPICH_COLL_OPT_OFF=1               # maybe only needed when running on LUMI-G and LUMI-C
    export MPICH_OFI_SKIP_NIC_SYMMETRY_TEST=1 # only needed when running on LUMI-G and LUMI-C
}

#####################################################
# Loads pre-compiled model directory
# TODO: check the headers

# Set environment to be able to run ENERGY_OFFSHORE application
# Globals:
# Arguments:
#
######################################################
function load_environment_ENERGY_OFFSHORE() {
    set +xuve
    # Load env modules
    module load LUMI/22.08
    module load partition/C
    module load PrgEnv-gnu
    module load GObject-Introspection/1.72.0-cpeGNU-22.08-cray-python3.9
    set -xuve
}

#####################################################
# Set environment to be able to run URBAN application
# Globals:
# Arguments:
#
######################################################
function load_environment_URBAN() {
    set +xuve
    # Load env modules
    module load LUMI/22.08
    module load partition/C
    module load PrgEnv-gnu
    module load GObject-Introspection/1.72.0-cpeGNU-22.08-cray-python3.9
    set -xuve
}

#####################################################
# Set environment to be able to run HYDROMET application
# Globals:
# Arguments:
#
######################################################
function load_environment_HYDROMET() {
    set +xuve
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C

    # Load modules
    ml ecCodes/2.33.0-cpeCray-23.03
    ml fdb/5.11.94-cpeCray-23.03
    ml metkit/1.11.0-cpeCray-23.03
    ml eckit/1.25.0-cpeCray-23.03
    ml python-climatedt/3.11.7-cpeCray-23.03
    set -xuve
}

#####################################################
# Set environment to be able to run WILDFIRES_WISE application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_WISE() {
    set +xuve
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C

    # Load modules
    ml ecCodes/2.33.0-cpeCray-23.03
    ml fdb/5.11.94-cpeCray-23.03
    ml metkit/1.11.0-cpeCray-23.03
    ml eckit/1.25.0-cpeCray-23.03
    ml python-climatedt/3.11.7-cpeCray-23.03
    set -xuve
}

#####################################################
# Set environment to be able to run WILDFIRES_SPITFIRE application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_SPITFIRE() {
    set +xuve
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C

    # Load modules
    ml ecCodes/2.33.0-cpeCray-23.03
    ml fdb/5.11.94-cpeCray-23.03
    ml metkit/1.11.0-cpeCray-23.03
    ml eckit/1.25.0-cpeCray-23.03
    ml python-climatedt/3.11.7-cpeCray-23.03 # Load env modules
    set -xuve
}

#####################################################
# Set environment to be able to run WILDFIRES_FWI application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_FWI() {

    set +xuve
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C

    # Load modules
    ml ecCodes/2.33.0-cpeCray-23.03
    ml fdb/5.11.94-cpeCray-23.03
    ml metkit/1.11.0-cpeCray-23.03
    ml eckit/1.25.0-cpeCray-23.03
    ml python-climatedt/3.11.7-cpeCray-23.03
    set -xuve
}

#####################################################
# Set environment to be able to run OBS application
# Globals:
# Arguments:
#
######################################################
function load_environment_OBSALL() {
    set +xuve
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C

    # Load modules
    ml ecCodes/2.33.0-cpeCray-23.03
    ml fdb/5.11.94-cpeCray-23.03
    ml metkit/1.11.0-cpeCray-23.03
    ml eckit/1.25.0-cpeCray-23.03
    ml python-climatedt/3.11.7-cpeCray-23.03
    set -xuve
}

#####################################################
# installs opa
# Globals:
#       HPCROOTDIR
#       PROJDEST
# Arguments:
######################################################
function install_OPA() {
    # install opa from local clone into the project
    pip install "${HPCROOTDIR}"/"${PROJDEST}"/one_pass/
}

#####################################################
# installs gsv interface
# Globals:
#       HPCROOTDIR
#       PROJDEST
# Arguments:
######################################################
function install_GSV_INTERFACE() {
    # install opa from local clone into the project
    pip install "${HPCROOTDIR}"/"${PROJDEST}"/gsv_interface/
}

#####################################################
# installs URBAN application
# Globals:
#       HPCROOTDIR
#       PROJDEST
# Arguments:
######################################################
function install_URBAN() {
    #install OBS application from local clone into the project
    pip install "${HPCROOTDIR}"/"${PROJDEST}"/urban
}

#####################################################
# Loads containers directory
# Globals:
#    MODEL_NAME
# Arguments:
#
#####################################################
function load_model_dir() {
    export HPC_MODEL_DIR=/projappl/project_465000454/models/${MODEL_NAME}
}

#####################################################
# Loads pre-compiled model directory
# Globals:
#    MODEL_NAME
# Arguments:
#
#####################################################
function inputs_dvc_checkout() {

    cd "$HPCROOTDIR/$PROJDEST/dvc-cache-de340"
    export PATH="/pfs/lustrep3/scratch/project_465000454/kkeller/environments/dvc/bin:$PATH"
    dvc checkout

}

#######
# Some header
#######
function load_dirs() {
    export HPC_CONTAINER_DIR=/projappl/project_465000454/containers
    export HPC_SCRATCH=/scratch/project_465000454/
    export HPC_PROJECT=/projappl/project_465000454/
}

###################################################
## Loads environment for backup job
###################################################
function load_backup_env() {
    module load LUMI/23.03
    module load parallel
}

#####################################################
# Set environment to be able to run MHM & MRM application
# Globals:
# Arguments:
#
######################################################
function load_environment_MHM() {
    # Load env modules
    set +xuve
    module purge
    export PATH="/project/project_465000454/mhm/mhm_helpers/bin:$PATH"
    set -xuve
}
function load_environment_MRM() {
    # Load env modules
    set +xuve
    module purge
    export PATH="/project/project_465000454/mhm/mhm_helpers/bin:$PATH"
    set -xuve
}

#####################################################
# installs URBAN application
# Globals:
#       HPCROOTDIR
#       PROJDEST
# Arguments:
######################################################
function install_URBAN() {
    #install OBS application from local clone into the project
    pip install ${HPCROOTDIR}/${PROJDEST}/urban
}

######################################################
function install_HYDROMET() {
    #install OBS application from local clone into the project
    pip install ${HPCROOTDIR}/${PROJDEST}/hydromet
}

#####################################################
# installs ENERGY_ONSHORE application
# Globals:
#       HPCROOTDIR
#       PROJDEST
# Arguments:
######################################################
function install_ENERGY_ONSHORE() {
    #install OBS application from local clone into the project
    pip install ${HPCROOTDIR}/${PROJDEST}/energy_onshore
}

#####################################################
# Loads containers directory
# Globals:
#    MODEL_NAME
# Arguments:
#
#####################################################
function load_dirs() {
    export HPC_CONTAINER_DIR=/projappl/project_465000454/containers
    export HPC_SCRATCH=/scratch/project_465000454
    export HPC_PROJECT=/projappl/project_465000454
}

# Module loads the climate dt python version
# Globals:
#
# Arguments:
#
#####################################################

function load_python_climate_dt() {
    # activate special environment for climate-dt
    module use /project/project_465000454/devaraju/modules/LUMI/23.03/C

    # load climate-dt python module
    module load python-climatedt/3.11.7-cpeCray-23.03
}
