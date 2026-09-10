"""
Pytest configuration and fixtures for monitor module tests.

This module provides common fixtures and configuration for testing the Climate DT
workflow monitoring components. It follows the pytest best practices for fixture
organization and includes mock data generators for SLURM commands.)

Thread Safety:
    All fixtures are function-scoped by default to ensure test isolation.
"""

import pytest
from pathlib import Path


@pytest.fixture
def fixtures_dir() -> Path:
    """
    Get path to test fixtures directory.

    Returns:
        Path: Absolute path to fixtures directory containing sample SLURM outputs.

    Example:
        >>> def test_load_fixture(fixtures_dir):
        ...     sstat_file = fixtures_dir / "sstat_output.txt"
        ...     assert sstat_file.exists()
    """
    return Path(__file__).parent / "fixtures"


@pytest.fixture
def real_sstat_parseable_output(fixtures_dir) -> str:
    """
    Load real sstat output from production SLURM system (parseable format).

    Returns:
        str: Real sstat -P --noheader output from job 32266924.

    Source: SLURM production system, 2025-11-18
    Features:
        - Two steps: extern and batch
        - Real TRES usage with energy, fs/disk
        - Realistic memory and disk I/O values
    """
    return (fixtures_dir / "real_sstat_output_parseable.txt").read_text()


@pytest.fixture
def real_scontrol_output(fixtures_dir) -> str:
    """
    Load real scontrol show job output from production SLURM system.

    Returns:
        str: Real scontrol output from job 32266924.

    Source: SLURM production system, 2025-11-18
    Features:
        - Interactive job on glogin3
        - Real TRES: cpu=2,mem=2000M,node=1
        - Actual timestamps and paths
    """
    return (fixtures_dir / "real_scontrol_output.txt").read_text()


@pytest.fixture
def real_lscpu_output(fixtures_dir) -> str:
    """
    Load real lscpu output from production HPC node.

    Returns:
        str: Real lscpu output from glogin4.

    Source: Production HPC node, 2025-11-18
    Features:
        - Intel Xeon Platinum 8480+
        - 224 logical CPUs (56 cores × 2 sockets × 2 threads)
        - SMT enabled (TPC=2)
    """
    return (fixtures_dir / "real_lscpu_output.txt").read_text()


@pytest.fixture
def real_free_output(fixtures_dir) -> str:
    """
    Load real free -k output from production HPC node.

    Returns:
        str: Real free -k output showing memory usage.

    Source: Production HPC node, 2025-11-18
    Features:
        - 263 GB total memory
        - 63% used (166 GB)
        - Minimal swap usage
    """
    return (fixtures_dir / "real_free_output.txt").read_text()


@pytest.fixture
def real_uptime_output(fixtures_dir) -> str:
    """
    Load real uptime output from production HPC node.

    Returns:
        str: Real uptime output with load averages.

    Source: Production HPC node, 2025-11-18
    Features:
        - 104 days uptime
        - Load averages: 6.23, 6.53, 7.93
        - 60 users logged in
    """
    return (fixtures_dir / "real_uptime_output.txt").read_text()


@pytest.fixture
def real_pidstat_output(fixtures_dir) -> str:
    """
    Load real pidstat output from production HPC node.

    Returns:
        str: Real pidstat -h -urw output from glogin4.

    Source: Production HPC node glogin4, 2025-11-18
    Features:
        - 224 logical CPUs (Intel Xeon)
        - Kernel processes (ksoftirqd, migration)
        - Real CPU usage and context switches
        - Zero memory processes (kernel threads)

    Note:
        Header line starts with '# Time' (commented out by pidstat -h flag)
    """
    return (fixtures_dir / "real_pidstat_output.txt").read_text()


