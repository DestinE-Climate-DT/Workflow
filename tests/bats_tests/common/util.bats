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

@test "get_member_number derives the realization from a list not starting at fc0" {
	MEMBER_NUMBER=$(get_member_number "fc10" "fc10")
	assert_equal "${MEMBER_NUMBER}" "11"
}

@test "get_member_number numbers an arbitrary-index member list by identity" {
	MEMBER_LIST="fc10 fc11 fc12"
	assert_equal "$(get_member_number "${MEMBER_LIST}" "fc10")" "11"
	assert_equal "$(get_member_number "${MEMBER_LIST}" "fc11")" "12"
	assert_equal "$(get_member_number "${MEMBER_LIST}" "fc12")" "13"
}

@test "get_member_number numbers a multi-member list from fc0" {
	MEMBER_LIST="fc0 fc1"
	assert_equal "$(get_member_number "${MEMBER_LIST}" "fc0")" "1"
	assert_equal "$(get_member_number "${MEMBER_LIST}" "fc1")" "2"
}

@test "get_member_number reads zero-padded members as base 10" {
	MEMBER_LIST="fc08 fc09"
	assert_equal "$(get_member_number "${MEMBER_LIST}" "fc08")" "9"
	assert_equal "$(get_member_number "${MEMBER_LIST}" "fc09")" "10"
}

@test "get_member_number fails for a member name outside the fcN format" {
	run get_member_number "default" "default"
	assert_failure
	assert_output "Member 'default' is not in the expected fcN format."
}

@test "get_member_number fails when the member is not in the list" {
	run get_member_number "fc0 fc1" "fc7"
	assert_failure
	assert_output "Member not found in the list."
}

# Callers use $(get_member_number ...), which would capture an error on stdout
@test "get_member_number writes errors to stderr, not into the captured value" {
	CAPTURED=$(get_member_number "default" "default" 2>/dev/null) || true
	assert_equal "${CAPTURED}" ""

	CAPTURED=$(get_member_number "fc0 fc1" "fc7" 2>/dev/null) || true
	assert_equal "${CAPTURED}" ""
}

@test "get_realization_list maps a member list to its realizations" {
	assert_equal "$(get_realization_list "fc0 fc1 fc2")" "1 2 3"
	assert_equal "$(get_realization_list "fc10 fc11 fc12")" "11 12 13"
	assert_equal "$(get_realization_list "fc0")" "1"
}

@test "get_realization_list fails on a member outside the fcN format" {
	run get_realization_list "fc0 default"
	assert_failure

	CAPTURED=$(get_realization_list "fc0 default" 2>/dev/null) || true
	assert_equal "${CAPTURED}" ""
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

@test "requires_process_monthly_nrt returns false for a daily split inside the month" {
	START_DATE="20170101"
	SPLIT_END_DATE="20170102"
	RESULT=$(requires_process_monthly_nrt "$START_DATE" "$SPLIT_END_DATE")
	assert_equal "${RESULT}" "false"
}

@test "requires_process_monthly_nrt returns true for the split crossing the month boundary" {
	START_DATE="20170131"
	SPLIT_END_DATE="20170201"
	RESULT=$(requires_process_monthly_nrt "$START_DATE" "$SPLIT_END_DATE")
	assert_equal "${RESULT}" "true"
}

@test "requires_process_monthly_nrt returns true for the split crossing the year boundary" {
	START_DATE="20171231"
	SPLIT_END_DATE="20180101"
	RESULT=$(requires_process_monthly_nrt "$START_DATE" "$SPLIT_END_DATE")
	assert_equal "${RESULT}" "true"
}

@test "get_month_start_date returns day 1 of the month for a boundary split" {
	RESULT=$(get_month_start_date "20170131")
	assert_equal "${RESULT}" "20170101"
}

@test "get_month_start_date is a no-op for a date already on day 1" {
	RESULT=$(get_month_start_date "20170101")
	assert_equal "${RESULT}" "20170101"
}

@test "get_request_start_date keeps the start date for a non-monthly profile" {
	RESULT=$(get_request_start_date "clte_general_request.yaml" "20170131")
	assert_equal "${RESULT}" "20170131"
}

@test "get_request_start_date widens a monthly profile to day 1 (LUMI *monthly*)" {
	RESULT=$(get_request_start_date "general_request_monthly.yaml" "20170131")
	assert_equal "${RESULT}" "20170101"
}

@test "get_request_start_date widens a clmn profile to day 1 (MN5 *clmn*)" {
	RESULT=$(get_request_start_date "general_request_clmn.yaml" "20170131")
	assert_equal "${RESULT}" "20170101"
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
