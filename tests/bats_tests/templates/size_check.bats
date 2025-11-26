# Tests for templates/transfer.sh

## setup

git() {
    echo 'Running git'
    true
}

setup_fdb() {
    mkdir -p "${FDB_HOME}/etc/fdb"
    cat > "${FDB_HOME}/etc/fdb/config.yaml" <<EOF
---
type: select
fdbs:
- select: class=d1,dataset=climate-dt
  type: local
  engine: toc
  schema: ~fdb/etc/fdb/schema
  spaces:
  - handler: Default
    roots:
    - path: ${ROOTDIR}/scratch/fdb/root
EOF
}

mock_fdb() {
    local DATE=$1
    mkdir -p "${ROOTDIR}/scratch/fdb/root/${CLASS}:${DATASET}:${ACTIVITY}:${EXPERIMENT}:${GENERATION}:${MODEL}:${REALIZATION}:${EXPVER}:${STREAM}:${DATE}"
    echo "dummpy-data" > "${ROOTDIR}/scratch/fdb/root/${CLASS}:${DATASET}:${ACTIVITY}:${EXPERIMENT}:${GENERATION}:${MODEL}:${REALIZATION}:${EXPVER}:${STREAM}:${DATE}/dummy_file.txt"
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

    export CLASS="d1"
    export DATASET="climate-dt"
    export ACTIVITY="baseline"
    export EXPERIMENT="cont"
    export GENERATION="1"
    export MODEL="model"
    export REALIZATION="2"
    export EXPVER="a000"
    export STREAM="clte"
    export START_DATE="20230101"
    export END_DATE="20230102"
    export FDB_HOME="${ROOTDIR}/scratch/fdb"
    export HPCROOTDIR="${ROOTDIR}/proj/${PROJDEST}"

}

@test "load_template_empty_fdb" {
    setup_fdb
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/performance/check_size.sh" "${CLASS}" "${DATASET}" "${ACTIVITY}" "${EXPERIMENT}" "${GENERATION}" "${MODEL}" "${REALIZATION}" "${EXPVER}" "${STREAM}" "${START_DATE}" "${END_DATE}" "${FDB_HOME}" "${HPCROOTDIR}"
    assert_failure
}

@test "load_template_with_mocked_pdfs" {
    setup_fdb
    current_date="$START_DATE"
    while [[ "$current_date" -le "$END_DATE" ]]; do
        mock_fdb ${current_date}
        current_date=$(date -I -d "$current_date + 1 day" | tr -d '-')
    done
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/performance/check_size.sh" "${CLASS}" "${DATASET}" "${ACTIVITY}" "${EXPERIMENT}" "${GENERATION}" "${MODEL}" "${REALIZATION}" "${EXPVER}" "${STREAM}" "${START_DATE}" "${END_DATE}" "${FDB_HOME}" "${HPCROOTDIR}"
    assert_success
}
