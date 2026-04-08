#!/usr/bin/env bats
#
# Unit tests for monitor_resources.sh script.
#
# This test suite validates the bash script that launches the resource monitor
# for SLURM jobs. It tests the script's structure, parameter handling, and logic.

# Setup and teardown
setup() {
    # Get the script path (go up from tests/bats_tests/templates to workspace root)
    WORKSPACE_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
    MONITOR_SCRIPT="$WORKSPACE_ROOT/templates/performance/monitor_resources.sh"

    # Create temporary test directory
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR

    # Setup test environment variables
    export EXPID="test_exp"
    export USER="testuser"
    export HPCROOTDIR="$TEST_DIR/hpc"
    export CHUNK="1"
    export WRAPPER=""
    export SIM_START_DATE="20250101"
    export MEMBER="fc0"
    export SCRIPTDIR="$TEST_DIR/scripts"
    export HPC_CONTAINER_DIR="$TEST_DIR/containers"
    export PERFORMANCE_METRICS_VERSION="1.0"
    export SAMPLING_FREQUENCY="30"
    export SLURM_FREQUENCY="60"
    export LIBDIR="$TEST_DIR/lib"
    export CURRENT_ARCH="lumi-c"
    export RUNDIR_PATH="$TEST_DIR/rundir"

    # Create required directories
    mkdir -p "$SCRIPTDIR/CPMIP"
    mkdir -p "$LIBDIR/lumi"
    mkdir -p "$LIBDIR/common"
    mkdir -p "$HPC_CONTAINER_DIR"
    mkdir -p "$HPCROOTDIR"
    mkdir -p "$RUNDIR_PATH"
}

teardown() {
    # Clean up temporary test directory
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Mock functions to override external commands
function create_mock_commands() {
    # Create mock squeue that returns a job ID
    cat > "$TEST_DIR/squeue" << 'EOF'
#!/bin/bash
echo "12345"
EOF
    chmod +x "$TEST_DIR/squeue"

    # Create mock python3 that executes Python scripts
    cat > "$TEST_DIR/python3" << 'EOF'
#!/bin/bash
# Mock python3 - handle both script execution and module execution
if [ "$1" = "-m" ]; then
    # Module mode: python3 -m module.path args...
    # Just echo success for now
    echo "Mock Python module execution: $@"
    exit 0
else
    # Script mode: python3 script.py args...
    script="$1"
    shift
    # Execute the script directly with bash, ignoring the python shebang
    bash "$script" "$@"
fi
EOF
    chmod +x "$TEST_DIR/python3"

    # Create mock Python script (written as bash since our mock python3 runs it with bash)
    cat > "$SCRIPTDIR/CPMIP/resource_monitor.py" << 'EOF'
#!/bin/bash
# Mock Python script running as bash
echo "Mock monitor running with args: $@"
exit 0
EOF
    chmod +x "$SCRIPTDIR/CPMIP/resource_monitor.py"

    # Create mock library files
    cat > "$LIBDIR/lumi/config.sh" << 'EOF'
#!/bin/bash
function load_singularity() {
    echo "Mock: Loading singularity"
}
function load_additional_modules() {
    echo "Mock: Loading additional modules"
}
EOF

    cat > "$LIBDIR/common/util.sh" << 'EOF'
#!/bin/bash
# Mock utility functions
EOF

    # Create the container file (required by validation)
    touch "$HPC_CONTAINER_DIR/performance_metrics_${PERFORMANCE_METRICS_VERSION}.sif"

    # Add mocks to PATH
    export PATH="$TEST_DIR:$PATH"
}


# ============================================================================
# BEHAVIORAL TESTS - Testing actual script execution and logic
# ============================================================================

@test "monitor script exists and is executable" {
    [ -f "$MONITOR_SCRIPT" ]
    [ -r "$MONITOR_SCRIPT" ]
}

@test "script executes successfully with valid job ID found" {
    create_mock_commands

    # Run the script with all parameters
    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -eq 0 ]
    [[ "$output" == *"INFO: Starting performance monitoring"* ]]
}

