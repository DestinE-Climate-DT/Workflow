# Tests for templates/remote_setup/generate_profiles.sh

## setup

load_singularity() {
    echo 'Loading singularity'
    true
}

# mock the load_fdb_ifs function
load_fdb_ifs() {
    echo "Fake load_fdb_ifs function called"
    # so we can assert later that it was called
    touch "${HPCROOTDIR}/load_fdb_ifs_called.flag"
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

setup() {
    bats_load_library bats-assert
    bats_load_library bats-support

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PROJECT_DIR="${DIR}/../../../"

    export HPCROOTDIR="${BATS_TMPDIR}/"
    export PROJDEST="test/bat"

    # Copy the workflow project into ${BATS_TMPDIR}/proj/workflow,
    # imitating what `autosubmit create|refresh` do -- as this is
    # expected by the `local_setup.sh` template script.
    mkdir -pv "${HPCROOTDIR}/proj/${PROJDEST}"
    mkdir -p "${HPCROOTDIR}/LOG_a000"

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
    eval "tar ${tar_exclude} -cf - ." | (cd "${HPCROOTDIR}/proj/${PROJDEST}"; tar xvf -)
    popd

    # fake it or the real load_fdb_ifs will be called
    export LIBDIR="fake_lib_dir"
    export LOAD_FDB="True"
    export MODEL_NAME="ifs-nemo"

    export MODEL_VERSION="test"
    export MODEL_PATH="${HPCROOTDIR}/model_path"
    export FDB_HOME="${HPCROOTDIR}/fdb_home"
    export EXPID="expid"
    export SIM_START_DATE="19900101"
    export SCRIPTDIR="${HPCROOTDIR}/scriptdir"
}

@test "LOAD_FDB False" {
    RUN_TYPE="test"
    LOAD_FDB="False"
    run source "${HPCROOTDIR}/proj/${PROJDEST}/templates/remote_setup/create_fdb.sh" ${LIBDIR} ${RUN_TYPE} ${LOAD_FDB} ${MODEL_NAME} ${MODEL_VERSION} ${HPCROOTDIR} ${PROJDEST} ${MODEL_PATH} ${FDB_HOME} ${EXPID} ${SIM_START_DATE} ${SCRIPTDIR}

    # should not have been called
    [ ! -f "${HPCROOTDIR}/load_fdb_ifs_called.flag" ]
    assert_success
}

@test "LOAD_FDB True" {
    RUN_TYPE="test"
    LOAD_FDB="True"
    run source "${HPCROOTDIR}/proj/${PROJDEST}/templates/remote_setup/create_fdb.sh" ${LIBDIR} ${RUN_TYPE} ${LOAD_FDB} ${MODEL_NAME} ${MODEL_VERSION} ${HPCROOTDIR} ${PROJDEST} ${MODEL_PATH} ${FDB_HOME} ${EXPID} ${SIM_START_DATE} ${SCRIPTDIR}

    [ -f "${HPCROOTDIR}/load_fdb_ifs_called.flag" ]
    assert_success
    rm "${HPCROOTDIR}/load_fdb_ifs_called.flag"
}

@test "RUN_TYPE production" {
    RUN_TYPE="Production"
    LOAD_FDB="True"
    run source "${HPCROOTDIR}/proj/${PROJDEST}/templates/remote_setup/create_fdb.sh" ${LIBDIR} ${RUN_TYPE} ${LOAD_FDB} ${MODEL_NAME} ${MODEL_VERSION} ${HPCROOTDIR} ${PROJDEST} ${MODEL_PATH} ${FDB_HOME} ${EXPID} ${SIM_START_DATE} ${SCRIPTDIR}

    # should not have been called due to the production run_type
    [ ! -f "${HPCROOTDIR}/load_fdb_ifs_called.flag" ]
    assert_success
}
