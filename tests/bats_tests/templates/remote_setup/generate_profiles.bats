# Tests for templates/remote_setup/generate_profiles.sh

## setup

load_singularity() {
    echo 'Loading singularity'
    true
}

# mock the install_aqua function
generate_profiles() {
    CURRENT_ROOTDIR="${BATS_TMPDIR}/"
    echo "Fake generate_profiles function called"
    # so we can assert later that it was called
    touch "${CURRENT_ROOTDIR}/generate_profiles_called.flag"
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

    export CURRENT_ROOTDIR="${BATS_TMPDIR}/"
    export PROJDEST="test/bat"

    # Copy the workflow project into ${BATS_TMPDIR}/proj/workflow,
    # imitating what `autosubmit create|refresh` do -- as this is
    # expected by the `local_setup.sh` template script.
    mkdir -pv "${CURRENT_ROOTDIR}/proj/${PROJDEST}"
    mkdir -p "${CURRENT_ROOTDIR}/LOG_a000"

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
    eval "tar ${tar_exclude} -cf - ." | (cd "${CURRENT_ROOTDIR}/proj/${PROJDEST}"; tar xvf -)
    popd

    # fake it or the real generate_profiles will be called
    export LIBDIR="fake_lib_dir"
    export CURRENT_ARCH="MARENOSTRUM5"

    export SCRATCH_DIR="${CURRENT_ROOTDIR}/scratch"
    export HPC_PROJECT_ROOT="${CURRENT_ROOTDIR}/projects"
    export LOCAL_DIR="${CURRENT_ROOTDIR}/local"

    export DQC_PROFILE_ROOT="${CURRENT_ROOTDIR}/DQCPROFILE"
    export CONTAINER_COMMAND="singularity"
    export DATA_PORTFOLIO="full"
    export DQC_PROFILE="lowres"
    export HPC_CONTAINER_DIR="${CURRENT_ROOTDIR}/containers"
    export GSV_VERSION="1.3.2"
}

@test "MODEL_NAME is nemo" {
    MODEL_NAME="nemo"
    run source "${CURRENT_ROOTDIR}/proj/${PROJDEST}/templates/remote_setup/generate_profiles.sh" ${LIBDIR} ${CURRENT_ARCH} ${MODEL_NAME} ${SCRATCH_DIR} ${HPC_PROJECT_ROOT} ${LOCAL_DIR} ${CURRENT_ROOTDIR} ${PROJDEST} ${DQC_PROFILE_ROOT} ${CONTAINER_COMMAND} ${DATA_PORTFOLIO} ${DQC_PROFILE} ${HPC_CONTAINER_DIR} ${GSV_VERSION}

    # should not have been called
    [ ! -f "${CURRENT_ROOTDIR}/generate_profiles_called.flag" ]
    assert_success
}

@test "GENERATE_PROFILES True" {
    MODEL_NAME="ifs-nemo"
    run source "${CURRENT_ROOTDIR}/proj/${PROJDEST}/templates/remote_setup/generate_profiles.sh" ${LIBDIR} ${CURRENT_ARCH} ${MODEL_NAME} ${SCRATCH_DIR} ${HPC_PROJECT_ROOT} ${LOCAL_DIR} ${CURRENT_ROOTDIR} ${PROJDEST} ${DQC_PROFILE_ROOT} ${CONTAINER_COMMAND} ${DATA_PORTFOLIO} ${DQC_PROFILE} ${HPC_CONTAINER_DIR} ${GSV_VERSION}

    [ -f "${CURRENT_ROOTDIR}/generate_profiles_called.flag" ]
    assert_success
}