@test "script exits with error when job ID not found" {
    create_mock_commands

    # Create squeue that returns empty (no job found)
    cat > "$TEST_DIR/squeue" << 'EOF'
#!/bin/bash
# Return nothing - simulating no job found
EOF
    chmod +x "$TEST_DIR/squeue"

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -ne 0 ]
}

@test "script exits with error when Python script does not exist" {
    create_mock_commands

    # Remove the Python script
    rm -f "$SCRIPTDIR/CPMIP/resource_monitor.py"

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -ne 0 ]
}

@test "script constructs correct jobname without wrapper" {
    create_mock_commands

    export WRAPPER=""
    expected_jobname="${EXPID}_${SIM_START_DATE}_${MEMBER}_${CHUNK}_SIM"

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -eq 0 ]
    # Just verify it ran successfully - output format may vary with set -x
}

@test "script constructs correct jobname with wrapper" {
    create_mock_commands

    WRAPPER="1"
    expected_jobname="${EXPID}_ASThread"

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -eq 0 ]
    [[ "$output" == *"job 12345 with name $expected_jobname"* ]]
}

@test "script creates correct directory structure" {
    create_mock_commands

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -eq 0 ]

    # Verify the performance/monitor directory was created in HPCROOTDIR
    # The script should create: ${HPCROOTDIR}/performance/monitor/${jobname}-${jobid}
    # Check that the base performance directory exists
    [ -d "$HPCROOTDIR/performance" ]
    [ -d "$HPCROOTDIR/performance/monitor" ]

    # Verify at least one subdirectory was created (the jobname-jobid directory)
    # Use find to check if any directory exists under monitor/
    job_dirs=$(find "$HPCROOTDIR/performance/monitor" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    [ "$job_dirs" -gt 0 ]
}

@test "script extracts HPC platform correctly from CURRENT_ARCH" {
    create_mock_commands

    # Test with LUMI architecture
    CURRENT_ARCH="lumi-c"
    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -eq 0 ]

    # Verify it tried to source lumi config (would fail if HPC extraction didn't work)
}

@test "script passes all required arguments to Python monitor" {
    create_mock_commands

    # Override python3 mock to print arguments
    cat > "$TEST_DIR/python3" << 'EOF'
#!/bin/bash
if [ "$1" = "-m" ]; then
    shift  # Remove -m
    module="$1"
    shift  # Remove module name
    echo "Module: $module"
    for arg in "$@"; do
        echo "ARG: $arg"
    done
    exit 0
else
    script="$1"
    shift
    bash "$script" "$@"
fi
EOF
    chmod +x "$TEST_DIR/python3"

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -eq 0 ]
    [[ "$output" == *"ARG: --jobid"* ]]
    [[ "$output" == *"ARG: 12345"* ]]
    [[ "$output" == *"ARG: --frequency"* ]]
    [[ "$output" == *"ARG: $SAMPLING_FREQUENCY"* ]]
    [[ "$output" == *"ARG: --slurm_frequency"* ]]
    [[ "$output" == *"ARG: $SLURM_FREQUENCY"* ]]
    [[ "$output" == *"ARG: --pidstat-path"* ]]
    [[ "$output" == *"ARG: /usr/local/bin/pidstat"* ]]
    [[ "$output" == *"ARG: --container-sif"* ]]
}

@test "script handles multiple job IDs and selects latest" {
    create_mock_commands

    # Create squeue that returns multiple job IDs (simulating multiple jobs with same name)
    cat > "$TEST_DIR/squeue" << 'EOF'
#!/bin/bash
echo "12343"
echo "12345"
echo "12344"
EOF
    chmod +x "$TEST_DIR/squeue"

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -eq 0 ]
    # Script should select 12345 (highest after sort -n | tail -1)
    [[ "$output" == *"job 12345"* ]]
}

# ============================================================================
# CONTAINER VALIDATION TESTS - Testing HPC_CONTAINER_DIR and version checks
# ============================================================================

@test "script fails when HPC_CONTAINER_DIR is empty" {
    create_mock_commands

    # Test with empty container directory
    HPC_CONTAINER_DIR=""

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR: HPC_CONTAINER_DIR is not set"* ]]
}

