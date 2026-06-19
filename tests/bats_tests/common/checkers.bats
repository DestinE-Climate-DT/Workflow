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

@test "checker_run_lra_generator LRA false and no prev exp" {
    export RUN_LRA_GENERATOR="False"
    run checker_run_lra_generator
    assert_failure
    assert_output --partial "CONFIGURATION.ADDITIONAL_JOBS.LRA is set to False and no previous AQUA experiment was entered to reanalyze."
    assert_output --partial "Please either set CONFIGURATION.ADDITIONAL_JOBS.LRA to True or designate a previous AQUA experiment to reanalyze using AQUA.PREV_EXP"
}

@test "checker_run_lra_generator LRA false and prev exp" {
    export RUN_LRA_GENERATOR="False"
    export PREV_AQUA_EXP="t0001"
    run checker_run_lra_generator
    assert_success
}

@test "checker_data_portfolio undefined with set -u for model workflow" {
    export WORKFLOW="model"
    set -u
    run checker_data_portfolio
    assert_failure
    assert_output "CONFIGURATION.DATA_PORTFOLIO is not defined. Please set it in main.yml under CONFIGURATION.DATA_PORTFOLIO."
}

@test "checker_data_portfolio undefined with set -u for end-to-end workflow" {
    export WORKFLOW="end-to-end"
    set -u
    run checker_data_portfolio
    assert_failure
    assert_output "CONFIGURATION.DATA_PORTFOLIO is not defined. Please set it in main.yml under CONFIGURATION.DATA_PORTFOLIO."
}

@test "checker_data_portfolio empty argument with set -u for model workflow" {
    export WORKFLOW="model"
    set -u
    run checker_data_portfolio ""
    assert_failure
    assert_output "CONFIGURATION.DATA_PORTFOLIO is not defined. Please set it in main.yml under CONFIGURATION.DATA_PORTFOLIO."
}

@test "checker_data_portfolio undefined for apps workflow" {
    export WORKFLOW="apps"
    run checker_data_portfolio ""
    assert_success
}

@test "checker_data_portfolio undefined for simless workflow" {
    export WORKFLOW="simless"
    run checker_data_portfolio ""
    assert_failure
    assert_output "CONFIGURATION.DATA_PORTFOLIO is not defined. Please set it in main.yml under CONFIGURATION.DATA_PORTFOLIO."
}

@test "checker_data_portfolio valid value" {
    run checker_data_portfolio "full"
    assert_success
    assert_output "CONFIGURATION.DATA_PORTFOLIO is full"
}

@test "checker_data_portfolio invalid value" {
    run checker_data_portfolio "partial"
    assert_failure
    assert_output "CONFIGURATION.DATA_PORTFOLIO 'partial' is not valid. Choose one of: full, reduced, minimal."
}

@test "checker_run_type undefined with set -u" {
    set -u
    run checker_run_type
    assert_failure
    assert_output "RUN.TYPE is not defined. Please set it in main.yml under RUN.TYPE."
}

@test "checker_run_type invalid value" {
    run checker_run_type "staging"
    assert_failure
    assert_output --partial "RUN.TYPE 'staging' is not valid."
}
