#!/bin/bash
#
# Configuration for BSC platform

#####################################################
# TODO
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
    #OpenMPI Enviroment vars
    export OMP_NUM_THREADS=$((4 * 1))
    export ICON_THREADS=$((4 * 1))
    export OMP_SCHEDULE="guided"
    export OMP_DYNAMIC="false"
    export OMP_STACKSIZE=1G
    export HDF5_USE_FILE_LOCKING=FALSE
    export FI_CXI_OPTIMIZED_MRS="false"

    # LD MN4 dependant enviroment vars
    module purge
    module load intel/2019.5
    module load openmpi/4.0.2
    module load hdf5/1.8.19

    # directories with absolute paths
    export MODEL_DIR="${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim
    export thisdir="${HPCROOTDIR}"/"${PROJDEST}"/icon-mpim/run
    export basedir="${MODEL_DIR}"
    export icon_data_rootFolder="${INPROOT}"

    export MODEL="${basedir}"/bin/icon
    set | grep SLURM

    # how to submit the next job
    # --------------------------
    export job_name=$SLURM_JOB_NAME
}

#####################################################
# Downloads RAPS dependencies in the local setup
# Globals:
#    ROOTDIR, PROJDEST, MODEL_NAME
# Arguments:
#
#####################################################
function pre-configuration-ifs() {
    cd "${ROOTDIR}"/proj/"${PROJDEST}"/"${MODEL_NAME}"/

    # Disable download of ATLAS grids
    sed -i 's/ENABLE_RETRIEVE_ORCA_DATA=ON/ENABLE_RETRIEVE_ORCA_DATA=OFF/' bundle.yml
    sed -i 's/ENABLE_INSTALL_ORCA_DATA=ON/ENABLE_INSTALL_ORCA_DATA=OFF/' bundle.yml

    if [ ! -d "source" ]; then
        ./ifs-bundle create
    fi
}

#####################################################
# TODO
# Set environment to be able to run AQUA application
# Globals:
# Arguments:
#
######################################################
function load_environment_AQUA() {

    # Load env modules
    set +xuve
    module purge
    set -xuve

}

#####################################################
# TODO
# Set environment to be able to run ENERGY_OFFSHORE application
# Globals:
# Arguments:
#
######################################################
function load_environment_ENERGY_OFFSHORE() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load impi
    module load hdf5
    module load python/3.12.1
    set -xuve
}

#####################################################
# TODO
# Set environment to be able to run HYDROMET application
# Globals:
# Arguments:
#
######################################################
function load_environment_HYDROMET() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load impi
    module load hdf5
    module load python/3.12.1
    set -xuve
}

#####################################################
# TODO
# Set environment to be able to run WILDFIRES_WISE application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_WISE() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load impi
    module load hdf5
    module load python/3.12.1
    set -xuve
}

#####################################################
# TODO
# Set environment to be able to run WILDFIRES_SPITFIRE application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_SPITFIRE() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load impi
    module load hdf5
    module load python/3.12.1
    set -xuve
}

#####################################################
# TODO
# Set environment to be able to run WILDFIRES_FWI application
# Globals:
# Arguments:
#
######################################################
function load_environment_WILDFIRES_FWI() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load impi
    module load hdf5
    module load python/3.12.1
    set -xuve
}

#####################################################
# TODO
# Set environment to be able to run OBS application
# Globals:
# Arguments:
#
######################################################
function load_environment_OBS() {

    # Load env modules
    set +xuve
    module purge
    module load intel
    module load mkl
    module load impi
    module load hdf5
    module load python/3.12.1
    set -xuve
}

######################################################
# Function: post_compilation_ifs-nemo
# Description: This function initializes the ATLAS grids for the IFS-NEMO workflow.
#              It sets the ATLAS_GRIDS variable to the path of the ATLAS grids directory,
#              and creates a symbolic link to the ATLAS grids in the appropriate location.
######################################################
function post_compilation_ifs-nemo() {
    echo "ATLAS grids init"
    ATLAS_GRIDS="$HPC_PROJECT/atlas-orca-data-cache/atlas/grids/orca/v0/"
    cd $BUILD_DIR/share/atlas/grids/orca && ln -svf $ATLAS_GRIDS
}

function load_compile_env_nemo_intel-openmpi() {

    export ARCH_NAME="mn5-gpp-intel-openmpi"
    export NEMO_HDF5_PATH="/apps/GPP/HDF5/1.14.1-2/INTEL/OPENMPI"
    export NEMO_NETCDF_C_PATH="/apps/GPP/NETCDF/c-4.9.2_fortran-4.6.1_cxx4-4.3.1_hdf5-1.14.1-2_pnetcdf-1.12.3/INTEL/OPENMPI"
    export NEMO_NETCDF_FORTRAN_PATH="/apps/GPP/NETCDF/c-4.9.2_fortran-4.6.1_cxx4-4.3.1_hdf5-1.14.1-2_pnetcdf-1.12.3/INTEL/OPENMPI"
    export NEMO_XIOS_PATH="/gpfs/projects/bsc32/DE340-share/xios-2.5"
    export NEMO_CPP="cpp"
    export NEMO_CC="mpicc"
    export NEMO_FC="mpifort"
    export NEMO_FCFLAGS="-r8 -ip -O3 -fp-model strict -extend-source 132 -heap-arrays -xCORE-AVX2"
    export NEMO_LDFLAGS="-lstdc++ -fopenmp"
    export NEMO_FPPFLAGS="-P -traditional -I/gpfs/apps/MN5/GPP/ONEAPI/2023.2.0/mpi/2021.10.0/include -DWITH_STRICT_FORTRAN_2018"

    set +xuve
    module --force purge
    module load intel/2023.2.0 openmpi/4.1.5
    module load hdf5/1.14.1-2-openmpi
    module load pnetcdf/1.12.3-openmp netcdf/c-4.9.2_fortran-4.6.1_cxx4-4.3.1_hdf5-1.14.1-2_pnetcdf-1.12.3-openmpi
    set -xuve
}

