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

	export KEEP_EVERY=12
	export KEEP_LAST=3

}

@test "get_member_number returns the member number" {
	MEMBER_LIST="fc0 fc1 fc2"
	MEMBER="fc1"
	MEMBER_NUMBER=$(get_member_number "${MEMBER_LIST}" ${MEMBER})
	assert_equal "${MEMBER_NUMBER}" "2"
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

@test build_bindings {
    test_bindings=(/directory1 /directory2 /directory3)
    output=$(build_bindings "${test_bindings[@]}")
    expected_output="  --bind /directory1  --bind /directory2  --bind /directory3"
    assert_output "$expected_output"
}

@test test_setup_additional_binds {
    CLEAN_DIR="${ROOTDIR}/clean_requests/"
    mkdir -p ${CLEAN_DIR}
    ADDITIONAL_BINDINGS=("${CLEAN_DIR}")

    expected_output="  --bind ${CLEAN_DIR}"
    output=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")
    assert_output "$expected_output"
}
