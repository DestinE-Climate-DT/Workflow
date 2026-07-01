# Tests for common/utils/backup_utils.sh

## setup

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
    # source file under test
    source "${DIR}/../../../../lib/common/utils/backup_utils.sh"

}

@test "determine_should_backup CHUNK is 1" {
    export CHUNK=1
    run determine_should_backup
    assert_success "true"
}

@test "determine_should_backup CHUNK is 13" {
    export CHUNK=13
    export KEEP_EVERY=12
    run determine_should_backup
    assert_success "true"
}

@test "determine_should_backup CHUNK is 5" {
    export CHUNK=5
    export KEEP_EVERY=12
    run determine_should_backup
    assert_success "false"
}

@test "determine_should_backup KEEP_EVERY unset" {
    export CHUNK=5
    unset KEEP_EVERY
    run determine_should_backup
    assert_success "false"
}
