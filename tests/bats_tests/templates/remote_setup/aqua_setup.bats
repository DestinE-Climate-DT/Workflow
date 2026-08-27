# Tests for templates/remote_setup/aqua_setup.sh

## setup

load_singularity() {
    echo 'Loading singularity'
    true
}

# mock the install_aqua function
install_aqua() {
    echo "Fake install_aqua function called"
    # so we can assert later that it was called
    touch "${HPCROOTDIR}/install_aqua_called.flag"
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
    # one level deeper than the other template tests: tests/bats_tests/templates/remote_setup
    PROJECT_DIR="${DIR}/../../../../"

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

    cat >>"${HPCROOTDIR}/proj/${PROJDEST}/lib/MARENOSTRUM5/config.sh" <<'EOF'

load_singularity() {
    true
}
EOF

    cat >>"${HPCROOTDIR}/proj/${PROJDEST}/lib/common/utils/remote_setup_utils.sh" <<EOF

install_aqua() {
    touch "${HPCROOTDIR}/install_aqua_called.flag"
}
EOF

    export CURRENT_ARCH="MARENOSTRUM5"
    export LIBDIR="${HPCROOTDIR}/proj/${PROJDEST}/lib"
    export HPC_CONTAINER_DIR="${HPCROOTDIR}/containers"
    export CONTAINER_VERSION="0.18.0"

    export SCRATCH_DIR="${HPCROOTDIR}/scratch"
    export HPC_PROJECT_ROOT="${HPCROOTDIR}/projects"
    export LOCAL_DIR="${HPCROOTDIR}/local"

    export AQUA_REGENCAT="False"
    export HPCARCH_short="MN5"
    export CATALOG_NAME="test-phase3"
    export EXPID="a000"
    export EXPVER="test"
    export MODEL="ifs-nemo"
    export DATA_PORTFOLIO="full"
    export SIM_START_DATE="19900101"
    export USER="testuser"
    export AQUA_CONFIG="${HPCROOTDIR}/.aqua"
    export AQUA_START_DATE=""
    export GRID_BUILD_ENABLED="False"
    export AQUA_GRID_ATM=""
    export MODEL_NAME_LOWER="ifs-nemo"
    export DQC_PROFILE="production"
    export GRID_OCE=""
    export RUN_LRA_GENERATOR="True"
    export PREV_AQUA_EXP=""
    export RESOLUTION="120km"
    export MODEL_NAME_UPPER="IFS-NEMO"
    export MEMBER_LIST="fc0"
    export EXPERIMENT_NAME="a000"
}

# Sets AQUA_SETUP_ARGS. An array, not an echo: several of these are legitimately
# empty and unquoted command substitution would drop them, shifting every
# following positional out of place.
set_aqua_setup_args() {
    AQUA_SETUP_ARGS=(
        "${CURRENT_ARCH}" "${LIBDIR}" "${AQUA_ON}" "${HPC_CONTAINER_DIR}" "${CONTAINER_VERSION}"
        "${SCRATCH_DIR}" "${HPC_PROJECT_ROOT}" "${LOCAL_DIR}" "${HPCROOTDIR}" "${AQUA_REGENCAT}"
        "${HPCARCH_short}" "${PROJDEST}" "${CATALOG_NAME}" "${EXPID}" "${EXPVER}" "${MODEL}"
        "${DATA_PORTFOLIO}" "${SIM_START_DATE}" "${USER}" "${AQUA_CONFIG}" "${AQUA_START_DATE}"
        "${GRID_BUILD_ENABLED}" "${AQUA_GRID_ATM}" "${MODEL_NAME_LOWER}" "${DQC_PROFILE}"
        "${GRID_OCE}" "${RUN_LRA_GENERATOR}" "${PREV_AQUA_EXP}" "${RESOLUTION}"
        "${MODEL_NAME_UPPER}" "${MEMBER_LIST}" "${EXPERIMENT_NAME}"
    )
}

@test "AQUA False" {
    AQUA_ON="False"
    set_aqua_setup_args
    run source "${HPCROOTDIR}/proj/${PROJDEST}/templates/remote_setup/aqua_setup.sh" "${AQUA_SETUP_ARGS[@]}"

    # should not have been called
    [ ! -f "${HPCROOTDIR}/install_aqua_called.flag" ]
    assert_success
}

@test "AQUA True" {
    AQUA_ON="True"
    set_aqua_setup_args
    run source "${HPCROOTDIR}/proj/${PROJDEST}/templates/remote_setup/aqua_setup.sh" "${AQUA_SETUP_ARGS[@]}"

    [ -f "${HPCROOTDIR}/install_aqua_called.flag" ]
    assert_success
}

@test "AQUA True extracts catalog tarball in AQUA_SETUP" {
    AQUA_ON="True"
    mkdir -p "${HPCROOTDIR}/catalog_bundle/catalog"
    touch "${HPCROOTDIR}/catalog_bundle/catalog/sentinel.yaml"
    tar -czf "${HPCROOTDIR}/catalog.tar.gz" -C "${HPCROOTDIR}/catalog_bundle" catalog
    rm -rf "${HPCROOTDIR}/catalog_bundle"

    set_aqua_setup_args
    run source "${HPCROOTDIR}/proj/${PROJDEST}/templates/remote_setup/aqua_setup.sh" "${AQUA_SETUP_ARGS[@]}"

    assert_success
    [ -f "${HPCROOTDIR}/catalog/sentinel.yaml" ]
}
