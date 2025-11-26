# Tests for templates/dqc.sh

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

    export MODEL="ifs-nemo"
    export CURRENT_ARCH="LUMI"
    export CHUNK_START_DATE="20210101"
    export CHUNK_SECOND_TO_LAST_DATE="20210102"
    export FDB_HOME="${ROOTDIR}/fdb"
    export MEMBER="1"
    export MEMBER_LIST="1 2 3"
    export CHECK_STANDARD_COMPLIANCE="True"
    export CHECK_SPATIAL_COMPLETENESS="True"
    export CHECK_SPATIAL_CONSISTENCY="True"
    export CHECK_PHYSICAL_PLAUSIBILITY="True"
    export EXPERIMENT="cont"
    export ACTIVITY="baseline"
    export DQC_PROFILE_PATH="${ROOTDIR}/dqc_profile"
    export EXPVER="a123"
    export CLASS="d1"
    export GENERATION="2"
    export HPC_CONTAINER_DIR="${ROOTDIR}/containers"
    export GSV_VERSION="v1.0.0"
    export LIBDIR="${ROOTDIR}/lib"
    export SCRIPTDIR="${ROOTDIR}/runscripts"
    export HPC_SCRATCH="${ROOTDIR}/scratch"
    export FDB_INFO_FILE_PATH="${ROOTDIR}"
    export FDB_INFO_FILE_NAME="${ROOTDIR}/info_file"
    export CHUNK_END_DATE="20210103"
    export BASE_VERSION="latest"
    export JOBNAME="a000_19900101_fc0_1_DQC"

    export SLURM_JOB_ID=123456
    export SLURM_JOB_CPUS_PER_NODE=4

    mock_profile
}

@test "load_template_dqc" {
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/dqc.sh" ${ROOTDIR} ${MODEL} ${CURRENT_ARCH} ${CHUNK_START_DATE} ${CHUNK_SECOND_TO_LAST_DATE} ${FDB_HOME} ${MEMBER} ${MEMBER_LIST} ${CHECK_STANDARD_COMPLIANCE} ${CHECK_SPATIAL_COMPLETENESS} ${CHECK_SPATIAL_CONSISTENCY} ${CHECK_PHYSICAL_PLAUSIBILITY} ${EXPERIMENT} ${ACTIVITY} ${DQC_PROFILE_PATH} ${EXPVER} ${CLASS} ${GENERATION} ${HPC_CONTAINER_DIR} ${GSV_VERSION} ${LIBDIR} ${SCRIPTDIR} ${HPC_SCRATCH} ${FDB_INFO_FILE_PATH} ${FDB_INFO_FILE_NAME} ${CHUNK_END_DATE} ${BASE_VERSION} ${JOBNAME}
    assert_success
}
