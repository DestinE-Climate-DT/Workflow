#!/bin/bash
#
# Configuration for LEVANTE platform

#####################################################
# Set the enviroment for compiling IFS
# Globals:
# Arguments:
#
######################################################
function load_compile_env_ifs() {
    # Enables modules in Levante
    source /sw/etc/profile.levante

    # Variables
    export NUMPROC=16
    export IFS_COMPILING_SCRIPT=config.intel.levante
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
function load_SIM_env_icon_cpu() {

    # OpenMP environment variables
    export OMP_NUM_THREADS=4
    export ICON_THREADS=$OMP_NUM_THREADS
    export OMP_SCHEDULE="guided"
    export OMP_DYNAMIC="false"
    export OMP_STACKSIZE=500M

    # Intel OpenMP
    export KMP_AFFINITY=granularity=fine,scatter
    export KMP_LIBRARY=turnaround
    # OpenMPI
    export OMPI_MCA_btl=self
    export OMPI_MCA_coll=^hcoll,ml
    export OMPI_MCA_coll_tuned_alltoallv_algorithm=2
    export OMPI_MCA_coll_tuned_use_dynamic_rules=true
    export OMPI_MCA_io=romio321
    export OMPI_MCA_osc=ucx
    export OMPI_MCA_pml=ucx
    export OMPI_MCA_pml_ucx_opal_mem_hooks=1
    # Unified Communication X
    export UCX_HANDLE_ERRORS=bt
    export UCX_IB_ADDR_TYPE=ib_global
    export UCX_NET_DEVICES=mlx5_0:1
    export UCX_TLS=mm,cma,dc_mlx5,dc_x,self
    export UCX_UNIFIED_MODE=y
    # HDF5 Library
    export HDF5_USE_FILE_LOCKING=FALSE
    # GNU C Library
    export MALLOC_TRIM_THRESHOLD_=-1
    # Intel MKL
    export MKL_DEBUG_CPU_TYPE=5
    export MKL_ENABLE_INSTRUCTIONS=AVX2
    export UCX_LOG_LEVEL=ERROR
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
function load_SIM_env_icon_gpu_gpu() {
    # OpenMP environment variables
    # ----------------------------
    export OMP_DYNAMIC="false"
    export OMP_SCHEDULE=guided
    export OMP_STACKSIZE=500M
    export OMP_NUM_THREADS=$((4 * 1))
    export ICON_THREADS=$OMP_NUM_THREADS

    # Intel OpenMP
    export KMP_AFFINITY=granularity=fine,scatter
    export KMP_LIBRARY=turnaround

    # OpenMPI
    export OMPI_MCA_btl=self
    export OMPI_MCA_coll=^hcoll,ml
    export OMPI_MCA_coll_tuned_alltoallv_algorithm=2
    export OMPI_MCA_coll_tuned_use_dynamic_rules=true
    export OMPI_MCA_io=romio321
    export OMPI_MCA_osc=ucx
    export OMPI_MCA_pml=ucx
    export OMPI_MCA_pml_ucx_opal_mem_hooks=1

    # Unified Communication X
    export UCX_HANDLE_ERRORS=bt
    export UCX_IB_ADDR_TYPE=ib_global
    export UCX_NET_DEVICES=mlx5_0:1
    export UCX_TLS=mm,cma,dc_mlx5,dc_x,self
    export UCX_UNIFIED_MODE=n
    export UCX_LOG_LEVEL=ERROR # TODO: unsilence UCX warnings

    # HDF5 Library
    export HDF5_USE_FILE_LOCKING=FALSE

    # GNU C Library
    export MALLOC_TRIM_THRESHOLD_=-1

    # Intel MKL
    export MKL_DEBUG_CPU_TYPE=5
    export MKL_ENABLE_INSTRUCTIONS=AVX2
}

#####################################################
# Set the enviroment for generating the ICON Makefile
# Globals:
#    HPCROOTDIR
#    PROJDEST
# Arguments:
#
######################################################
function load_compile_env_icon() {

    local ICON_PATH=${HPCROOTDIR}/${PROJDEST}/icon-mpim

    # Load enviroment and create Makefile
    cd "${ICON_PATH}"

    # Check if Makefile already exists
    if [ ! -f bin/icon ]; then
        ./config/dkrz/levante.intel --enable-openmp --enable-mixed-precision
    else
        echo "An old version of Makefile exists"
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
# Set the enviroment for running IFS
# Globals:
#    HPCROOTDIR
# Arguments:
#
#####################################################
function load_SIM_env_ifs() {
    # Enables modules in Levante
    source /sw/etc/profile.levante

    # Variables
    export host=lum # should be lev, but that is not yet in the RAPS script
}

#####################################################
# Deletes IFS restarts
# Globals:
#    HPCROOTDIR
# Arguments:
#
#####################################################
function rm_restarts_ifs() {
    rm -rf "$HPCROOTDIR"/restarts
}

#####################################################
# Loads pre-compiled model directory
# Globals:
#    MODEL_NAME
# Arguments:
#
#####################################################
function load_model_dir() {
    export HPC_MODEL_DIR=/work/bb1153/models/${MODEL_NAME}
}
