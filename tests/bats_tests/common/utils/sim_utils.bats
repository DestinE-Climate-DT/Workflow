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

@test load_experiment_ifs {
    export IFS_EXPVER="123"
    export label="test"
    export GTYPE="gtype_test"
    export RESOL="resol_test"
    export levels="456"
    export CHUNKSIZEUNIT="month"

    run load_experiment_ifs
    assert_success
}

@test "load_experiment_ifs explicit chunk end date accumulates fclen across splits and chunks" {
    # When the optional second argument (this_chunk_end_date) is given, fclen counts
    # days from the fixed base date IFS_START_DATE to that end date, so it
    # accumulates across all splits and chunks (d1, d2, ... d31, d32, ...). Used by
    # NRT day-splits but not tied to NRT. Call the function directly (not via run)
    # so the exported fclen is visible to the assertions.
    export IFS_START_DATE="19900101"

    load_experiment_ifs "${SIM_START_DATE}" "19900102" # day 1
    assert_equal "${fclen}" "d1"

    load_experiment_ifs "${SIM_START_DATE}" "19900201" # day 31
    assert_equal "${fclen}" "d31"

    load_experiment_ifs "${SIM_START_DATE}" "19900202" # day 32
    assert_equal "${fclen}" "d32"
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

@test "restarts_moving NRT split 1 skips file moves" {
    # Split 1: the template already pointed current→CHUNK/SPLIT before RAPS ran.
    # Source and destination resolve to the same directory; file moves must be
    # skipped to avoid "cannot move to itself" errors.  Only the symlink refresh
    # is expected.
    export NRT=true
    export PRE_RESTART_DIR="${DIR}/test_restarts_nrt_s1"
    export IFS_START_DATE="19900101"
    export SDATE_LONG="${IFS_START_DATE}000000"
    export runlength="1"
    export CHUNK=1
    export SPLIT=1
    export SPLIT_LAST="FALSE"
    export EXPVER="test"
    export SPLIT_END_DATE="19900102"

    local split_dir="${PRE_RESTART_DIR}/${CHUNK}/${SPLIT}"
    mkdir -p "${split_dir}"

    # Simulate what the template does for SPLIT==1 before RAPS runs
    ln -sfn "${CHUNK}/${SPLIT}" "${PRE_RESTART_DIR}/current"

    # Simulate RAPS output landing in current (= split_dir)
    touch "${split_dir}/LAW${SDATE_LONG}_000000"
    touch "${split_dir}/srf000001"
    touch "${split_dir}/BLS${SDATE_LONG}_000000"
    touch "${split_dir}/waminfo"
    touch "${split_dir}/rcf"

    run restarts_moving
    assert_success

    # Files must still be in 1/1 (no move happened)
    assert [ -f "${split_dir}/LAW${SDATE_LONG}_000000" ]
    assert [ -f "${split_dir}/rcf" ]

    # current must still point to 1/1
    assert_equal "$(readlink "${PRE_RESTART_DIR}/current")" "${CHUNK}/${SPLIT}"

    rm -rf "${PRE_RESTART_DIR}"
}

@test "restarts_moving NRT mid-chunk split moves files to next split dir" {
    # Split 2: current→1/1 (output of split 1).  After split 2 runs,
    # restarts_moving must move files from 1/1 to 1/2 and advance current.
    export NRT=true
    export PRE_RESTART_DIR="${DIR}/test_restarts_nrt_s2"
    export IFS_START_DATE="19900101"
    export SDATE_LONG="${IFS_START_DATE}000000"
    export runlength="2"
    export CHUNK=1
    export SPLIT=2
    export SPLIT_LAST="FALSE"
    export EXPVER="test"
    export SPLIT_END_DATE="19900103"

    local src_dir="${PRE_RESTART_DIR}/1/1"
    local dst_dir="${PRE_RESTART_DIR}/1/2"
    mkdir -p "${src_dir}" "${dst_dir}"

    # current points to the previous split's directory (1/1)
    ln -sfn "1/1" "${PRE_RESTART_DIR}/current"

    touch "${src_dir}/LAW${SDATE_LONG}_000001"
    touch "${src_dir}/srf000002"
    touch "${src_dir}/BLS${SDATE_LONG}_000001"
    touch "${src_dir}/waminfo"
    touch "${src_dir}/rcf"

    run restarts_moving
    assert_success

    # Files must have moved to 1/2
    assert [ -f "${dst_dir}/rcf" ]
    assert [ -f "${dst_dir}/waminfo" ]
    # Source dir must be empty of those files
    assert [ ! -f "${src_dir}/rcf" ]

    # current must now point to 1/2
    assert_equal "$(readlink "${PRE_RESTART_DIR}/current")" "${CHUNK}/${SPLIT}"

    rm -rf "${PRE_RESTART_DIR}"
}

@test "restarts_moving NRT last split moves files to next chunk's first split" {
    # SPLIT_LAST=TRUE: files from current (1/31) go to 2/1 and current advances.
    export NRT=true
    export PRE_RESTART_DIR="${DIR}/test_restarts_nrt_last"
    export IFS_START_DATE="19900101"
    export SDATE_LONG="${IFS_START_DATE}000000"
    export runlength="31"
    export CHUNK=1
    export SPLIT=31
    export SPLIT_LAST="TRUE"
    export EXPVER="test"
    export SPLIT_END_DATE="19900201"

    local src_dir="${PRE_RESTART_DIR}/1/30"
    mkdir -p "${src_dir}"

    ln -sfn "1/30" "${PRE_RESTART_DIR}/current"

    touch "${src_dir}/LAW${SDATE_LONG}_000030"
    touch "${src_dir}/srf000031"
    touch "${src_dir}/BLS${SDATE_LONG}_000030"
    touch "${src_dir}/waminfo"
    touch "${src_dir}/rcf"

    run restarts_moving
    assert_success

    local next_dir="${PRE_RESTART_DIR}/2/1"
    assert [ -f "${next_dir}/rcf" ]
    assert [ -f "${next_dir}/waminfo" ]
    assert [ ! -f "${src_dir}/rcf" ]

    # current must point to 2/1 for the next chunk's first split
    assert_equal "$(readlink "${PRE_RESTART_DIR}/current")" "$((CHUNK + 1))/1"

    rm -rf "${PRE_RESTART_DIR}"
}

@test iso8601_to_seconds {
    export duration="2D"
    run iso8601_to_seconds ${duration}
    assert_output "172800"

    export duration="2D5H3S"
    run iso8601_to_seconds ${duration}
    assert_output "190803"
}
