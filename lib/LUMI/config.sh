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
    export OTHERS="--with-gpu"
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


    # Needed MPI variables in Lumi to avoid crashes
    export FI_CXI_RX_MATCH_MODE=software
    export MPICH_ABORT_ON_ERROR=1
    export MPICH_SMP_SINGLE_COPY_MODE=NONE
    export MPICH_ALLTOALL_INTRA_ALGORITHM=pairwise
    export MPICH_ASYNC_PROGRESS=1
    export FI_CXI_EQ_ACK_BATCH_SIZE=1
    export FI_CXI_DEFAULT_CQ_SIZE=1024
    export FI_CXI_OFLOW_BUF_SIZE=20971520
    export FI_MR_CACHE_MONITOR=memhooks
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
    if [ ! -f "${ICON_PATH}"/build/yaco_16.0.1.1_rocm-5.4.1/yaco ]; then 
        cd "${ICON_PATH}"/build && cp -r ${YACO_PATH} .
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
    if [ ! -f "${ICON_PATH}"/build/16.0.1.1_rocm-5.4.1_cpu/bin/icon ]; then 
        
	mkdir -p build/16.0.1.1_rocm-5.4.1_cpu && cd build/16.0.1.1_rocm-5.4.1_cpu
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
    if [ ! -f "${ICON_PATH}"/build/16.0.1.1_rocm-5.4.1_gpu/bin/icon ]; then 
        
	mkdir -p build/16.0.1.1_rocm-5.4.1_gpu && cd build/16.0.1.1_rocm-5.4.1_gpu
        
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
    if [ ! -f "${ICON_PATH}"/build/16.0.1.1_rocm-5.4.1_cpu/bin/icon ]; then
  
	cd "${ICON_PATH}"/build/16.0.1.1_rocm-5.4.1_cpu  
	"${ICON_PATH}"/scripts/lumi_scripts/build4lumi.sh -c "make -j 16"

    fi
}

function compile_icon_gpu_gpu() {
    
    local ICON_PATH="${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim
	
    # Compilation for the OCE Binary (Currently running on G partition)
    compile_icon_cpu

    # Check if binary exists
    # Compile
    if [ ! -f "${ICON_PATH}"/build/16.0.1.1_rocm-5.4.1_gpu/bin/icon ]; then

        cd "${ICON_PATH}"/build/16.0.1.1_rocm-5.4.1_gpu
        "${ICON_PATH}"/scripts/lumi_scripts/build4lumi.sh -c "make -j 16"

    fi
}


