# Tests for templates/transfer.sh

## setup

rsync() {
    echo 'Mock rsync called'
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

    export ROOTDIR="${BATS_TMPDIR}/"
    export PROJDEST="test/bat"
    export DEFAULT_HPCARCH="MARENOSTRUM5"

    # Copy the workflow project into ${BATS_TMPDIR}/proj/workflow,
    # imitating what `autosubmit create|refresh` do -- as this is
    # expected by the `local_setup.sh` template script.
    mkdir -pv "${ROOTDIR}/proj/${PROJDEST}/lib/${DEFAULT_HPCARCH}"
    source "lib/MARENOSTRUM5/config.sh"

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

    export HPCROOTDIR="/hpcrootdir"
    export HPCUSER="hpcuser"
    export HPCHOST="hpchost"
    export DEFAULT_HPCARCH="MARENOSTRUM5"
    export SCRATCH_DIR="/scratch"
    export TRANSFER_USER="transferuser"
    export TRANSFER_HOST="transferhost"
    export TRANSFER_SCRATCH="/transferscratch"
    export TRANSFER_PROJECT="transferproject"
    export EXPID="a000"

    export TRANSFER_ON="false"
    export AQUA_ON="False"

}

@test "rsync .tar.gz and create flag on first run" {
    mkdir -p "${ROOTDIR}/proj/${PROJDEST}"
    touch "${ROOTDIR}/proj/${PROJDEST}/sentinel"
    tar -czf "${ROOTDIR}/proj/${PROJDEST}.tar.gz" -C "${ROOTDIR}/proj" "${PROJDEST}"

    run source "${ROOTDIR}/proj/${PROJDEST}/templates/synchronize.sh" \
        ${HPCROOTDIR} ${ROOTDIR} ${HPCUSER} ${HPCHOST} ${PROJDEST} ${DEFAULT_HPCARCH} \
        ${SCRATCH_DIR} ${TRANSFER_USER} ${TRANSFER_HOST} ${TRANSFER_SCRATCH} ${TRANSFER_PROJECT} ${EXPID} ${TRANSFER_ON} ${AQUA_ON}

    assert_success
    assert_output --partial "Sending the tarball to the remote platform"
    [ -f "${ROOTDIR}/flag_tarball_sent" ]
}

@test "rsync directory when tarball already sent" {
    touch "${ROOTDIR}/flag_tarball_sent"
    mkdir -p "${ROOTDIR}/proj/${PROJDEST}"

    run source "${ROOTDIR}/proj/${PROJDEST}/templates/synchronize.sh" \
        ${HPCROOTDIR} ${ROOTDIR} ${HPCUSER} ${HPCHOST} ${PROJDEST} ${DEFAULT_HPCARCH} \
        ${SCRATCH_DIR} ${TRANSFER_USER} ${TRANSFER_HOST} ${TRANSFER_SCRATCH} ${TRANSFER_PROJECT} ${EXPID} ${TRANSFER_ON} ${AQUA_ON}

    assert_success
    assert_output --partial "The tarball was already sent, skipping tarball sending step. Only rsyncing the project directory"
}

@test "skip transfer step when TRANSFER_ON is false" {
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/synchronize.sh" \
        ${HPCROOTDIR} ${ROOTDIR} ${HPCUSER} ${HPCHOST} ${PROJDEST} ${DEFAULT_HPCARCH} \
        ${SCRATCH_DIR} ${TRANSFER_USER} ${TRANSFER_HOST} ${TRANSFER_SCRATCH} ${TRANSFER_PROJECT} ${EXPID} ${TRANSFER_ON} ${AQUA_ON}

    assert_output --partial "Transfer is disabled, skipping synchronize step"
}

@test "rsync catalog tarball when AQUA is enabled" {
    export AQUA_ON="True"
    rm -f "${ROOTDIR}/flag_tarball_sent"
    mkdir -p "${ROOTDIR}/proj/${PROJDEST}" "${ROOTDIR}/tmp/catalog"
    touch "${ROOTDIR}/proj/${PROJDEST}/sentinel" "${ROOTDIR}/tmp/catalog/entry.yaml"
    tar -czf "${ROOTDIR}/proj/${PROJDEST}.tar.gz" -C "${ROOTDIR}/proj" "${PROJDEST}"
    tar -czf "${ROOTDIR}/tmp/catalog.tar.gz" -C "${ROOTDIR}/tmp" "catalog"

    run source "${ROOTDIR}/proj/${PROJDEST}/templates/synchronize.sh" \
        ${HPCROOTDIR} ${ROOTDIR} ${HPCUSER} ${HPCHOST} ${PROJDEST} ${DEFAULT_HPCARCH} \
        ${SCRATCH_DIR} ${TRANSFER_USER} ${TRANSFER_HOST} ${TRANSFER_SCRATCH} ${TRANSFER_PROJECT} ${EXPID} ${TRANSFER_ON} ${AQUA_ON}

    assert_success
    [ ! -f "${ROOTDIR}/tmp/catalog.tar.gz" ]
    [ -f "${ROOTDIR}/flag_tarball_sent" ]
}

@test "transfer to datamover when TRANSFER_ON is true" {
    export TRANSFER_ON="true"
    touch "${ROOTDIR}/flag_tarball_sent"
    mkdir -p "${ROOTDIR}/proj/${PROJDEST}"

    run source "${ROOTDIR}/proj/${PROJDEST}/templates/synchronize.sh" \
        ${HPCROOTDIR} ${ROOTDIR} ${HPCUSER} ${HPCHOST} ${PROJDEST} ${DEFAULT_HPCARCH} \
        ${SCRATCH_DIR} ${TRANSFER_USER} ${TRANSFER_HOST} ${TRANSFER_SCRATCH} ${TRANSFER_PROJECT} ${EXPID} ${TRANSFER_ON} ${AQUA_ON}

    assert_success
    assert_output --partial "Syncing the project to the remote platform"
    assert_output --partial "Mock rsync called"
}
