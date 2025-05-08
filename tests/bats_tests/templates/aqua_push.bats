# Tests for templates/transfer.sh

## setup

load_singularity() {
    echo 'Loading singularity'
    true
}

git() {
    echo 'Running git'
    true
}

aqua() {
    echo 'Running aqua command $1 with arguments $2'
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
    local tar_exclude_submodules="--exclude=dvc-cache-de340 --exclude=ifs-nemo--exclude=catalog --exclude=data-portfolio --exclude=nemo"
    # TODO: Use exclude-vcs when we upgrade the tar version used in Docker
    #       local tar_exclude="--exclude-vcs --exclude-vcs-ignores ${tar_exclude_submodules}"
    local tar_exclude="--exclude=.git --exclude=docs/build ${tar_exclude_submodules}"
    eval "tar ${tar_exclude} -cf - ." | (cd "${ROOTDIR}/proj/${PROJDEST}"; tar xvf -)
    popd

    export HPCROOTDIR="${ROOTDIR}"
    export HPCUSER="testuser"
    export HPCHOST="testhost"
    export MODEL="testmodel"
    export EXPVER="testexpver"
    export APP_OUTPATH="${ROOTDIR}/proj/${PROJDEST}/testappoutpath"
    export HPCARCH="testhpcarch"
    export CATALOG_NAME="testcatalogname"
    export BUCKET="testbucket"

}

@test "load_template" {
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/aqua/aqua_push.sh" "${HPCROOTDIR}" "${ROOTDIR}" "${HPCUSER}" "${HPCHOST}" "${PROJDEST}" "${MODEL}" "${EXPVER}" "${APP_OUTPATH}" "${HPCARCH}" "${CATALOG_NAME}" "${BUCKET}"
    assert_success
}
