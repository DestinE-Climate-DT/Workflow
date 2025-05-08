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

convert_AS_variables_to_parameters() {
    var=$1
    path_to_template=$2
    # substitute VAR1=%whatever% with VAR1=${VAR1}
    sed -i "s/${var}=%[^%]*%/${var}=\${${var}}/g" ${path_to_template}
}

convert_AS_variables_to_bash () {
    var=$1
    value=$2
    path_to_template=$3
    # substitute VAR1=%whatever% with VAR1=${value}
    sed -i "s/\%${var}%/${value}/g" ${path_to_template}
}

export_slurm_vars() {
    export SLURM_JOB_NAME="test"
    export SLURM_JOB_ID="123"
    export SLURM_JOB_NUM_NODES="1"
    export SLURM_NPROCS="1"
    export SLURM_CPUS_PER_TASK="1"
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

    export CHUNKSIZE="1"
    export CHUNKSIZEUNIT="unit"
    export MODEL_NAME="ifs-nemo"
    export ENVIRONMENT="env"
    export HPCARCH="arch"
    export MODEL_VERSION="1.0"
    export OCEAN_GRID="eOrca1"
    export EXPID="expid"
    export ATM_GRID="tco79l137"
    export CHUNK="1"
    export TOTAL_RETRIALS="3"
    export ICMCL="pattern"
    export START_DATE="01012000"
    export END_DATE="01012001"
    export END_IN_DAYS="365"
    export PREV="365"
    export RUN_DAYS="30"
    export IFS_IO_TASKS="tasks"
    export NEMO_IO_TASKS="tasks"
    export HPC_PROJECT="project_dir"
    export MULTIO_ATM_PLANS="plans"
    export MULTIO_OCEAN_PLANS="plans"
    export PU="cpu"
    export RAPS_USER_FLAGS="flags"
    export RAPS_EXPERIMENT="experiment"
    export RUN_TYPE="production"
    export IFS_IO_PPN="ppn"
    export NEMO_IO_PPN="ppn"
    export IFS_IO_NODES="nodes"
    export NEMO_IO_NODES="nodes"
    export MEMBER="1"
    export MEMBER_LIST="1 2 3 4 5 6 7 8 9 10"
    export WORKFLOW="model"
    export SPLITS="10"
    export EXPVER="test"
    export CLASS="d1"
    export FDB_HOME="${ROOTDIR}/proj/${PROJDEST}/fdb"
    export DQC_PROFILE_PATH="${ROOTDIR}/profiles"
    export EXPERIMENT="test"
    export ACTIVITY="test"
    export GENERATION="2"
    export MODEL="ifs-nemo"
    export IO_ON="true"
    export LIBDIR="${ROOTDIR}/proj/${PROJDEST}/lib"
    export SCRATCH_DIR="${ROOTDIR}/proj/${PROJDEST}/scratch"
    export HPC_CONTAINER_DIR="${ROOTDIR}/proj/${PROJDEST}/containers"
    export GSV_VERSION="1"
    export MODEL_ROOT_PATH="root_path"
    export MODEL_PATH="path"
    export MODEL_INPUTS="inputs"
    export SCRIPTDIR="${ROOTDIR}/proj/${PROJDEST}/runscripts"
    export RAPS_HOST_CPU="cpu"
    export RAPS_HOST_GPU="gpu"
    export RAPS_BIN_HPC_NAME="hpc_name"
    export RAPS_COMPILER="compiler"
    export RAPS_MPILIB="mpilib"
    export MODULES_PROFILE_PATH="modules_profile_path"

    export LD_LIBRARY_PATH="${ROOTDIR}/path"

    convert_AS_variables_to_bash input_expver "${EXPVER}" "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh"
    convert_AS_variables_to_bash label "hz9m" "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh"
    convert_AS_variables_to_bash gtype "gtype" "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh"
    convert_AS_variables_to_bash resol "tco123" "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh"
    convert_AS_variables_to_bash levels "137" "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh"
    convert_AS_variables_to_bash SDATE "20001101" "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh"
    convert_AS_variables_to_bash runlength "123" "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh"
    convert_AS_variables_to_bash SDATE_LONG "20000101000000" "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh"
    convert_AS_variables_to_bash CHUNK_END_IN_DAYS "123" "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh"

    mock_profile
}

