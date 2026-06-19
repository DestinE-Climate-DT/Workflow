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
    RESTART_DIR="${ROOTDIR}/restarts"
    RESTARTS="1 2 3 4"

    for dir in $RESTARTS; do
        mkdir -p "$RESTART_DIR/$dir"
    done

    run delete_restarts "${RESTART_DIR}" 12 3
    assert_success "Not enough restarts to delete anything."

    # clean up
    rm -rf "${RESTART_DIR}"
}

@test "test_delete_restarts more numbers" {
    RESTART_DIR="${ROOTDIR}/restarts"
    # should keep: 1 (first), 13 and 25 (KEEP_EVERY interval), 35 (KEEP_LAST), 37 (interval)
    # should delete: 2 and 3 (not interval, not in last 3)
    RESTARTS="1 2 3 13 25 35 37"
    mkdir -p "$RESTART_DIR"

    for dir in $RESTARTS; do
        mkdir -p "$RESTART_DIR/$dir"
    done

    run delete_restarts "${RESTART_DIR}" 12 3
    assert_output --partial "Deleting restart ${RESTART_DIR}/2."
    assert_output --partial "Deleting restart ${RESTART_DIR}/3."

    # assert 2, 3 were deleted
    [ ! -d "$RESTART_DIR/2" ]
    [ ! -d "$RESTART_DIR/3" ]
    # assert the rest were kept (35 kept by KEEP_LAST)
    [ -d "$RESTART_DIR/1" ]
    [ -d "$RESTART_DIR/13" ]
    [ -d "$RESTART_DIR/25" ]
    [ -d "$RESTART_DIR/35" ]
    [ -d "$RESTART_DIR/37" ]

    # clean up
    rm -rf "${RESTART_DIR}"
}

@test "test_delete_restarts fails when KEEP_EVERY is unset" {
    RESTART_DIR="${ROOTDIR}/restarts"
    mkdir -p "$RESTART_DIR/1"

    run delete_restarts "${RESTART_DIR}" "" 3
    assert_failure
    assert_output --partial "ERROR: KEEP_EVERY is not set"

    # clean up
    rm -rf "${RESTART_DIR}"
}

@test "test_delete_restarts fails when KEEP_EVERY is zero" {
    RESTART_DIR="${ROOTDIR}/restarts"
    mkdir -p "$RESTART_DIR/1"

    run delete_restarts "${RESTART_DIR}" 0 3
    assert_failure
    assert_output --partial "ERROR: KEEP_EVERY must be a positive integer"

    # clean up
    rm -rf "${RESTART_DIR}"
}

@test "test_delete_restarts fails when KEEP_EVERY is non-numeric" {
    RESTART_DIR="${ROOTDIR}/restarts"
    mkdir -p "$RESTART_DIR/1"

    run delete_restarts "${RESTART_DIR}" "abc" 3
    assert_failure
    assert_output --partial "ERROR: KEEP_EVERY must be a positive integer"

    # clean up
    rm -rf "${RESTART_DIR}"
}

@test "test_delete_restarts fails when RESTART_DIR is empty" {
    run delete_restarts "" 12 3
    assert_failure
    assert_output --partial "ERROR: RESTART_DIR is not set"
}

@test "test_delete_restarts fails when RESTART_DIR is a relative path" {
    run delete_restarts "relative/path/to/restarts" 12 3
    assert_failure
    assert_output --partial "ERROR: Unsafe RESTART_DIR"
}

@test "test_delete_restarts fails when RESTART_DIR is root /" {
    run delete_restarts "/" 12 3
    assert_failure
    assert_output --partial "ERROR: Unsafe RESTART_DIR"
}

@test "test_delete_restarts succeeds when RESTART_DIR does not exist" {
    run delete_restarts "${ROOTDIR}/nonexistent_dir" 12 3
    assert_success
    assert_output --partial "does not exist. Nothing to do."
}

