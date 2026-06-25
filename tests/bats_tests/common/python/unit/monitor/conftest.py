"""
Shared fixtures for monitor unit tests.

These are minimal/dummy fixtures for unit tests that may reference
real data fixtures but don't actually need them (backward compatibility).

For real integration tests with production data, see:
tests/bats_tests/common/python/integration/monitor/
"""

import pytest
from pathlib import Path


# Load real fixtures if available (for tests that still reference them)
fixtures_dir = (
    Path(__file__).parent.parent.parent / "integration" / "monitor" / "fixtures"
)


@pytest.fixture
def real_scontrol_output():
    """Real scontrol output from production."""
    fixture_file = fixtures_dir / "real_scontrol_output.txt"
    if fixture_file.exists():
        return fixture_file.read_text()
    return "JobId=12345 State=RUNNING"  # Minimal fallback


@pytest.fixture
def real_sstat_parseable_output():
    """Real sstat parseable output from production."""
    fixture_file = fixtures_dir / "real_sstat_output_parseable.txt"
    if fixture_file.exists():
        return fixture_file.read_text()
    return "JobID|MaxRSS|AveRSS\n12345.0|4G|2G"  # Minimal fallback


@pytest.fixture
def real_lscpu_output():
    """Real lscpu output from production."""
    fixture_file = fixtures_dir / "real_lscpu_output.txt"
    if fixture_file.exists():
        return fixture_file.read_text()
    return "Thread(s) per core: 2\nCore(s) per socket: 64\nSocket(s): 2"


@pytest.fixture
def real_free_output():
    """Real free output from production."""
    fixture_file = fixtures_dir / "real_free_output.txt"
    if fixture_file.exists():
        return fixture_file.read_text()
    return "Mem: 512000 256000 256000"


@pytest.fixture
def real_uptime_output():
    """Real uptime output from production."""
    fixture_file = fixtures_dir / "real_uptime_output.txt"
    if fixture_file.exists():
        return fixture_file.read_text()
    return "load average: 1.0, 2.0, 3.0"


@pytest.fixture
def real_pidstat_output():
    """Real pidstat output from production."""
    fixture_file = fixtures_dir / "real_pidstat_output.txt"
    if fixture_file.exists():
        return fixture_file.read_text()
    return ""  # Minimal fallback


@pytest.fixture
def sample_sstat_output():
    """Sample sstat output for testing - must match all SSTAT_FIELDS."""
    # Fields: MaxVMSize|MaxVMSizeNode|MaxVMSizeTask|AveVMSize|MaxRSS|MaxRSSNode|MaxRSSTask|AveRSS|
    #         MaxDiskRead|MaxDiskReadNode|MaxDiskReadTask|AveDiskRead|MaxDiskWrite|MaxDiskWriteNode|MaxDiskWriteTask|AveDiskWrite|
    #         MaxPages|MaxPagesNode|MaxPagesTask|AvePages|ConsumedEnergy|NTasks|MinCPU|MinCPUNode|MinCPUTask|AveCPU|AveCPUFreq|
    #         ReqCPUFreqMin|ReqCPUFreqMax|ReqCPUFreqGov|
    #         TRESUsageInTot|TRESUsageOutTot|TRESUsageInMax|TRESUsageInMaxNode|TRESUsageInMaxTask|
    #         TRESUsageOutMax|TRESUsageOutMaxNode|TRESUsageOutMaxTask|
    #         TRESUsageInMin|TRESUsageInMinNode|TRESUsageInMinTask|
    #         TRESUsageOutMin|TRESUsageOutMinNode|TRESUsageOutMinTask|
    #         TRESUsageInAve|TRESUsageOutAve
    return (
        "12345.batch|4G|node01|0|2G|2G|node01|0|1G|"
        "1000M|node01|0|500M|800M|node01|0|400M|"
        "5000|node01|0|2500|1234.56|"
        "16|00:30:00|node01|0|00:15:00|2400000|"
        "Unknown|Unknown|Unknown|"
        "cpu=01:00:00,mem=50G|cpu=00:30:00,mem=20G|cpu=02:00:00,mem=100G|node01|0|"
        "cpu=01:00:00,mem=40G|node01|0|"
        "cpu=00:10:00,mem=10G|node01|0|"
        "cpu=00:20:00,mem=15G|node01|0|"
        "cpu=01:30:00,mem=75G|cpu=00:45:00,mem=30G"
    )
