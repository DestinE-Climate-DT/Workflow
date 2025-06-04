# Tests for templates/transfer.sh

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

mock_gribfile() {
    mkdir -p "${ROOTDIR}/transfer_requests"
    dd if=/dev/zero of="${ROOTDIR}/transfer_requests/test_sdate_${SPLIT_START_DATE}_endate_${SECOND_TO_LAST_DATE}_real_${MEMBER}.grb" bs=1M count=1
}

mock_yamlfile_first_chunk() {
    mkdir -p ${FDB_INFO_FILE_PATH}
    touch ${FDB_INFO_FILE_NAME}
    cat <<EOF > ${FDB_INFO_FILE_NAME}
hpc:
  data_end_date: '19900311'
  data_start_date: '19900101'
  expver: a000
EOF
}

check_updated_yaml() {
    updated_param=$1
    updated_value=$2
    updated_yaml=$(cat ${FDB_INFO_FILE_NAME} | grep ${updated_param} | awk '{print $2}')
    [ "${updated_value}" == "${updated_yaml}" ]
}

mock_mars_bin() {
    mkdir -p "${FDB_HOME}/bin"
    touch "${FDB_HOME}/bin/mars"
    chmod +x "${FDB_HOME}/bin/mars"
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

    export CHUNK="1"
    export SPLIT_START_DATE="20000111"
    export SECOND_TO_LAST_DATE="20000112"
    export MODEL_NAME="icon"
    export EXPERIMENT="test"
    export ACTIVITY="test"
    export DQC_PROFILE_PATH="${ROOTDIR}/profiles"
    export FDB_HOME="${ROOTDIR}/proj/${PROJDEST}/fdb"
    export EXPVER="test"
    export SCRATCH_DIR="${ROOTDIR}/proj/${PROJDEST}/scratch"
    export HPC_CONTAINER_DIR="${ROOTDIR}/proj/${PROJDEST}/containers"
    export GSV_VERSION="1"
    export LIBDIR="${ROOTDIR}/proj/${PROJDEST}/lib"
    export MEMBER="1"
    export MEMBER_LIST="1 2 3"
    export GENERATION="1"
    export SCRIPTDIR="${ROOTDIR}/proj/${PROJDEST}/runscripts"
    export FDB_PROD="${ROOTDIR}/proj/${PROJDEST}/fdb_prod"
    export DATABRIDGE_FDB_HOME="${ROOTDIR}/proj/${PROJDEST}/databridge_fdb"
    export FDB_INFO_FILE_PATH="${ROOTDIR}/proj/${PROJDEST}"
    export FDB_INFO_FILE_NAME="${FDB_INFO_FILE_PATH}/a000.yaml"
    export SPLIT_FIRST="FALSE"
    export SPLIT_SECOND_TO_LAST_DATE="01022001"
    export SPLITS="31"
    export DAY_BEFORE="31012001"
    export CHUNK_LAST="FALSE"
    export EXPID="a000"
    export SIMULATION_START_DATE="20000101"
    export SPLIT_END_DATE="20000112"
    export DQC_PROFILE="lowres"
    export DATA_PORTFOLIO="production"
    export DQC_PROFILE_ROOT="${ROOTDIR}/profiles"
    export PROJECT="test"
    export USER="test"
    export CURRENT_ROOTDIR=${ROOTDIR}
    export MARS_BINARY="${FDB_HOME}/bin/mars"

    mock_profile
    mock_mars_bin
}

@test "load_transfer_template_not_working" {
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/transfer.sh" ${ROOTDIR} ${CURRENT_ARCH} ${CHUNK} ${SPLIT_START_DATE} ${SECOND_TO_LAST_DATE} ${MODEL_NAME} ${EXPERIMENT} ${ACTIVITY} ${DQC_PROFILE_PATH} ${FDB_HOME} ${EXPVER} ${SCRATCH_DIR} ${HPC_CONTAINER_DIR} ${GSV_VERSION} ${LIBDIR} ${MEMBER} "${MEMBER_LIST}" ${GENERATION} ${SCRIPTDIR} ${FDB_PROD} ${DATABRIDGE_FDB_HOME} ${FDB_INFO_FILE_PATH} ${FDB_INFO_FILE_NAME} ${SPLIT_FIRST} ${SPLIT_SECOND_TO_LAST_DATE} ${CHUNK_SECOND_TO_LAST_DATE} ${SPLITS} ${EXPID} ${SIMULATION_START_DATE} ${SPLIT_END_DATE}
    assert_failure
}