#####################################################
# Deletes ICON restarts, preliminary  solution as 
# restart logic hasn't been fully decided yet
# Globals:
#    HPCROOTDIR
# Arguments:
#  
#####################################################
function rm_restarts_icon() {
   # Delete restarts for clean new run 
   if [ -d "${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim/experiments ]; then
         rm -rf "${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim/experiments
   else
        echo "Restart files don't exist"
   fi
}

#####################################################
# Loads and sets, most SIM variables needed by the 
# ICON run-script. Some settings will be included
# custom confs
# Globals:
#    HPCROOTDIR
#    PROJDEST
#    INPROOT
# Arguments:
#  
######################################################
function load_sim_env_icon_cpu() {

    # OpenMP environment variables
    # ----------------------------
    export OMP_NUM_THREADS=$((4*1))
    export ICON_THREADS=$((4*1))

    export OMP_SCHEDULE="guided"
    export OMP_DYNAMIC="false"
    export OMP_STACKSIZE=1G

    export HDF5_USE_FILE_LOCKING=FALSE
    
    export FI_CXI_OPTIMIZED_MRS="false"
    export FI_MR_CACHE_MONITOR="memhooks"  # ticket 2111 seg faults
    export PMI_SHARED_SECRET=""            # _pmi_set_af_in_use:PMI ERROR
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
     
     # Load modules
     module purge
     module use /project/project_465000454/devaraju/modules/LUMI/22.08/C
 
     # Load modules
     module load pyfdb/0.0.2-cpeCray-22.08
     module load ecCodes/2.30.0-cpeCray-22.08
     module load python-climatedt/3.11.3-cpeCray-22.08.lua
    # Config FDB5

    export FDB5_CONFIG_FILE=$1/experiments/$2/config.yaml
    
    export GSV_WEIGHTS_PATH=/scratch/project_465000454/igonzalez/gsv_weights
    export GRID_DEFINITION_PATH=/scratch/project_465000454/igonzalez/grid_definitions
}

#####################################################
# Set environment to be able to run opa in lumi
# Globals:
# Arguments:
#
######################################################
function load_environment_opa() {
    # Load modules
    true
}

#####################################################
# Set environment to be able to run AQUA application
# Globals:
# Arguments:
#
######################################################
function load_environment_AQUA() {
        module purge
   	AQUA_container=/project/project_465000454/containers/aqua/aqua-v0.3.sif
    	FDB5_CONFIG_FILE=/pfs/lustrep3/scratch/project_465000454/pool/data/EXPERIMENTS/fdb-config-CONTROL_1950_DEVCON.yaml  # Change it to your simulation
    	GSV_WEIGHTS_PATH=/scratch/project_465000454/igonzalez/gsv_weights/
   	GRID_DEFINITION_PATH=/scratch/project_465000454/igonzalez/grid_definitions

}

#####################################################
# Set environment to be able to run ENERGY_ONSHORE application
# Globals:
# Arguments:
#
######################################################
function load_environment_ENERGY_ONSHORE() {

        # Load env modules
        module load LUMI/22.08
        module load partition/C
        module load PrgEnv-gnu
        module load GObject-Introspection/1.72.0-cpeGNU-22.08-cray-python3.9
}

#####################################################
# Loads and sets, most SIM variables needed by the 
# ICON run-script. Some settings will be included
# custom confs
# Globals:
#    HPCROOTDIR
#    PROJDEST
#    INPROOT
# Arguments:
#  
######################################################
function load_sim_env_icon_gpu_gpu() {

    # OpenMP environment variables
    # ----------------------------
    export OMP_SCHEDULE="guided"
    export OMP_DYNAMIC="false"
    
    export HDF5_USE_FILE_LOCKING=FALSE
    export FI_CXI_OPTIMIZED_MRS="false"
    export FI_MP_CACHE_MONITOR="memhooks"

    export MPICH_COLL_OPT_OFF=1               # maybe only needed when running on LUMI-G and LUMI-C
    export MPICH_OFI_SKIP_NIC_SYMMETRY_TEST=1 # only needed when running on LUMI-G and LUMI-C

    export CRAY_ACC_NO_ASYNC=1 
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

        # Load env modules
        module load LUMI/22.08
        module load partition/C
        module load PrgEnv-gnu
        module load GObject-Introspection/1.72.0-cpeGNU-22.08-cray-python3.9

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

        # Load env modules
        module load LUMI/22.08
        module load partition/C
        module load PrgEnv-gnu
        module load GObject-Introspection/1.72.0-cpeGNU-22.08-cray-python3.9

}

#####################################################
# Set environment to be able to run MHM application
# Globals:
# Arguments:
#
######################################################
function load_environment_MHM() {
        #load_environment_gsv #not nice but I have to do that to load the others
        # Load env modules
        module use /project/project_465000454/mhm/EasyBuild/modules/LUMI/22.08/partition/L
        module load NCO/5.1.0-cpeCray-22.08
        module load python-climatedt/3.11.3-cpeCray-22.08.lua # this already contains CDO

}

#####################################################
# Set environment to be able to run WILDFIRES_WISE application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_WISE() {

        # Load env modules
        module load LUMI/22.08
        module load partition/C
        module load PrgEnv-gnu
        module load GObject-Introspection/1.72.0-cpeGNU-22.08-cray-python3.9

}

#####################################################
# Set environment to be able to run WILDFIRES_SPITFIRE application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_SPITFIRE() {

        # Load env modules
        module load LUMI/22.08
        module load partition/C
        module load PrgEnv-gnu
        module load GObject-Introspection/1.72.0-cpeGNU-22.08-cray-python3.9

}

#####################################################
# Set environment to be able to run WILDFIRES_FWI application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_FWI() {

        # Load env modules
        module load cray-python/3.9.13.1
        # Equivalent of source env-lumi-gnu.sh
        module load PrgEnv-gnu
        module load cray-hdf5 cray-netcdf
}

#####################################################
# Set environment to be able to run OBS application
# Globals:
# Arguments:
#
######################################################
function load_environment_OBS() {

        # Load env modules
        module load LUMI/22.08
        module load partition/C
        module load PrgEnv-gnu
        module load GObject-Introspection/1.72.0-cpeGNU-22.08-cray-python3.9

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
    pip install ${HPCROOTDIR}/${PROJDEST}/one_pass/
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
    pip install ${HPCROOTDIR}/${PROJDEST}/gsv_interface/
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
  pip install  ${HPCROOTDIR}/${PROJDEST}/urban
}


#####################################################
# Loads containers directory
# Globals:
#    MODEL_NAME
# Arguments:
#
#####################################################
function load_model_dir(){
        export HPC_MODEL_DIR=/projappl/project_465000454/models/${MODEL_NAME}
}


#####################################################
# Updates the submodules for ICON
# Globals:
#    ROOTDIR
#    PROJDEST
# Arguments:
#
#####################################################
function pre-configuration-icon(){
    
    cd "${ROOTDIR}"/proj/"${PROJDEST}"
    git submodule update icon-mpim
}


#######
# Some header
#######
function load_dirs(){
        export HPC_CONTAINER_DIR=/projappl/project_465000454/containers
        export HPC_SCRATCH=/scratch/project_465000454/
        export HPC_PROJECT=/projappl/project_465000454/
}
