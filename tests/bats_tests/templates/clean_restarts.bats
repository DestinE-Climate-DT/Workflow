# Tests for templates/clean_restarts.sh

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

    export CURRENT_ARCH="arch"
    export EXPID="expid"
    export HPC_PROJECT="project_dir"
    export HPCROOTDIR="${ROOTDIR}"
    export KEEP_EVERY=12
    export KEEP_LAST=3
    export START_DATE="19900101"
    export MEMBER="fc0"
    export LIBDIR="${ROOTDIR}/proj/${PROJDEST}/lib"

    RESTART_DIR="${ROOTDIR}/restarts/${START_DATE}/${MEMBER}"
    mkdir -p "$RESTART_DIR"

    RESTART_BACKUP_PATH="${ROOTDIR}/restart_backups/${START_DATE}/${MEMBER}"
    mkdir -p "$RESTART_BACKUP_PATH"

}

@test "clean_restarts 1 chunk" {
    export CHUNK=1
    mkdir -p "$RESTART_DIR/1"
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/clean_restarts.sh" ${HPC_PROJECT} ${HPCROOTDIR} ${EXPID} ${CURRENT_ARCH} ${CHUNK} ${KEEP_EVERY} ${KEEP_LAST} ${START_DATE} ${MEMBER} ${LIBDIR}
    assert_success "Not enough restarts to delete anything."
}

@test "clean_restarts 5 chunks" {
    export CHUNK=1
    RESTARTS="1 2 3 4 5"

    for dir in $RESTARTS; do
        mkdir -p "$RESTART_DIR/$dir"
    done

    run source "${ROOTDIR}/proj/${PROJDEST}/templates/clean_restarts.sh" ${HPC_PROJECT} ${HPCROOTDIR} ${EXPID} ${CURRENT_ARCH} ${CHUNK} ${KEEP_EVERY} ${KEEP_LAST} ${START_DATE} ${MEMBER} ${LIBDIR}
    assert_output --partial "Deleting restart ${RESTART_DIR}/2."

    rm -rf "${RESTART_DIR}"
    rm -rf "${RESTART_BACKUP_PATH}"
}
