# Tests for templates/fix_constant_variables.sh

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

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PROJECT_DIR="${DIR}/../../../"

    # Copy the workflow project into ${BATS_TMPDIR}/proj/workflow,
    # imitating what `autosubmit create|refresh` do -- as this is
    # expected by the `local_setup.sh` template script.
    mkdir -pv "${ROOTDIR}/proj/${PROJDEST}"

    # cp is slow! https://basila.medium.com/fastest-way-to-copy-a-directory-in-linux-40611d2c5aa4
    # cp -r "${PROJECT_DIR}/." "${ROOTDIR}/proj/${PROJDEST}"
    git config --global --add safe.directory /code
    pushd "${PROJECT_DIR}/"

    export ROOTDIR="${BATS_TMPDIR}/"
    export HPC_PROJECT_ROOT="${BATS_TMPDIR}/projects"
    export LOCAL_DIR="${BATS_TMPDIR}/local"
    export PROJDEST="test/bat"
    export FDB_HOME="${ROOTDIR}/proj/${PROJDEST}/fdb"
    export CHUNK="1"
    export START_DATE="01012000"
    export END_DATE="01012001"
    export MEMBER="fc0"
    export MEMBER_LIST="fc0 fc1 fc2 fc3 fc4 fc5 fc6 fc7 fc8 fc9"
    export EXPVER="test"
    export DQC_PROFILE_PATH="${ROOTDIR}/profiles"
    export EXPERIMENT="test"
    export ACTIVITY="test"
    export GENERATION="2"
    export MODEL="ifs-nemo"
    export LIBDIR="${ROOTDIR}/proj/${PROJDEST}/lib"
    export SCRATCH_DIR="${ROOTDIR}/proj/${PROJDEST}/scratch"
    export HPC_CONTAINER_DIR="${ROOTDIR}/proj/${PROJDEST}/containers"
    export GSV_VERSION="1"
    export SCRIPTDIR="${ROOTDIR}/proj/${PROJDEST}/runscripts"
}

@test "fix_constant_variables_MN5" {
    export CURRENT_ARCH="MARENOSTRUM5"
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/fix_constant_variables.sh" ${SCRATCH_DIR} ${HPC_PROJECT_ROOT} ${LOCAL_DIR} ${FDB_HOME} ${LIBDIR} ${DQC_PROFILE_PATH} ${EXPVER} ${EXPERIMENT} ${ACTIVITY} ${GENERATION} ${MEMBER} "${MEMBER_LIST}" ${MODEL} ${START_DATE} ${END_DATE} ${CHUNK} ${ROOTDIR} ${SCRIPTDIR} ${GSV_VERSION} ${CURRENT_ARCH} ${HPC_CONTAINER_DIR}
    assert_success
}

@test "fix_constant_variables_LUMI" {
    export CURRENT_ARCH="LUMI"
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/fix_constant_variables.sh" ${SCRATCH_DIR} ${HPC_PROJECT_ROOT} ${LOCAL_DIR} ${FDB_HOME} ${LIBDIR} ${DQC_PROFILE_PATH} ${EXPVER} ${EXPERIMENT} ${ACTIVITY} ${GENERATION} ${MEMBER} "${MEMBER_LIST}" ${MODEL} ${START_DATE} ${END_DATE} ${CHUNK} ${ROOTDIR} ${SCRIPTDIR} ${GSV_VERSION} ${CURRENT_ARCH} ${HPC_CONTAINER_DIR}
    assert_success
}
