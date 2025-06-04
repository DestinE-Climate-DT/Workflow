# Tests for templates/transfer.sh

## setup

load_singularity() {
    echo 'Loading singularity'
    true
}


singularity() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            exec)
                shift
                ;;
            --cleanenv)
                export -n $(env | cut -d= -f1)
                shift
                ;;
            --no-home)
                shift
                ;;
            --env)
                shift
                export "$1"
                shift
                ;;
            --bind)
                shift
                ;;
            *)
                CMD="$1"
                echo "CMD: $CMD"
                shift
                ;;
        esac
    done
    bash -c "$CMD"
    echo 'Running singularity'
    true
}

git() {
    echo 'Running git'
    true
}

mock_profile() {
    mkdir -p "$DQC_PROFILE_PATH"
    touch "$DQC_PROFILE_PATH/test.yaml"
}

mock_gribfile() {
    mkdir -p "${ROOTDIR}/transfer_requests"
    dd if=/dev/zero of="${ROOTDIR}/transfer_requests/test_sdate_${START_DATE}_endate_${SECOND_TO_LAST_DATE}.grb" bs=1M count=1
}

mock_mars_bin() {
    mkdir -p "${FDB_HOME}/bin"
    touch "${FDB_HOME}/bin/mars"
    chmod +x "${FDB_HOME}/bin/mars"
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
    local tar_exclude_submodules="--exclude=gsv_interface --exclude=one_pass --exclude=urban --exclude=energy_onshore --exclude=energy_offshore --exclude=obsall --exclude=icon-mpim --exclude=ifs-fesom --exclude=dvc-cache-de340 --exclude=ifs-nemo --exclude=mhm --exclude=wildfires_wise --exclude=wildfires_fwi --exclude=hydromet --exclude=wildfires_spitfire --exclude=mrm --exclude=aqua"
    # TODO: Use exclude-vcs when we upgrade the tar version used in Docker
    #       local tar_exclude="--exclude-vcs --exclude-vcs-ignores ${tar_exclude_submodules}"
    local tar_exclude="--exclude=.git --exclude=docs/build ${tar_exclude_submodules}"
    eval "tar ${tar_exclude} -cf - ." | (cd "${ROOTDIR}/proj/${PROJDEST}"; tar xvf -)
    popd

    export CURRENT_ARCH="LUMI"
    export CHUNK="1"
    export START_DATE="20000101"
    export SECOND_TO_LAST_DATE="20000131"
    export MODEL_NAME="icon"
    export DATABRIDGE_FDB_HOME="${ROOTDIR}/proj/${PROJDEST}/fdb"
    export EXPERIMENT="test"
    export ACTIVITY="test"
    export GENERATION="2"
    export DQC_PROFILE_PATH="${ROOTDIR}/profiles"
    export FDB_HOME="${ROOTDIR}/proj/${PROJDEST}/fdb"
    export EXPVER="test"
    export SCRATCH_DIR="${ROOTDIR}/proj/${PROJDEST}/scratch"
    export HPC_CONTAINER_DIR="${ROOTDIR}/proj/${PROJDEST}/containers"
    export GSV_VERSION="1"
    export LIBDIR="${ROOTDIR}/proj/${PROJDEST}/lib"
    export SCRIPTDIR="${ROOTDIR}/proj/${PROJDEST}/runscripts"
    export MEMBER="1"
    export MEMBER_LIST="1 2 3 4 5 6 7 8 9 10"
    export FDB_PROD="${ROOTDIR}/proj/${PROJDEST}/fdb_prod"
    export FDB_INFO_FILE_PATH="${ROOTDIR}/proj/${PROJDEST}"
    export FDB_INFO_FILE_NAME="${FDB_INFO_FILE_PATH}/a000.yaml"
    export BASE_VERSION="1"
    export SPLIT_END_DATE="20000131"
    export OPERATIONAL_PROJECT_SCRATCH="${SCRATCH_DIR}/proj/${PROJDEST}"
    export DEVELOPMENT_PROJECT_SCRATCH="${SCRATCH_DIR}/proj/${PROJDEST}"

    mock_profile
}

@test "load_template_with_doit" {
    WIPE_DOIT="true"
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/wipe.sh" ${ROOTDIR} ${CURRENT_ARCH} ${CHUNK} ${START_DATE} ${SECOND_TO_LAST_DATE} ${MODEL_NAME} ${DATABRIDGE_FDB_HOME} ${EXPERIMENT} ${ACTIVITY} ${GENERATION} ${DQC_PROFILE_PATH} ${EXPVER} ${FDB_HOME} ${SCRATCH_DIR} ${HPC_CONTAINER_DIR} ${GSV_VERSION} ${LIBDIR} ${SCRIPTDIR} ${WIPE_DOIT} ${MEMBER} ${MEMBER_LIST} ${FDB_INFO_FILE_PATH} ${FDB_INFO_FILE_NAME} ${BASE_VERSION} ${SPLIT_END_DATE} ${OPERATIONAL_PROJECT_SCRATCH} ${DEVELOPMENT_PROJECT_SCRATCH}
    assert_success
}

@test "load_template_without_doit" {
    WIPE_DOIT="false"
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/wipe.sh" ${ROOTDIR} ${CURRENT_ARCH} ${CHUNK} ${START_DATE} ${SECOND_TO_LAST_DATE} ${MODEL_NAME} ${DATABRIDGE_FDB_HOME} ${EXPERIMENT} ${ACTIVITY} ${GENERATION} ${DQC_PROFILE_PATH} ${EXPVER} ${FDB_HOME} ${SCRATCH_DIR} ${HPC_CONTAINER_DIR} ${GSV_VERSION} ${LIBDIR} ${SCRIPTDIR} ${WIPE_DOIT} ${MEMBER} ${MEMBER_LIST} ${FDB_INFO_FILE_PATH} ${FDB_INFO_FILE_NAME} ${BASE_VERSION} ${SPLIT_END_DATE} ${OPERATIONAL_PROJECT_SCRATCH} ${DEVELOPMENT_PROJECT_SCRATCH}
    assert_success
}