@pytest.fixture
def sample_sstat_output() -> str:
    """
    Generate sample sstat command output for testing.

    Returns:
        str: Pipe-delimited sstat output with multiple job steps including:
            - Main job step (12345.0)
            - Batch step (12345.batch)
            - External step (12345.extern)

    Format:
        JobID|MaxRSS|AveRSS|MaxVMSize|AveVMSize|...

    Note:
        Uses binary (base-1024) units as per SLURM convention:
        K=1024, M=1024², G=1024³

    Example:
        >>> output = sample_sstat_output()
        >>> assert "12345.0|" in output
        >>> assert "|4096M|" in output  # Memory in MiB
    """
    return (
        "12345.0|4096M|nid001|0|2048M|8192M|nid001|0|4096M|"
        "1024M|nid001|0|512M|2048M|nid001|0|1024M|"
        "1000|nid001|0|500|100.5J|10|00:10:00|nid001|0|00:05:00|"
        "2000.0|Unknown|Unknown|Unknown|"
        "cpu=600,mem=4G|cpu=1200,mem=8G|cpu=300,mem=2G|cpu=600,mem=4G|"
        "cpu=600,mem=4G|cpu=1200,mem=8G|cpu=300,mem=2G|cpu=600,mem=4G\n"
        "12345.batch|2048M|nid001|0|1024M|4096M|nid001|0|2048M|"
        "512M|nid001|0|256M|1024M|nid001|0|512M|"
        "500|nid001|0|250|50.5J|5|00:05:00|nid001|0|00:02:30|"
        "1800.0|Unknown|Unknown|Unknown|"
        "cpu=300,mem=2G|cpu=600,mem=4G|cpu=150,mem=1G|cpu=300,mem=2G|"
        "cpu=300,mem=2G|cpu=600,mem=4G|cpu=150,mem=1G|cpu=300,mem=2G\n"
    )


@pytest.fixture
def sample_scontrol_output() -> str:
    """
    Generate sample scontrol show job output for testing.

    Returns:
        str: Space-separated key=value output from 'scontrol show job <jobid>'.

    Format:
        Key=Value pairs separated by spaces, with quoted strings for paths.

    Important Fields:
        - JobId: Job identifier (numeric)
        - NumCPUs: Logical CPU count (physical_cores × TPC)
        - AllocTRES: Allocated TRES resources in format 'cpu=N,mem=XG,node=N'
        - NodeList: SLURM nodelist notation (e.g., 'nid[001-004]')

    Thread Safety:
        Contains TPC-sensitive fields (NumCPUs, CPUs/Task) that need conversion.

    Example:
        >>> output = sample_scontrol_output()
        >>> assert "JobId=12345" in output
        >>> assert "NumCPUs=128" in output  # Logical cores (64 physical × TPC=2)
    """
    return (
        "JobId=12345 JobName=test_job UserId=user1(1000) GroupId=group1(1000) "
        "MCS_label=N/A Priority=4294901757 Nice=0 Account=account1 QOS=normal "
        "JobState=RUNNING Reason=None Dependency=(null) Requeue=1 Restarts=0 "
        "BatchFlag=1 Reboot=0 ExitCode=0:0 RunTime=01:30:00 TimeLimit=02:00:00 "
        "TimeMin=N/A SubmitTime=2025-01-15T10:00:00 EligibleTime=2025-01-15T10:00:00 "
        "AccrueTime=2025-01-15T10:00:00 StartTime=2025-01-15T10:05:00 "
        "EndTime=2025-01-15T12:05:00 Deadline=N/A SuspendTime=None SecsPreSuspend=0 "
        "LastSchedEval=2025-01-15T10:05:00 Scheduler=Main Partition=main "
        "AllocNode:Sid=login01:12345 ReqNodeList=(null) ExcNodeList=(null) "
        "NodeList=nid[001-004] BatchHost=nid001 NumNodes=4 NumCPUs=128 NumTasks=64 "
        "CPUs/Task=2 ReqB:S:C:T=0:0:*:* TRES=cpu=128,mem=512G,node=4,billing=128 "
        "Socks/Node=* NtasksPerN:B:S:C=0:0:*:* CoreSpec=* MinCPUsNode=1 "
        "MinMemoryCPU=4G MinTmpDiskNode=0 Features=(null) DelayBoot=00:00:00 "
        "OverSubscribe=OK Contiguous=0 Licenses=(null) Network=(null) "
        "Command=/path/to/script.sh WorkDir=/work/dir StdErr=/work/dir/error.log "
        "StdIn=/dev/null StdOut=/work/dir/output.log Power= "
        "AllocTRES=cpu=128,mem=512G,node=4,billing=128"
    )


