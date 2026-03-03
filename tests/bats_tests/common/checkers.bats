# Tests for common/checkers.sh

## setup

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
    # source file under test
    source "${DIR}/../../../lib/common/checkers.sh"
    export ROOTDIR="${BATS_TMPDIR}/"
    export PROJDEST="test/bat"

    # set variables for everything that is needed
    WORKFLOW="model"
    MODEL_NAME="ifs-nemo"
    COMPILE="True"
    AQUA_ON="True"
    DVC_INPUTS_BRANCH="ClimateDT-phase2"
    DATELIST="19900101"

    # make the directories
    mkdir -p "${ROOTDIR}/proj/${PROJDEST}/data-portfolio"
    mkdir -p "${ROOTDIR}/proj/${PROJDEST}/${MODEL_NAME}"
    mkdir -p "${ROOTDIR}/proj/${PROJDEST}/catalog"
    mkdir -p "${ROOTDIR}/proj/${PROJDEST}/dvc-cache-de340"
}

@test "checker_submodules all errors" {
    # don't add files to the directories so there are errors
    # mimics failed cloning
    run checker_submodules
    # we should have gotten all of the errors
    expected_output='The data-portfolio submodule for the workflow has failed to clone. The ifs-nemo submodule has failed to clone. The catalog submodule has failed to clone. The data-portfolio submodule for AQUA has failed to clone. The DVC cache submodule has failed to clone.'
    assert_output "${expected_output}"
}

@test "checker_submodules no errors" {
    # add files to the directories so they are not empty
    # mimics successful cloning
    cd ${ROOTDIR}/proj/${PROJDEST}/
    for directory in */; do
        touch "$directory/fake_file.txt"
    done

    run checker_submodules
    # we should have gotten 0 errors and have no output
    refute_output
}

@test "checker_submodules AQUA datelist" {
    # should error with multiple start dates
    DATELIST="19900101 20200101"

    expected_output="Multiple dates are not supported in AQUA at this time."
    run checker_submodules
    assert_output "${expected_output}"
}

@test "checker_backup_on_if_clean_restarts no BACKUP value" {
    # BACKUP_ON not defined
    export CLEAN_RESTARTS_ON="True"
    expected_output="Please set the BACKUP additional job to True if you would like to clean the restarts."

    run checker_backup_on_if_clean_restarts
    assert_failure
    assert_output --partial "${expected_output}"


}

@test "checker_backup_on_if_clean_restarts BACKUP False" {
    export CLEAN_RESTARTS_ON="True"
    export BACKUP_ON="False"
    expected_output="Please set the BACKUP additional job to True if you would like to clean the restarts."

    run checker_backup_on_if_clean_restarts
    assert_failure
    assert_output --partial "${expected_output}"
}

@test "checker_backup_on_if_clean_restarts should succeed" {
    # both are true so no error should be thrown
    export CLEAN_RESTARTS_ON="True"
    export BACKUP_ON="True"

    run checker_backup_on_if_clean_restarts
    assert_success
}