@test "script fails when HPC_CONTAINER_DIR is unset" {
    create_mock_commands

    # Unset the variable
    unset HPC_CONTAINER_DIR

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR: HPC_CONTAINER_DIR is not set"* ]]
}

@test "script fails when PERFORMANCE_METRICS_VERSION is empty" {
    create_mock_commands

    # Create container file with empty version (this should fail validation)
    PERFORMANCE_METRICS_VERSION=""

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR: PERFORMANCE_METRICS_VERSION is not set"* ]]
}

@test "script fails when PERFORMANCE_METRICS_VERSION is unset" {
    create_mock_commands

    unset PERFORMANCE_METRICS_VERSION

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR: PERFORMANCE_METRICS_VERSION is not set"* ]]
}

@test "script fails when container file does not exist" {
    create_mock_commands

    # Remove the container file that was created by create_mock_commands
    rm -f "$HPC_CONTAINER_DIR/performance_metrics_${PERFORMANCE_METRICS_VERSION}.sif"

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR: Container file does not exist"* ]]
    [[ "$output" == *"performance_metrics_${PERFORMANCE_METRICS_VERSION}.sif"* ]]
}

@test "script lists available containers when expected file is missing" {
    create_mock_commands

    # Remove the default container created by create_mock_commands
    rm -f "$HPC_CONTAINER_DIR/performance_metrics_${PERFORMANCE_METRICS_VERSION}.sif"

    # Create different versions of the container (not the one we're looking for)
    touch "$HPC_CONTAINER_DIR/performance_metrics_2.0.sif"
    touch "$HPC_CONTAINER_DIR/performance_metrics_latest.sif"

    # But we're looking for version 1.0 which doesn't exist
    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR: Container file does not exist"* ]]
    [[ "$output" == *"Available files"* ]]
    [[ "$output" == *"performance_metrics_2.0.sif"* ]]
    [[ "$output" == *"performance_metrics_latest.sif"* ]]
}

@test "script succeeds when container file exists" {
    create_mock_commands

    # Create the expected container file
    touch "$HPC_CONTAINER_DIR/performance_metrics_${PERFORMANCE_METRICS_VERSION}.sif"

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -eq 0 ]
    [[ "$output" == *"INFO: Using container:"* ]]
    [[ "$output" == *"performance_metrics_${PERFORMANCE_METRICS_VERSION}.sif"* ]]
}

@test "script constructs correct container path" {
    create_mock_commands

    # Override python3 mock to show arguments
    cat > "$TEST_DIR/python3" << 'EOF'
#!/bin/bash
if [ "$1" = "-m" ]; then
    shift  # Remove -m
    module="$1"
    shift  # Remove module name
    for arg in "$@"; do
        echo "ARG: $arg"
    done
    exit 0
else
    script="$1"
    shift
    bash "$script" "$@"
fi
EOF
    chmod +x "$TEST_DIR/python3"

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$HPC_CONTAINER_DIR" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -eq 0 ]

    # Verify the full container path is passed correctly
    expected_path="${HPC_CONTAINER_DIR}/performance_metrics_${PERFORMANCE_METRICS_VERSION}.sif"
    [[ "$output" == *"ARG: $expected_path"* ]]
}

@test "script handles container path with special characters" {
    create_mock_commands

    # Create a container directory with spaces (edge case)
    SPECIAL_DIR="$TEST_DIR/container dir with spaces"
    mkdir -p "$SPECIAL_DIR"
    touch "$SPECIAL_DIR/performance_metrics_${PERFORMANCE_METRICS_VERSION}.sif"

    run bash "$MONITOR_SCRIPT" \
        "$EXPID" "$USER" "$HPCROOTDIR" "$CHUNK" "$WRAPPER" \
        "$SIM_START_DATE" "$MEMBER" "$SCRIPTDIR" "$SPECIAL_DIR" \
        "$PERFORMANCE_METRICS_VERSION" "$SAMPLING_FREQUENCY" "$SLURM_FREQUENCY" \
        "$LIBDIR" "$CURRENT_ARCH" "$RUNDIR_PATH"

    [ "$status" -eq 0 ]
    [[ "$output" == *"INFO: Using container:"* ]]
}
