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
	source "${DIR}/../../../lib/common/util.sh"
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


@test "get_member_number returns the member number" {
	MEMBER_LIST="fc0 fc1 fc2"
	MEMBER="fc1"
	MEMBER_NUMBER=$(get_member_number "${MEMBER_LIST}" ${MEMBER})
	assert_equal "${MEMBER_NUMBER}" "2"
}

@test "get_arch_compilation_flags returns the compilation flags in CPU case" {
	PU="cpu"
	ARCH_CPU="cpu/default"
	ARCH_GPU="gpu/default"
	ADDITIONAL_COMPILATION_FLAGS_CPU="--cpu-flag"
	ADDITIONAL_COMPILATION_FLAGS_GPU="--gpu-flag"
	get_arch_compilation_flags $PU $ARCH_CPU $ARCH_GPU $ADDITIONAL_COMPILATION_FLAGS_CPU $ADDITIONAL_COMPILATION_FLAGS_GPU
	assert_equal "${add_flags}" "${ADDITIONAL_COMPILATION_FLAGS_CPU}"
	assert_equal "${arch}" "${ARCH_CPU}"
}

@test "get_arch_compilation_flags returns the compilation flags in GPU case" {
	PU="gpu"
	ARCH_CPU="cpu/default"
	ARCH_GPU="gpu/default"
	ADDITIONAL_COMPILATION_FLAGS_CPU="--cpu-flag"
	ADDITIONAL_COMPILATION_FLAGS_GPU="--gpu-flag"
	get_arch_compilation_flags $PU $ARCH_CPU $ARCH_GPU $ADDITIONAL_COMPILATION_FLAGS_CPU $ADDITIONAL_COMPILATION_FLAGS_GPU
	assert_equal "${add_flags}" "${ADDITIONAL_COMPILATION_FLAGS_GPU}"
	assert_equal "${arch}" "${ARCH_GPU}"
}

@test "enable_process_monthly returns true if the first day of the month is in the chunk" {
	START_DATE="20230101"
	SPLIT_END_DATE="20230131"
	RESULT=$(enable_process_monthly "$START_DATE" "$SPLIT_END_DATE")
	assert_equal "${RESULT}" "true"
}

@test "enable_process_monthly returns false if the first day of the month is not in the chunk" {
	START_DATE="20230102"
	SPLIT_END_DATE="20230131"
	RESULT=$(enable_process_monthly "$START_DATE" "$SPLIT_END_DATE")
	assert_equal "${RESULT}" "false"
}
