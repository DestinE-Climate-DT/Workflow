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