@pytest.fixture
def sample_pidstat_output() -> str:
    """
    Generate sample pidstat -urwh output for testing.

    Returns:
        str: Multi-line output with header and process statistics.

    Format:
        Time UID PID %usr %system %guest %wait %CPU CPU minflt/s majflt/s VSZ RSS %MEM cswch/s nvcswch/s Command

    Important Notes:
        - %CPU is percentage relative to LOGICAL cores (needs TPC conversion)
        - %MEM is percentage of NODE's total memory (not job allocation)
        - VSZ/RSS in KB by default (pidstat without -k flag shows KB)
        - CPU column is last-seen processor ID (0 to N-1)

    Thread Safety:
        %CPU values must be normalized: physical_cores = (%CPU / 100) / TPC

    Example:
        >>> output = sample_pidstat_output()
        >>> lines = output.strip().split('\\n')
        >>> assert len(lines) >= 2  # Header + at least one process
        >>> assert "400.00" in output  # 4 logical cores at 100% each
    """
    return """09:18:36        0   1234   25.00   10.00    0.00    0.00   35.00    0    100.00      0.00  4194304  2097152   0.50    50.00     10.00  my_process
09:18:36        0   5678  400.00   50.00    0.00    5.00  455.00   15    500.00      5.00  8388608  4194304   1.00   200.00     20.00  heavy_process
09:18:36        0   9012    5.00    2.00    0.00    0.00    7.00   31     10.00      0.00  1048576   524288   0.10     5.00      1.00  light_process
"""


@pytest.fixture
def sample_lscpu_output() -> str:
    """
    Generate sample lscpu output for testing CPU topology detection.

    Returns:
        str: Multi-line output showing CPU architecture details.

    Key Fields:
        - Thread(s) per core: SMT/Hyper-Threading factor (TPC)
        - Core(s) per socket: Physical cores per CPU socket
        - Socket(s): Number of CPU sockets
        - Model name: CPU model identifier

    Formula:
        Total Physical Cores = Sockets × Cores_Per_Socket
        Total Logical Cores = Total Physical Cores × TPC

    Example:
        >>> output = sample_lscpu_output()
        >>> assert "Thread(s) per core:  2" in output  # SMT enabled
        >>> assert "Core(s) per socket:  32" in output
        >>> # Total: 2 sockets × 32 cores × 2 threads = 128 logical cores
    """
    return """Architecture:        x86_64
CPU op-mode(s):      32-bit, 64-bit
Byte Order:          Little Endian
CPU(s):              128
On-line CPU(s) list: 0-127
Thread(s) per core:  2
Core(s) per socket:  32
Socket(s):           2
NUMA node(s):        2
Vendor ID:           GenuineIntel
CPU family:          6
Model:               85
Model name:          Intel(R) Xeon(R) Platinum 8268 CPU @ 2.90GHz
Stepping:            7
CPU MHz:             2900.000
BogoMIPS:            5800.00
"""


@pytest.fixture
def sample_free_output() -> str:
    """
    Generate sample 'free -k' output for testing memory statistics.

    Returns:
        str: Multi-line output showing memory usage in kilobytes.

    Format:
        Line 1: Header (total used free shared buff/cache available)
        Line 2: Mem: <values in KB>
        Line 3: Swap: <values in KB>

    Important:
        - All values in KB (kilobytes, base 1024)
        - 'available' column shows memory available for new applications
        - buff/cache can be reclaimed if needed

    Example:
        >>> output = sample_free_output()
        >>> lines = output.strip().split('\\n')
        >>> assert lines[0].strip().startswith("total")
        >>> assert "Mem:" in lines[1]
    """
    return """              total        used        free      shared  buff/cache   available
Mem:      263568128    78521856    66241280     2351232   118804992   180419200
Swap:      16777216     1048576    15728640
"""
