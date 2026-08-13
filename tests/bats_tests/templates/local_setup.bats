# Tests for templates/local_setup.sh

## setup

git() {
    case "$1" in
        clone)
            mkdir -p "$3"
            ;;
        -C)
            ;;
        *)
            echo 'Running git'
            ;;
    esac
    true
}

mock_git() {
    # -f to ensure that sub-shells can also use the mock
    export -f git
}

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PROJECT_DIR="${DIR}/../../../"

    export ROOTDIR="${BATS_TMPDIR}/"
    export PROJDEST="test/bat"

    # Copy the workflow project into ${BATS_TMPDIR}/proj/workflow,
    # imitating what `autosubmit create|refresh` do -- as this is
    # expected by the `local_setup.sh` template script.
    mkdir -pv "${ROOTDIR}/proj/${PROJDEST}"

    # cp is slow! https://basila.medium.com/fastest-way-to-copy-a-directory-in-linux-40611d2c5aa4
    # cp -r "${PROJECT_DIR}/." "${ROOTDIR}/proj/${PROJDEST}"
    git config --global --add safe.directory /code
    pushd "${PROJECT_DIR}/"
    # TODO: Why this is not working?
    #       local tar_exclude_submodules="$(git config --file .gitmodules --get-regexp path | awk '{ print $2 }' | xargs -I{} echo "--exclude={}" | paste -s -d' ')"
    local tar_exclude_submodules="--exclude=gsv_interface --exclude=one_pass --exclude=urban --exclude=energy_indicators --exclude=obsall --exclude=icon-mpim --exclude=ifs-fesom --exclude=dvc-cache-de340 --exclude=ifs-nemo --exclude=mhm --exclude=wildfires_wise --exclude=wildfires_fwi --exclude=hydromet --exclude=wildfires_spitfire --exclude=mrm --exclude=aqua"
    # TODO: Use exclude-vcs when we upgrade the tar version used in Docker
    #       local tar_exclude="--exclude-vcs --exclude-vcs-ignores ${tar_exclude_submodules}"
    local tar_exclude="--exclude=.git --exclude=docs/build ${tar_exclude_submodules}"
    eval "tar ${tar_exclude} -cf - ." | (cd "${ROOTDIR}/proj/${PROJDEST}"; tar xvf -)
    popd

    export MODEL_NAME="icon"
    export HPCARCH="LUMI"
    export MODEL_VERSION="1"
    export ENVIRONMENT="PleaseNotCray"

    export NEMO_XPROC=2
    export NEMO_YPROC=2
    export IO_NODES=2
    export NODES=3
    export TASKS=16

    export DVC_INPUTS_BRANCH="ClimateDT-phase2"
    export APP="NONE"
    export WORKFLOW="model"

    export INSTALL="False"
    export RUN_TYPE="test"

    export COMPILE="False"
    export USE_FXED_DVC_COMMIT="False"
    export AQUA_ON="False"
    export DOWNLOAD_ADDITIONAL_DEPENDENCIES="False"
    export DATELIST="19900101"
    export CLEAN_RESTARTS_ON="False"
    export BACKUP_ON="False"
    export RUN_LRA_GENERATOR="False"
    export PREV_AQUA_EXP=""
    export DATA_PORTFOLIO="full"
    export CATALOG_REF="e26.1_v2"
    # Non-empty: unquoted $(local_setup_tail_args) would drop empty fields and
    # shift MEMBERS out of position 31
    export IFS_IO_PPN="0"
    export NEMO_IO_PPN="0"
    export IFS_IO_NODES="0"
    export NEMO_IO_NODES="0"
    export IFS_IO_TASKS="0"
    export NEMO_IO_TASKS="0"
    export MEMBERS="fc0"

    mock_git
}

# Positional args 22-31, so MEMBERS reaches checker_members instead of the placeholder
local_setup_tail_args() {
    echo "${CATALOG_REF}" "${NODES}" "${TASKS}" "${IFS_IO_PPN}" "${NEMO_IO_PPN}" \
        "${IFS_IO_NODES}" "${NEMO_IO_NODES}" "${IFS_IO_TASKS}" "${NEMO_IO_TASKS}" \
        "${MEMBERS}"
}