@test "load_transfer_template_working_lumi" {
    CURRENT_ARCH="LUMI"
    CONTAINER_COMMAND="singularity"
    DATABRIDGE_DATABASE="databridge-fdb"
    mock_gribfile
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/transfer.sh" ${ROOTDIR} ${CURRENT_ARCH} ${CHUNK} ${SPLIT_START_DATE} ${SECOND_TO_LAST_DATE} ${MODEL_NAME} ${EXPERIMENT} ${ACTIVITY} ${DQC_PROFILE_PATH} ${FDB_HOME} ${EXPVER} ${SCRATCH_DIR} ${HPC_CONTAINER_DIR} ${GSV_VERSION} ${LIBDIR} ${MEMBER} "${MEMBER_LIST}" ${GENERATION} ${SCRIPTDIR} ${FDB_PROD} ${DATABRIDGE_FDB_HOME} ${FDB_INFO_FILE_PATH} ${FDB_INFO_FILE_NAME} ${SPLIT_FIRST} ${SPLIT_SECOND_TO_LAST_DATE} ${CHUNK_SECOND_TO_LAST_DATE} ${SPLITS} ${EXPID} ${SIMULATION_START_DATE} ${SPLIT_END_DATE} ${CONTAINER_COMMAND} ${DQC_PROFILE} ${DATA_PORTFOLIO} ${DQC_PROFILE_ROOT} ${PROJECT} ${USER} ${CURRENT_ROOTDIR} ${MARS_BINARY} ${PROJDEST} ${DATABRIDGE_DATABASE}
    assert_success
}

@test "load_transfer_template_working_MN5_transfer" {
    CURRENT_ARCH="MARENOSTRUM5-TRANSFER"
    CONTAINER_COMMAND="/home/datamover/apptainer-install-dir/bin/apptainer"
    DATABRIDGE_DATABASE="databridge"
    mock_gribfile
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/transfer.sh" ${ROOTDIR} ${CURRENT_ARCH} ${CHUNK} ${SPLIT_START_DATE} ${SECOND_TO_LAST_DATE} ${MODEL_NAME} ${EXPERIMENT} ${ACTIVITY} ${DQC_PROFILE_PATH} ${FDB_HOME} ${EXPVER} ${SCRATCH_DIR} ${HPC_CONTAINER_DIR} ${GSV_VERSION} ${LIBDIR} ${MEMBER} "${MEMBER_LIST}" ${GENERATION} ${SCRIPTDIR} ${FDB_PROD} ${DATABRIDGE_FDB_HOME} ${FDB_INFO_FILE_PATH} ${FDB_INFO_FILE_NAME} ${SPLIT_FIRST} ${SPLIT_SECOND_TO_LAST_DATE} ${SPLITS} ${EXPID} ${SIMULATION_START_DATE} ${SPLIT_END_DATE} ${CONTAINER_COMMAND} ${DQC_PROFILE} ${DATA_PORTFOLIO} ${DQC_PROFILE_ROOT} ${PROJECT} ${USER} ${CURRENT_ROOTDIR} ${MARS_BINARY} ${PROJDEST} ${DATABRIDGE_DATABASE}
    assert_success
}

# Container doesn't have python!
# @test "load_transfer_update_file_first_chunk" {
#     mock_gribfile
#     mock_yamlfile_first_chunk
#     export CHUNK="1"
#     export "SPLIT_FIRST"="TRUE"
#     run source "${ROOTDIR}/proj/${PROJDEST}/templates/transfer.sh" ${ROOTDIR} ${CURRENT_ARCH} ${CHUNK} ${START_DATE} ${SECOND_TO_LAST_DATE} ${MODEL_NAME} ${EXPERIMENT} ${ACTIVITY} ${DQC_PROFILE_PATH} ${FDB_HOME} ${EXPVER} ${SCRATCH_DIR} ${HPC_CONTAINER_DIR} ${GSV_VERSION} ${LIBDIR} ${MEMBER} "${MEMBER_LIST}" ${GENERATION} ${SCRIPTDIR} ${FDB_PROD} ${DATABRIDGE_FDB_HOME} ${FDB_INFO_FILE_PATH} ${FDB_INFO_FILE_NAME} ${SPLIT_FIRST} ${SPLIT_SECOND_TO_LAST_DATE} ${SPLITS} ${DAY_BEFORE} ${CHUNK_LAST} ${EXPID}
#     cat ${FDB_INFO_FILE_NAME}
#     check_updated_yaml "bridge_start_date" "${START_DATE}"
#     assert_success
# }