@test "load_template_sim_ifs-nemo_lumi" {
    export CURRENT_ARCH="LUMI"
    export HPCROOTDIR="${ROOTDIR}"
    export PROJDEST="${PROJDEST}"
    export_slurm_vars
    convert_AS_variables_to_parameters "HPCROOTDIR" "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh"
    convert_AS_variables_to_parameters "PROJDEST" "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh"
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh" ${HPCROOTDIR} ${PROJDEST} ${CURRENT_ARCH} ${CHUNKSIZE} ${CHUNKSIZEUNIT} ${MODEL_NAME} ${ENVIRONMENT} ${HPCARCH} ${MODEL_VERSION} ${OCEAN_GRID} ${EXPID} ${ATM_GRID} ${CHUNK} ${TOTAL_RETRIALS} ${ICMCL} ${START_DATE} ${END_DATE} ${END_IN_DAYS} ${PREV} ${RUN_DAYS} ${IFS_IO_TASKS} ${NEMO_IO_TASKS} ${HPC_PROJECT} ${MULTIO_ATM_PLANS} ${MULTIO_OCEAN_PLANS} ${PU} ${RAPS_USER_FLAGS} ${RAPS_EXPERIMENT} ${RUN_TYPE} ${IFS_IO_PPN} ${NEMO_IO_PPN} ${IFS_IO_NODES} ${NEMO_IO_NODES} ${MEMBER} "${MEMBER_LIST}" ${WORKFLOW} ${SPLITS} ${EXPVER} ${CLASS} ${FDB_HOME} ${DQC_PROFILE_PATH} ${EXPERIMENT} ${ACTIVITY} ${GENERATION} ${MODEL} ${IO_ON} ${LIBDIR} ${SCRATCH_DIR} ${HPC_CONTAINER_DIR} ${GSV_VERSION} ${MODEL_ROOT_PATH} ${MODEL_PATH} ${MODEL_INPUTS} ${SCRIPTDIR} ${RAPS_HOST_CPU} ${RAPS_HOST_GPU} ${RAPS_BIN_HPC_NAME} ${RAPS_COMPILER} ${RAPS_MPILIB} ${MODULES_PROFILE_PATH}
    assert_success
}

@test "load_template_sim_ifs-nemo_mn5" {
    export CURRENT_ARCH="MARENOSTRUM5"
    export HPCROOTDIR="${ROOTDIR}"
    export PROJDEST="${PROJDEST}"
    export_slurm_vars
    convert_AS_variables_to_parameters "HPCROOTDIR" "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh"
    convert_AS_variables_to_parameters "PROJDEST" "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh"
    run source "${ROOTDIR}/proj/${PROJDEST}/templates/sim_ifs-nemo.sh" ${HPCROOTDIR} ${PROJDEST} ${CURRENT_ARCH} ${CHUNKSIZE} ${CHUNKSIZEUNIT} ${MODEL_NAME} ${ENVIRONMENT} ${HPCARCH} ${MODEL_VERSION} ${OCEAN_GRID} ${EXPID} ${ATM_GRID} ${CHUNK} ${TOTAL_RETRIALS} ${ICMCL} ${START_DATE} ${END_DATE} ${END_IN_DAYS} ${PREV} ${RUN_DAYS} ${IFS_IO_TASKS} ${NEMO_IO_TASKS} ${HPC_PROJECT} ${MULTIO_ATM_PLANS} ${MULTIO_OCEAN_PLANS} ${PU} ${RAPS_USER_FLAGS} ${RAPS_EXPERIMENT} ${RUN_TYPE} ${IFS_IO_PPN} ${NEMO_IO_PPN} ${IFS_IO_NODES} ${NEMO_IO_NODES} ${MEMBER} "${MEMBER_LIST}" ${WORKFLOW} ${SPLITS} ${EXPVER} ${CLASS} ${FDB_HOME} ${DQC_PROFILE_PATH} ${EXPERIMENT} ${ACTIVITY} ${GENERATION} ${MODEL} ${IO_ON} ${LIBDIR} ${SCRATCH_DIR} ${HPC_CONTAINER_DIR} ${GSV_VERSION} ${MODEL_ROOT_PATH} ${MODEL_PATH} ${MODEL_INPUTS} ${SCRIPTDIR} ${RAPS_HOST_CPU} ${RAPS_HOST_GPU} ${RAPS_BIN_HPC_NAME} ${RAPS_COMPILER} ${RAPS_MPILIB} ${MODULES_PROFILE_PATH}
    assert_success
}