function load_compile_env_nemo_gcc-openmpi() {

    export ARCH_NAME="mn5-gpp-gcc-openmpi"
    export NEMO_HDF5_PATH="/apps/GPP/HDF5/1.14.1-2/GCC/OPENMPI"
    export NEMO_NETCDF_C_PATH="/apps/GPP/NETCDF/c-4.9.2_fortran-4.6.1_cxx4-4.3.1_hdf5-1.14.1-2_pnetcdf-1.12.3/GCC/OPENMPI"
    export NEMO_NETCDF_FORTRAN_PATH="/apps/GPP/NETCDF/c-4.9.2_fortran-4.6.1_cxx4-4.3.1_hdf5-1.14.1-2_pnetcdf-1.12.3/GCC/OPENMPI"
    export NEMO_XIOS_PATH="/gpfs/projects/bsc32/DE340-share/xios-2.5-gcc-openmpi"
    export NEMO_CPP="cpp"
    export NEMO_CC="gcc"
    export NEMO_FC="mpif90"
    export NEMO_FCFLAGS="-O3 -fdefault-real-8 -fcray-pointer -ffree-line-length-none -fallow-argument-mismatch -I/gpfs/apps/MN5/GPP/OPENMPI/4.1.5/GCC/include"
    export NEMO_LDFLAGS="-lstdc++ -fopenmp -I/gpfs/apps/MN5/GPP/OPENMPI/4.1.5/GCC/include"
    export NEMO_FPPFLAGS="-P -traditional -I/gpfs/apps/MN5/GPP/OPENMPI/4.1.5/GCC/include"

    set +xuve
    module --force purge
    module load openmpi/4.1.5-gcc hdf5/1.14.1-2-gcc-openmpi pnetcdf/1.12.3-gcc-openmpi netcdf/c-4.9.2_fortran-4.6.1_cxx4-4.3.1_hdf5-1.14.1-2_pnetcdf-1.12.3-gcc-openmpi
    set -xuve

}

function load_compile_env_nemo_intel() {
    export ARCH_NAME="mn5-gpp"
    export NEMO_HDF5_PATH="/apps/GPP/HDF5/1.14.1-2/INTEL/IMPI"
    export NEMO_NETCDF_C_PATH="/apps/GPP/NETCDF/c-4.9.2_fortran-4.6.1_cxx4-4.3.1_hdf5-1.14.1-2_pnetcdf-1.12.3/INTEL/IMPI"
    export NEMO_NETCDF_FORTRAN_PATH="/apps/GPP/NETCDF/c-4.9.2_fortran-4.6.1_cxx4-4.3.1_hdf5-1.14.1-2_pnetcdf-1.12.3/INTEL/IMPI"
    export NEMO_XIOS_PATH="/gpfs/projects/bsc32/DE340-share/xios-2.5"
    export NEMO_CPP="cpp"
    export NEMO_CC="icc"
    export NEMO_FC="mpiifort"
    export NEMO_FCFLAGS="-r8 -ip -O3 -fp-model strict -extend-source 132 -heap-arrays -xCORE-AVX2"
    export NEMO_LDFLAGS="-lstdc++ -fopenmp"
    export NEMO_FPPFLAGS="-P -traditional -I/gpfs/apps/MN5/GPP/ONEAPI/2023.2.0/mpi/2021.10.0/include -DWITH_STRICT_FORTRAN_2018"

    set +xuve
    module --force purge
    module load intel/2023.2.0 impi/2021.10.0 mkl/2023.2.0 hdf5/1.14.1-2 pnetcdf/1.12.3 netcdf/c-4.9.2_fortran-4.6.1_cxx4-4.3.1_hdf5-1.14.1-2_pnetcdf-1.12.3
    set -xuve
}

function nemo_build_pre_compile() {
    here=$PWD
    mkdir -p $1 && cd $1
    touch mpif-config.h.idone mpif-constants.h.idone mpif-externals.h.idone mpif-handles.h.idone mpif-io-constants.h.idone mpif-io-handles.h.idone mpif-sentinels.h.idone mpif-sizeof.h.idone
    touch mpif-config.h mpif-constants.h mpif-externals.h mpif-handles.h mpif-io-constants.h mpif-io-handles.h mpif-sentinels.h mpif-sizeof.h
    export VPATH=$PWD
    cd $here
}

function load_compile_env_nemo_cpu() {
    load_compile_env_nemo_intel
}

function install_ENERGY_ONSHORE() {
    #TODO
    true
}

function load_singularity() {
    set +xuve
    module load singularity
    set -xuve
}
#####################################################
# installs bias_adjustment
# Globals:
#       HPCROOTDIR
#       PROJDEST
# Arguments:
######################################################
function install_BIAS_ADJUSTMENT() {
    # TODO
    true
}
