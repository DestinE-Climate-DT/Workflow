# Tests for common/utils/ini_utils.sh

## setup

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
    # source file under test
    source "${DIR}/../../../../lib/common/utils/ini_utils.sh"

}

@test "by default rm_rundir_icon returns true" {
    run rm_rundir_icon
    assert_success "true"
}

@test "by default perturb_icon returns true" {
    run perturb_icon
    assert_success "true"
}

@test "by default perturb_nemo returns true" {
    run perturb_nemo
    assert_success "true"
}

@test "copy_restarts_from_expid copies to the NRT chunk-1/split-1 target dir" {
    # NRT callers pass the chunk-1/split-1 dir; the 'current' symlink is created
    # by the template, not the function.
    export PRE_RESTART_DIR="${BATS_TMPDIR}/test_nrt_ini_restarts"
    export RESTART_FROM="prev_expid"
    export RESTARTS_FROM_PATH="${BATS_TMPDIR}/test_nrt_ini_src"

    mkdir -p "${RESTARTS_FROM_PATH}"
    touch "${RESTARTS_FROM_PATH}/rcf"
    touch "${RESTARTS_FROM_PATH}/waminfo"
    touch "${RESTARTS_FROM_PATH}/LAW19900101000000_000000"

    run copy_restarts_from_expid "${PRE_RESTART_DIR}/1/1/"
    assert_success

    # Restarts must be under chunk 1 / split 1
    assert [ -f "${PRE_RESTART_DIR}/1/1/rcf" ]
    assert [ -f "${PRE_RESTART_DIR}/1/1/waminfo" ]

    rm -rf "${PRE_RESTART_DIR}" "${RESTARTS_FROM_PATH}"
}

@test "copy_restarts_from_expid copies to the default chunk-1 dir" {
    # Standard callers pass the chunk-1 dir (also the default when no arg given).
    export PRE_RESTART_DIR="${BATS_TMPDIR}/test_std_ini_restarts"
    export RESTART_FROM="prev_expid"
    export RESTARTS_FROM_PATH="${BATS_TMPDIR}/test_std_ini_src"

    mkdir -p "${RESTARTS_FROM_PATH}"
    touch "${RESTARTS_FROM_PATH}/rcf"
    touch "${RESTARTS_FROM_PATH}/waminfo"

    run copy_restarts_from_expid "${PRE_RESTART_DIR}/1/"
    assert_success

    assert [ -f "${PRE_RESTART_DIR}/1/rcf" ]
    assert [ -f "${PRE_RESTART_DIR}/1/waminfo" ]

    rm -rf "${PRE_RESTART_DIR}" "${RESTARTS_FROM_PATH}"
}

@test "copy_restarts_from_expid fails when source path does not exist" {
    export PRE_RESTART_DIR="${BATS_TMPDIR}/test_nrt_ini_missing"
    export RESTART_FROM="prev_expid"
    export RESTARTS_FROM_PATH="${BATS_TMPDIR}/does_not_exist"

    run copy_restarts_from_expid "${PRE_RESTART_DIR}/1/1/"
    assert_failure
}