@test "clean_restarts on but backup off" {
    CLEAN_RESTARTS_ON="True"
    BACKUP_ON="False"

    run source "${ROOTDIR}/proj/${PROJDEST}/templates/local_setup.sh" \
        "${ROOTDIR}" "${PROJDEST}" "${MODEL_NAME}" "${HPCARCH}" "${MODEL_VERSION}" \
        "${ENVIRONMENT}" "${DVC_INPUTS_BRANCH}" "${APP}" "${WORKFLOW}" "${INSTALL}" \
        "${RUN_TYPE}" "${COMPILE}" "${USE_FXED_DVC_COMMIT}" "${AQUA_ON}" \
        "${DOWNLOAD_ADDITIONAL_DEPENDENCIES}" "${DATELIST}" \
        "${CLEAN_RESTARTS_ON}" "${BACKUP_ON}" "${RUN_LRA_GENERATOR}" "${PREV_AQUA_EXP}" \
        "${DATA_PORTFOLIO}" $(local_setup_tail_args)
    [ "$status" -eq 1 ]
    [[ "$output" == *"Please set the BACKUP additional job to True"* ]]
}

# checker_data_portfolio should fail because the DATA_PORTFOLIO is undefined
@test "checker_data_portfolio with undefined data_portfolio" {
    DATA_PORTFOLIO=""

    run source "${ROOTDIR}/proj/${PROJDEST}/templates/local_setup.sh" \
        "${ROOTDIR}" "${PROJDEST}" "${MODEL_NAME}" "${HPCARCH}" "${MODEL_VERSION}" \
        "${ENVIRONMENT}" "${DVC_INPUTS_BRANCH}" "${APP}" "${WORKFLOW}" "${INSTALL}" \
        "${RUN_TYPE}" "${COMPILE}" "${USE_FXED_DVC_COMMIT}" "${AQUA_ON}" \
        "${DOWNLOAD_ADDITIONAL_DEPENDENCIES}" "${DATELIST}" \
        "${CLEAN_RESTARTS_ON}" "${BACKUP_ON}" "${RUN_LRA_GENERATOR}" "${PREV_AQUA_EXP}" \
        "${DATA_PORTFOLIO}" $(local_setup_tail_args)
    assert_failure
    [[ "$output" == *"CONFIGURATION.DATA_PORTFOLIO is not defined. Please set it in main.yml under CONFIGURATION.DATA_PORTFOLIO."* ]]
}

# checker_data_portfolio should fail because the DATA_PORTFOLIO is invalid
@test "checker_data_portfolio with invalid value data_portfolio" {
    DATA_PORTFOLIO="invalid"

    run source "${ROOTDIR}/proj/${PROJDEST}/templates/local_setup.sh" \
        "${ROOTDIR}" "${PROJDEST}" "${MODEL_NAME}" "${HPCARCH}" "${MODEL_VERSION}" \
        "${ENVIRONMENT}" "${DVC_INPUTS_BRANCH}" "${APP}" "${WORKFLOW}" "${INSTALL}" \
        "${RUN_TYPE}" "${COMPILE}" "${USE_FXED_DVC_COMMIT}" "${AQUA_ON}" \
        "${DOWNLOAD_ADDITIONAL_DEPENDENCIES}" "${DATELIST}" \
        "${CLEAN_RESTARTS_ON}" "${BACKUP_ON}" "${RUN_LRA_GENERATOR}" "${PREV_AQUA_EXP}" \
        "${DATA_PORTFOLIO}" $(local_setup_tail_args)
    assert_failure
    [[ "$output" == *"CONFIGURATION.DATA_PORTFOLIO '${DATA_PORTFOLIO}' is not valid. Choose one of: full, reduced, minimal."* ]]
}

