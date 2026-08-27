# Tests for common/utils/sim_utils.sh

## setup

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert

    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
    # source file under test
    source "${DIR}/../../../../lib/common/utils/sim_utils.sh"

    export HPCROOTDIR=${DIR}
    export RAPS_HOST_CPU="raps_host_cpu"
    export RAPS_HOST_GPU="raps_host_gpu"
    export SIM_START_DATE=19900101
    export CHUNK_END_IN_DAYS=31
    export CHUNK=1
    export ATM_MODEL="ifs"
}

## load_variables_ifs
@test "load_variables_ifs exported values" {
    assert [ -z "${nodes}" ]
    assert [ -z "${mpi}" ]
    assert [ -z "${omp}" ]
    assert [ -z "${jobid}" ]
    assert [ -z "${jobname}" ]
    SLURM_JOB_NUM_NODES="1"
    SLURM_NPROCS="2"
    SLURM_CPUS_PER_TASK="3"
    SLURM_JOB_ID="4"
    SLURM_JOB_NAME="job.4"
    load_variables_ifs
    assert_equal "${nodes}" "1"
    assert_equal "${mpi}" "2"
    assert_equal "${omp}" "3"
    assert_equal "${jobid}" "4"
    assert_equal "${jobname}" "job.4"
}

@test "load_experiment_ifs with UTC time" {
    export IFS_EXPVER="123"
    export label="test"
    export gtype="gtype_test"
    export resol="resol_test"
    export levels="456"
    export CHUNKSIZEUNIT="month"
    export IFS_START_DATE="19900101"
    export USE_LOCAL_TIME="False"

    load_experiment_ifs
    assert_equal "${runlength}" "31"
    assert_equal "${fclen}" "d31"
}

@test "load_experiment_ifs with local time" {
    export IFS_EXPVER="123"
    export label="test"
    export gtype="gtype_test"
    export resol="resol_test"
    export levels="456"
    export CHUNKSIZEUNIT="month"
    export IFS_START_DATE="19900101"
    export USE_LOCAL_TIME="True"

    load_experiment_ifs
    assert_equal "${runlength}" "31"
    assert_equal "${fclen}" "d31"
}

@test "get_host_for_raps cpu" {
    PU="cpu"
    run get_host_for_raps ${PU} ${RAPS_HOST_CPU} ${RAPS_HOST_GPU}

    assert_success
    assert_equal "$output" ${RAPS_HOST_CPU}
}

@test "get_host_for_raps gpu" {
    PU="gpu"
    run get_host_for_raps ${PU} ${RAPS_HOST_CPU} ${RAPS_HOST_GPU}

    assert_success
    assert_equal "$output" ${RAPS_HOST_GPU}
}

@test "get_host_for_raps unknown PU" {
    PU="unknown"
    run get_host_for_raps ${PU} ${RAPS_HOST_CPU} ${RAPS_HOST_GPU}

    assert_failure
    assert_output --partial "ERROR: Unknown PU=unknown in /usr/local/libexec/bats-core/bats-exec-test::get_host_for_raps"
}

@test "check_rundir_name no previous rundir" {
    export runlength=1
    export jobname="test_job"
    export jobid="test"
    output=$(check_rundir_name)
    expected_output="Rundir variable is empty. No previous rundir found. "
    assert_output "$expected_output"
}

@test "check_rundir_name with previous rundir" {
    export runlength=1
    export SLURM_JOB_NAME="test_job"
    export SLURM_JOB_ID="test"
    export MODEL_NAME="ifs-nemo"

    TOTAL_RETRIALS=1
    test_rundir="${HPCROOTDIR}/h$(($runlength * 24))*${SLURM_JOB_NAME}-${SLURM_JOB_ID}"
    mkdir -pv "$test_rundir" >/dev/null 2>&1
    mkdir -pv "$test_rundir.1" >/dev/null 2>&1

    run check_rundir_name
    assert_output --partial "Previous rundir found. This is a retrial inside a wrapper"
    assert_output --partial "The previous rundir was: ${test_rundir}"
    assert_output --partial "Found the 1 attempt to run this chunk inside the wrapper"
    assert_output --partial "The previous rundir: ${test_rundir} has been renamed"
    assert_output --partial "It can be found in: ${test_rundir}.2"

    rm -rf "$test_rundir"*
}

@test restarts_moving {
    # Note: This test only validates common IFS atmospheric restart files
    # that are shared by both ifs-nemo and ifs-fesom models.
    # It does NOT test model-specific files (NEMO: nemorcf, FESOM: fesom_raw_restart)
    export PRE_RESTART_DIR="${DIR}/test_restarts"
    export IFS_START_DATE="19900101"
    export runlength="31"
    export MODEL_NAME="ifs-nemo"  # Required but not tested model-specifically

    formatted_days=$(printf "%06d" "$runlength")0000
    formatted_days_1=000030
    SDATE_LONG=${IFS_START_DATE}000000
    mkdir -p "${PRE_RESTART_DIR}/${CHUNK}"

    # make some test files to be moved (common IFS restart files only)
    test_files=(
      "LAW${SDATE_LONG}_${formatted_days_1}"
      "srf${formatted_days}"
      "BLS"${SDATE_LONG}_"${formatted_days_1}"
    )
    cd ${PRE_RESTART_DIR}/${CHUNK}
    for file in "${test_files[@]}"; do
      touch $file
    done

    run restarts_moving
    assert_success

    # check that the files were moved into the correct directory
    cd "/${PRE_RESTART_DIR}/$((CHUNK + 1))"
    for file in "${test_files[@]}"; do
      if [[ ! -f "$file" ]]; then
        echo "Missing expected file: $file"
        return 1
      fi
    done

    # clean up
    rm -rf ${PRE_RESTART_DIR}
}

@test iso8601_to_seconds {
    export duration="2D"
    run iso8601_to_seconds ${duration}
    assert_output "172800"

    export duration="2D5H3S"
    run iso8601_to_seconds ${duration}
    assert_output "190803"
}
