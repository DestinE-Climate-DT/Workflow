# Tests for templates/clean.sh

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

compress_rundir() {
    echo "compressing rundir"
    # so we can assert later that it was called
    touch "/${BATS_TMPDIR}/compress_rundir_called.flag"
    true
}

compress_logs() {
    echo "compressing logs"
    # so we can assert later that it was called
    touch "/${BATS_TMPDIR}/compress_logs_called.flag"
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

    export ROOTDIR="${BATS_TMPDIR}/"
    export PROJDEST="test/bat"

    # Copy the workflow project into ${BATS_TMPDIR}/proj/workflow,
    # imitating what `autosubmit create|refresh` do -- as this is
    # expected by the `local_setup.sh` template script.
    HPCROOTDIR="${ROOTDIR}/proj/${PROJDEST}"
    mkdir -pv "${HPCROOTDIR}"

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
    eval "tar ${tar_exclude} -cf - ." | (cd "${HPCROOTDIR}"; tar xvf -)
    popd

    export CURRENT_ARCH="LUMI"
    export CHUNK="1"
    export START_DATE="01012000"
    export SECOND_TO_LAST_DATE="01012001"
    export MODEL_NAME="icon"
    export EXPERIMENT="test"
    export ACTIVITY="test"
    export GENERATION="2"
    export DQC_PROFILE_PATH="${ROOTDIR}/profiles"
    export FDB_HOME="${ROOTDIR}/proj/${PROJDEST}/fdb"
    export EXPVER="test"
    export SCRATCH_DIR="${ROOTDIR}/proj/${PROJDEST}/scratch"
    export HPC_CONTAINER_DIR="${ROOTDIR}/proj/${PROJDEST}/containers"
    export LIBDIR="${ROOTDIR}/proj/${PROJDEST}/lib"
    export SCRIPTDIR="${ROOTDIR}/proj/${PROJDEST}/runscripts"
    export LOCAL_DIR="${ROOTDIR}/proj/${PROJDEST}/local"
    export MEMBER="fc0"
    export MEMBER_LIST="fc0 fc1 fc2 fc3 fc4 fc5 fc6 fc7 fc8 fc9"
    export HPC_PROJECT="test_project"
    export EXPID="test_expid"
    export CLEAN_JOBNAME="clean_job"
    export CHUNK_START_DATE="01012000"
    export CHUNK_END_IN_DAYS="365"
    export CHUNKSIZE="1"
    export CHUNKSIZEUNIT="days"
    export CHUNK_SECOND_TO_LAST_DATE="31122000"
    export REALIZATION="1"
    export GSV_VERSION="1.0"

    mock_profile
    # prevent our mock functions for the test from being overwritten by the real ones
    readonly -f compress_rundir compress_logs singularity
}

@test "load_template_clean" {
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/clean.sh" ${HPC_PROJECT} ${EXPID} ${HPCROOTDIR} ${START_DATE} ${CURRENT_ARCH} ${FDB_HOME} ${CLEAN_JOBNAME} ${CHUNK_START_DATE} ${CHUNK_END_IN_DAYS} ${CHUNKSIZE} ${CHUNKSIZEUNIT} ${CHUNK} ${MODEL_NAME} ${CHUNK_SECOND_TO_LAST_DATE} ${EXPERIMENT} ${ACTIVITY} ${EXPVER} ${GENERATION} ${SCRATCH_DIR} ${HPC_CONTAINER_DIR} ${GSV_VERSION} ${LIBDIR} ${SCRIPTDIR}
    assert_success
}

@test "dont_compress_rundir_or_logs" {
    TAR_RUNDIR="False"
    TAR_LOGS="False"
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/clean.sh" ${HPC_PROJECT} ${EXPID} ${HPCROOTDIR} ${START_DATE} ${CURRENT_ARCH} ${FDB_HOME} ${CLEAN_JOBNAME} ${CHUNK_START_DATE} ${CHUNK_END_IN_DAYS} ${CHUNKSIZE} ${CHUNKSIZEUNIT} ${CHUNK} ${MODEL_NAME} ${CHUNK_SECOND_TO_LAST_DATE} ${EXPERIMENT} ${ACTIVITY} ${EXPVER} ${GENERATION} ${SCRATCH_DIR} ${HPC_CONTAINER_DIR} ${GSV_VERSION} ${LIBDIR} ${SCRIPTDIR} ${MEMBER} "${MEMBER_LIST}" ${ROOTDIR} ${LOCAL_DIR} "${TAR_RUNDIR}" "${TAR_LOGS}"
    [ ! -f "/${BATS_TMPDIR}/compress_rundir_called.flag" ]
    [ ! -f "/${BATS_TMPDIR}/compress_logs_called.flag" ]
    assert_success
}

