# Tests for common/utils/wipe_utils.sh

## setup

setup() {
	bats_load_library bats-support
	bats_load_library bats-assert

	# get the containing directory of this file
	# use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
	# as those will point to the bats executable's location or the preprocessed file respectively
	DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
	# source file under test
	source "${DIR}/../../../../lib/common/utils/wipe_utils.sh"

}

@test "matching experimentversionnumber and BRIDGE_EXPVER succeeds" {
    run check_expver_match "true" "experimentversionnumber=0001" "0001" "a001"
    assert_success
    assert_output --partial "experimentversionnumber matches BRIDGE_EXPVER"
}

@test "non-matching experimentversionnumber and BRIDGE_EXPVER fails" {
    run check_expver_match "true" "experimentversionnumber=0001" "a001" "a001"
    assert_failure
    assert_output --partial "Mismatch: experimentversionnumber=0001, BRIDGE_EXPVER=a001"
}

@test "missing experimentversionnumber fails" {
    run check_expver_match "true" "subcenter=23" "0001" "a001"
    assert_failure
    assert_output --partial "experimentversionnumber field is not modified and BRIDGE_EXPVER does not match EXPVER."
}

@test "missing experimentversionnumber with matching expvers succeds" {
    run check_expver_match "true" "subcenter=23" "a001" "a001"
    assert_success
    assert_output --partial "The transfer job is modifying the metadata, but the experimentversionnumber field is not present."
}

@test "modify metadata in transfer not true and BRIDGE_EXPVER matches EXPVER succeeds" {
    run check_expver_match "false" "experimentversionnumber=0001" "a001" "a001"
    assert_success
    assert_output --partial "MODIFY_METADATA_TRANSFER is not true, but the BRIDGE_EXPVER matches the experiment EXPVER"
}

@test "modify metadata in  transfer not true and BRIDGE_EXPVER does not match EXPVER fails" {
    run check_expver_match "false" "experimentversionnumber=0001" "0001" "a001"
    assert_failure
    assert_output --partial "MODIFY_METADATA_TRANSFER is not true, but the BRIDGE_EXPVER does not match the experiment EXPVER."
}
