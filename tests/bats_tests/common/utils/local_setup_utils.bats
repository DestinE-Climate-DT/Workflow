# Tests for common/utils/local_setup_utils.sh

## setup

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  # get the containing directory of this file
  # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
  # as those will point to the bats executable's location or the preprocessed file respectively
  DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
  export ROOTDIR="${BATS_TMPDIR}/"
  export PROJDEST="test/bat"

  # source file under test
  source "${DIR}/../../../../lib/common/utils/local_setup_utils.sh"

}

## pre-configuration-ifs
@test "by default pre-configuration-ifs returns true" {
	run pre-configuration-ifs
	assert_success "true"
}

## pre-configuration-icon
@test "by default pre-configuration-icon returns true" {
	run pre-configuration-icon
	assert_success "true"
}

## pre-configuration-nemo
@test "by default pre-configuration-nemo returns true" {
	run pre-configuration-nemo
	assert_success "true"
}

## checker_icon
@test "by default checker_icon returns true" {
    run checker_icon
    assert_success
}

## checker_ifs-fesom
@test "by default checker_ifs-fesom returns true" {
    run checker_ifs-fesom
    assert_success
}

# tar_directory
@test "tar_directory test compression" {
    mkdir -p "${ROOTDIR}/proj/${PROJDEST}"
    touch "${ROOTDIR}/proj/${PROJDEST}/batar.test"

    run tar_directory "${ROOTDIR}/proj" "${PROJDEST}"
    assert_success
    assert [ -e "${ROOTDIR}/proj/${PROJDEST}.tar.gz" ]

    run rm -rf "${ROOTDIR}/proj/${PROJDEST}.tar.gz"
    assert_success
}