@test "only_compress_rundir_not_logs" {
    TAR_RUNDIR="True"
    TAR_LOGS="False"
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/clean.sh" ${HPC_PROJECT} ${EXPID} ${HPCROOTDIR} ${START_DATE} ${CURRENT_ARCH} ${FDB_HOME} ${CLEAN_JOBNAME} ${CHUNK_START_DATE} ${CHUNK_END_IN_DAYS} ${CHUNKSIZE} ${CHUNKSIZEUNIT} ${CHUNK} ${MODEL_NAME} ${CHUNK_SECOND_TO_LAST_DATE} ${EXPERIMENT} ${ACTIVITY} ${EXPVER} ${GENERATION} ${SCRATCH_DIR} ${HPC_CONTAINER_DIR} ${GSV_VERSION} ${LIBDIR} ${SCRIPTDIR} ${MEMBER} "${MEMBER_LIST}" ${ROOTDIR} ${LOCAL_DIR} "${TAR_RUNDIR}" "${TAR_LOGS}"

    [ -f "/${BATS_TMPDIR}/compress_rundir_called.flag" ]
    [ ! -f "/${BATS_TMPDIR}/compress_logs_called.flag" ]
    assert_success

    # remove flag to reset for next test
    rm "/${BATS_TMPDIR}/compress_rundir_called.flag"
}

@test "only_compress_logs_not_rundir" {
    TAR_RUNDIR="False"
    TAR_LOGS="True"
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/clean.sh" ${HPC_PROJECT} ${EXPID} ${HPCROOTDIR} ${START_DATE} ${CURRENT_ARCH} ${FDB_HOME} ${CLEAN_JOBNAME} ${CHUNK_START_DATE} ${CHUNK_END_IN_DAYS} ${CHUNKSIZE} ${CHUNKSIZEUNIT} ${CHUNK} ${MODEL_NAME} ${CHUNK_SECOND_TO_LAST_DATE} ${EXPERIMENT} ${ACTIVITY} ${EXPVER} ${GENERATION} ${SCRATCH_DIR} ${HPC_CONTAINER_DIR} ${GSV_VERSION} ${LIBDIR} ${SCRIPTDIR} ${MEMBER} "${MEMBER_LIST}" ${ROOTDIR} ${LOCAL_DIR} "${TAR_RUNDIR}" "${TAR_LOGS}"

    [ ! -f "/${BATS_TMPDIR}/compress_rundir_called.flag" ]
    [ -f "/${BATS_TMPDIR}/compress_logs_called.flag" ]
    assert_success

    # remove flag to reset for next test
    rm "/${BATS_TMPDIR}/compress_logs_called.flag"
}

@test "compress_rundir_and_logs" {
    TAR_RUNDIR="True"
    TAR_LOGS="True"
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/clean.sh" ${HPC_PROJECT} ${EXPID} ${HPCROOTDIR} ${START_DATE} ${CURRENT_ARCH} ${FDB_HOME} ${CLEAN_JOBNAME} ${CHUNK_START_DATE} ${CHUNK_END_IN_DAYS} ${CHUNKSIZE} ${CHUNKSIZEUNIT} ${CHUNK} ${MODEL_NAME} ${CHUNK_SECOND_TO_LAST_DATE} ${EXPERIMENT} ${ACTIVITY} ${EXPVER} ${GENERATION} ${SCRATCH_DIR} ${HPC_CONTAINER_DIR} ${GSV_VERSION} ${LIBDIR} ${SCRIPTDIR} ${MEMBER} "${MEMBER_LIST}" ${ROOTDIR} ${LOCAL_DIR} "${TAR_RUNDIR}" "${TAR_LOGS}"
    [ -f "/${BATS_TMPDIR}/compress_rundir_called.flag" ]
    [ -f "/${BATS_TMPDIR}/compress_logs_called.flag" ]
    assert_success
}
