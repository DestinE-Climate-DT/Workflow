# Tests for LUMI/config.sh

## setup

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    # source file under test
    source "${DIR}/../../LUMI/config.sh"
}

## load_compile_env_ifs_gpu

@test "load_compile_env_ifs_gpu exported values" {
    assert [ -z "${NUMPROC}" ]
    assert [ -z "${ARCH}" ]
    assert [ -z "${OTHERS}" ]
    assert [ -z "${IFS_BUNDLE_SKIP_FESOM}" ]
    load_compile_env_ifs_gpu
    assert_equal "${NUMPROC}" "128"
    assert_equal "${ARCH}" "arch/eurohpc/lumi-g/default"
    assert_equal "${OTHERS}" "--dry-run --keep-going --retry -j32 --with-gpu"
    assert_equal "${IFS_BUNDLE_SKIP_FESOM}" "1"
}

## load_compile_env_ifs_cpu

@test "load_compile_env_ifs_cpu exported values" {
    assert [ -z "${NUMPROC}" ]
    assert [ -z "${ARCH}" ]
    assert [ -z "${OTHERS}" ]
    load_compile_env_ifs_cpu
    assert_equal "${NUMPROC}" "128"
    assert_equal "${ARCH}" "arch/eurohpc/lumi-c/default"
    assert_equal "${OTHERS}" ""
}

## load_SIM_env_ifs_cpu

@test "load_SIM_env_ifs_cpu exported values" {
    assert [ -z "${host}" ]
    assert [ -z "${bin_hpc_name}" ]
    assert [ -z "${compiler}" ]
    assert [ -z "${mpilib}" ]
    load_SIM_env_ifs_cpu
    assert_equal "${host}" "lum-c"
    assert_equal "${bin_hpc_name}" "lumi"
    assert_equal "${compiler}" "cce"
    assert_equal "${mpilib}" "cray-mpich"
}

## load_SIM_env_ifs_gpu

@test "load_SIM_env_ifs_gpu exported values" {
    assert [ -z "${host}" ]
    assert [ -z "${bin_hpc_name}" ]
    assert [ -z "${compiler}" ]
    assert [ -z "${mpilib}" ]
    load_SIM_env_ifs_gpu
    assert_equal "${host}" "lum-g"
    assert_equal "${bin_hpc_name}" "lumi"
    assert_equal "${compiler}" "cce"
    assert_equal "${mpilib}" "cray-mpich"
}
