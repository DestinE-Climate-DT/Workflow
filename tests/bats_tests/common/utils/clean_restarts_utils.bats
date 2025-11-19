# Tests for common/utils/clean_restarts_utils.sh

## setup

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
    # source file under test
    source "${DIR}/../../../../lib/common/utils/clean_restarts_utils.sh"

}

@test "test_delete_restarts nothing to delete" {
    export KEEP_EVERY=12
    RESTART_DIR="${ROOTDIR}/restarts"
    RESTARTS="1 2 3 4"

    for dir in $RESTARTS; do
        mkdir -p "$RESTART_DIR/$dir"
    done

    run delete_restarts
    assert_success "Not enough restarts to delete anything."
}

@test "test_delete_restarts more numbers" {
    export KEEP_EVERY=12
    RESTART_DIR="${ROOTDIR}/restarts"
    # should keep the 1st and multiples of 12 + 1
    RESTARTS="1 13 25 35 37"
    mkdir -p "$RESTART_DIR"

    for dir in $RESTARTS; do
        mkdir -p "$RESTART_DIR/$dir"
    done

    run delete_restarts
    assert_output --partial "Deleting restart 35."

    # assert 27 was deleted and the rest were kept
    [ ! -d "$RESTART_DIR/35" ]
    [ -d "$RESTART_DIR/1" ]
    [ -d "$RESTART_DIR/13" ]
    [ -d "$RESTART_DIR/25" ]
    [ -d "$RESTART_DIR/37" ]

    # clean up
    rm -rf "${RESTART_DIR}"
}
