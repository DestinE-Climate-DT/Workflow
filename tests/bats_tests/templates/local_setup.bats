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

load_template() {
    # source file under test
    source "${ROOTDIR}/proj/${PROJDEST}/templates/local_setup.sh" \
        "${ROOTDIR}" "${PROJDEST}" "${MODEL_NAME}" "${HPCARCH}" "${MODEL_VERSION}" \
        "${ENVIRONMENT}" "${DVC_INPUTS_BRANCH}" "${APP}" "${WORKFLOW}" "${INSTALL}" \
        "${RUN_TYPE}" "${COMPILE}" "${USE_FXED_DVC_COMMIT}" "${AQUA_ON}" \
        "${DOWNLOAD_ADDITIONAL_DEPENDENCIES}" "${DATELIST}" \
        "${CLEAN_RESTARTS_ON}" "${BACKUP_ON}" "${RUN_LRA_GENERATOR}" "${PREV_AQUA_EXP}" \
        "${DATA_PORTFOLIO}" "${CATALOG_REF}"
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
    local tar_exclude_submodules="--exclude=gsv_interface --exclude=one_pass --exclude=urban --exclude=energy_indicators --exclude=energy_offshore --exclude=obsall --exclude=icon-mpim --exclude=ifs-fesom --exclude=dvc-cache-de340 --exclude=ifs-nemo --exclude=mhm --exclude=wildfires_wise --exclude=wildfires_fwi --exclude=hydromet --exclude=wildfires_spitfire --exclude=mrm --exclude=aqua"
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

    export DVC_INPUTS_BRANCH="A"
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
    export CATALOG_REF="e26.1_v0"

    mock_git
    load_template
}

# tar_directory

@test "tar_directory test compression" {
    mkdir -p "${ROOTDIR}/proj/${PROJDEST}"
    touch "${ROOTDIR}/proj/${PROJDEST}/batar.test"

    tar_directory "${ROOTDIR}/proj" "${PROJDEST}"

    if [ -e "${ROOTDIR}/proj/${PROJDEST}.tar.gz" ]; then
        run rm -rf "${ROOTDIR}/proj/${PROJDEST}.tar.gz"
        assert_success
    else
        assert_failure
    fi
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

## checker_model_version

@test "checker_model_version tests that the MODEL-VERSION exits correctly" {
    export MODEL_VERSION="None"
    run checker_model_version
    assert_line --partial 'Bad definition of MODEL_VERSION.'
}

@test "clean_restarts on but backup off" {
    CLEAN_RESTARTS_ON="True"
    BACKUP_ON="False"

    run "${ROOTDIR}/proj/${PROJDEST}/templates/local_setup.sh" \
        "${ROOTDIR}" "${PROJDEST}" "${MODEL_NAME}" "${HPCARCH}" "${MODEL_VERSION}" \
        "${ENVIRONMENT}" "${DVC_INPUTS_BRANCH}" "${APP}" "${WORKFLOW}" "${INSTALL}" \
        "${RUN_TYPE}" "${COMPILE}" "${USE_FXED_DVC_COMMIT}" "${AQUA_ON}" \
        "${DOWNLOAD_ADDITIONAL_DEPENDENCIES}" "${DATELIST}" \
        "${CLEAN_RESTARTS_ON}" "${BACKUP_ON}" "${RUN_LRA_GENERATOR}" "${PREV_AQUA_EXP}" \
        "${DATA_PORTFOLIO}" "${CATALOG_REF}"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Please set the BACKUP additional job to True"* ]]
}