# should succeed
@test "local_setup for ifs-nemo" {
    MODEL_NAME="ifs-nemo"

    # set up for the data_portfolio check
    mkdir -p "${ROOTDIR}/proj/${PROJDEST}/dvc-cache-de340"
    touch "${ROOTDIR}/proj/${PROJDEST}/dvc-cache-de340/file"

    run source "${ROOTDIR}/proj/${PROJDEST}/templates/local_setup.sh" \
        "${ROOTDIR}" "${PROJDEST}" "${MODEL_NAME}" "${HPCARCH}" "${MODEL_VERSION}" \
        "${ENVIRONMENT}" "${DVC_INPUTS_BRANCH}" "${APP}" "${WORKFLOW}" "${INSTALL}" \
        "${RUN_TYPE}" "${COMPILE}" "${USE_FXED_DVC_COMMIT}" "${AQUA_ON}" \
        "${DOWNLOAD_ADDITIONAL_DEPENDENCIES}" "${DATELIST}" \
        "${CLEAN_RESTARTS_ON}" "${BACKUP_ON}" "${RUN_LRA_GENERATOR}" "${PREV_AQUA_EXP}" \
        "${DATA_PORTFOLIO}" $(local_setup_tail_args)
    assert_success
}

# should fail because the DVC directory will be empty
@test "local_setup for ifs-nemo with empty DVC directory" {
    MODEL_NAME="ifs-nemo"
    # Ensure the DVC cache directory is completely empty (including hidden files)
    rm -rf "${ROOTDIR}/proj/${PROJDEST}/dvc-cache-de340"
    mkdir -p "${ROOTDIR}/proj/${PROJDEST}/dvc-cache-de340"

    run source "${ROOTDIR}/proj/${PROJDEST}/templates/local_setup.sh" \
        "${ROOTDIR}" "${PROJDEST}" "${MODEL_NAME}" "${HPCARCH}" "${MODEL_VERSION}" \
        "${ENVIRONMENT}" "${DVC_INPUTS_BRANCH}" "${APP}" "${WORKFLOW}" "${INSTALL}" \
        "${RUN_TYPE}" "${COMPILE}" "${USE_FXED_DVC_COMMIT}" "${AQUA_ON}" \
        "${DOWNLOAD_ADDITIONAL_DEPENDENCIES}" "${DATELIST}" \
        "${CLEAN_RESTARTS_ON}" "${BACKUP_ON}" "${RUN_LRA_GENERATOR}" "${PREV_AQUA_EXP}" \
        "${DATA_PORTFOLIO}" $(local_setup_tail_args)
    assert_failure
    [[ "$output" == *"The DVC cache submodule has failed to clone."* ]]
}

# should succeed despite the data-portfolio submodule being empty
@test "local_setup for nemo without data-portfolio contents" {
    MODEL_NAME="nemo"
    mkdir -p "${ROOTDIR}/proj/${PROJDEST}/dvc-cache-de340"
    touch "${ROOTDIR}/proj/${PROJDEST}/dvc-cache-de340/fake_file.txt"
    # Ensure the data-portfolio directory is empty
    rm -rf "${ROOTDIR}/proj/${PROJDEST}/data-portfolio/"
    # even if it's not cloned, the parent folder still exists
    mkdir -p "${ROOTDIR}/proj/${PROJDEST}/data-portfolio/"

    run source "${ROOTDIR}/proj/${PROJDEST}/templates/local_setup.sh" \
        "${ROOTDIR}" "${PROJDEST}" "${MODEL_NAME}" "${HPCARCH}" "${MODEL_VERSION}" \
        "${ENVIRONMENT}" "${DVC_INPUTS_BRANCH}" "${APP}" "${WORKFLOW}" "${INSTALL}" \
        "${RUN_TYPE}" "${COMPILE}" "${USE_FXED_DVC_COMMIT}" "${AQUA_ON}" \
        "${DOWNLOAD_ADDITIONAL_DEPENDENCIES}" "${DATELIST}" \
        "${CLEAN_RESTARTS_ON}" "${BACKUP_ON}" "${RUN_LRA_GENERATOR}" "${PREV_AQUA_EXP}" \
        "${DATA_PORTFOLIO}" $(local_setup_tail_args)
    assert_success
}
