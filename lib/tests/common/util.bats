# Tests for common/util.sh

## setup

setup() {
	bats_load_library bats-support
	bats_load_library bats-assert

	# get the containing directory of this file
	# use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
	# as those will point to the bats executable's location or the preprocessed file respectively
	DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
	# source file under test
	source "${DIR}/../../common/util.sh"
}

## pre-configuration-ifs

@test "by default pre-configuration-ifs returns true" {
	run pre-configuration-ifs
	assert_success
}

## pre-configuration-icon

@test "by default pre-configuration-icon returns true" {
	run pre-configuration-icon
	assert_success
}

## load_variables_ifs

@test "load_variables_ifs exported values" {
	assert [ -z "${nodes}" ]
	assert [ -z "${mpi}" ]
	assert [ -z "${omp}" ]
	assert [ -z "${jobid}" ]
	assert [ -z "${jobname}" ]
	SLURM_JOB_NUM_NODES="1"
	SLURM_NPROCS="2"
	SLURM_CPUS_PER_TASK="3"
	SLURM_JOB_ID="4"
	SLURM_JOB_NAME="job.4"
	load_variables_ifs
	assert_equal "${nodes}" "1"
	assert_equal "${mpi}" "2"
	assert_equal "${omp}" "3"
	assert_equal "${jobid}" "4"
	assert_equal "${jobname}" "job.4"
}

## load_inproot_precomp_path

@test "load_inproot_precomp_path returns only the input dir if no model provided" {
	assert [ -z "${MODEL_VERSION}" ]
	assert [ -z "${INPROOT}" ]
	HPC_MODEL_DIR="/tmp"
	load_inproot_precomp_path
	assert_equal "${INPROOT}" "/tmp/inidata"
	assert [ -z "${PRECOMP_MODEL_PATH}" ]
}

@test "load_inproot_precomp_path returns the input dir and precompiled path (arch is lowercase)" {
	assert [ -z "${INPROOT}" ]
	MODEL_VERSION="ifs-1.2.3"
	HPC_MODEL_DIR="/tmp"
	HPCARCH="LOWERCASE"
	ENVIRONMENT="Test"
	load_inproot_precomp_path
	assert_equal "${INPROOT}" "/tmp/ifs-1.2.3/inidata"
	assert_equal "${PRECOMP_MODEL_PATH}" "/tmp/ifs-1.2.3/make/lowercase-Test"
}