@test "test_delete_restarts fails when KEEP_LAST is unset" {
    RESTART_DIR="${ROOTDIR}/restarts"
    mkdir -p "$RESTART_DIR/1"

    run delete_restarts "${RESTART_DIR}" 12 ""
    assert_failure
    assert_output --partial "ERROR: KEEP_LAST is not set"

    # clean up
    rm -rf "${RESTART_DIR}"
}

@test "test_delete_restarts fails when KEEP_LAST is zero" {
    RESTART_DIR="${ROOTDIR}/restarts"
    mkdir -p "$RESTART_DIR/1"

    run delete_restarts "${RESTART_DIR}" 12 0
    assert_failure
    assert_output --partial "ERROR: KEEP_LAST must be a positive integer"

    # clean up
    rm -rf "${RESTART_DIR}"
}

@test "test_delete_restarts keeps last N restarts" {
    RESTART_DIR="${ROOTDIR}/restarts"
    # Dirs: 1 2 3 4 5 6 7
    # KEEP_EVERY=12 keeps: 1, 13, 25... (only 1 applies here)
    # KEEP_LAST=3 keeps: 5, 6, 7 (last 3)
    # Should delete: 2, 3, 4
    RESTARTS="1 2 3 4 5 6 7"

    for dir in $RESTARTS; do
        mkdir -p "$RESTART_DIR/$dir"
    done

    run delete_restarts "${RESTART_DIR}" 12 3
    assert_output --partial "Deleting restart ${RESTART_DIR}/2."
    assert_output --partial "Deleting restart ${RESTART_DIR}/3."
    assert_output --partial "Deleting restart ${RESTART_DIR}/4."

    # assert 2, 3, 4 were deleted
    [ ! -d "$RESTART_DIR/2" ]
    [ ! -d "$RESTART_DIR/3" ]
    [ ! -d "$RESTART_DIR/4" ]
    # assert 1, 5, 6, 7 were kept
    [ -d "$RESTART_DIR/1" ]
    [ -d "$RESTART_DIR/5" ]
    [ -d "$RESTART_DIR/6" ]
    [ -d "$RESTART_DIR/7" ]

    # clean up
    rm -rf "${RESTART_DIR}"
}

@test "test_delete_restarts keep_last preserves recent over keep_every deletion" {
    RESTART_DIR="${ROOTDIR}/restarts"
    # Dirs: 1 2 3 4 5 6 7 8 9
    # KEEP_EVERY=4 keeps: 1, 5, 9 (where (dir-1) % 4 == 0)
    # KEEP_LAST=2 keeps: 8, 9 (last 2)
    # Should delete: 2, 3, 4, 6, 7 — but 8 is protected by KEEP_LAST
    RESTARTS="1 2 3 4 5 6 7 8 9"

    for dir in $RESTARTS; do
        mkdir -p "$RESTART_DIR/$dir"
    done

    run delete_restarts "${RESTART_DIR}" 4 2
    assert_output --partial "Deleting restart ${RESTART_DIR}/2."
    assert_output --partial "Deleting restart ${RESTART_DIR}/3."
    assert_output --partial "Deleting restart ${RESTART_DIR}/4."
    assert_output --partial "Deleting restart ${RESTART_DIR}/6."
    assert_output --partial "Deleting restart ${RESTART_DIR}/7."

    # assert deleted
    [ ! -d "$RESTART_DIR/2" ]
    [ ! -d "$RESTART_DIR/3" ]
    [ ! -d "$RESTART_DIR/4" ]
    [ ! -d "$RESTART_DIR/6" ]
    [ ! -d "$RESTART_DIR/7" ]
    # assert kept (first + interval + last 2)
    [ -d "$RESTART_DIR/1" ]
    [ -d "$RESTART_DIR/5" ]
    [ -d "$RESTART_DIR/8" ]
    [ -d "$RESTART_DIR/9" ]

    # clean up
    rm -rf "${RESTART_DIR}"
}
