"""Tests for pidstat collector module - comprehensive mock coverage."""

import pytest
from unittest.mock import patch

from runscripts.CPMIP.monitor.pidstat.collector import (
    collect_single_node,
    collect_node_stats,
)


@pytest.fixture
def mock_sysinfo_output():
    """Mock sysinfo output matching real format."""
    return """10:23:45 up 5 days, 12:34,  2 users,  load average: 1.23, 2.34, 3.45
__SPLIT__
Architecture:                       x86_64
Thread(s) per core:                 2
Core(s) per socket:                 28
Socket(s):                          2
CPU(s):                             112
Model name:                         Intel Xeon
__SPLIT__
              total        used        free      shared  buff/cache   available
Mem:      196608000    12345678    98765432       12345    85496890   183262322
Swap:      10485760           0    10485760""".strip()


@pytest.fixture
def mock_pidstat_output():
    """Mock pidstat output with -h flag (all columns in one line)."""
    return """Linux 5.10.0-28-amd64 (nid001234)       11/19/2025      _x86_64_        (112 CPU)

09:18:36        0      1234   25.50    5.00    0.00    0.50   30.50     0    150.00      0.50  524288  262144  0.13   10.00      5.00  python
09:18:36        0      5678   10.00    2.00    0.00    0.00   12.00     1     50.00      0.00 1048576  524288  0.27   20.00      3.00  nemo.exe""".strip()


@patch("runscripts.CPMIP.monitor.pidstat.collector.execute_srun")
def test_basic_collection_success(mock_srun, mock_sysinfo_output, mock_pidstat_output):
    """
    GIVEN a single node with 2 running processes (PIDs 1234 and 5678)
    WHEN collect_single_node is called successfully
    THEN return NodeStats with:
      - Exactly 2 processes in summary count
      - Exactly 2 processes in Processes list
      - Valid Summary and Node_General_Info structures
    """
    mock_srun.side_effect = [
        (True, mock_sysinfo_output, ""),
        (True, mock_pidstat_output, ""),
    ]

    result = collect_single_node(
        node_name="nid001",
        pidstat_path="/usr/bin/pidstat",
        jobid="12345",
        threads_per_core=2,
    )

    # Exact structural checks
    assert "Summary" in result
    assert "Processes" in result
    assert "Node_General_Info" in result

    # Exact count verification
    assert result["Summary"]["Counts"]["Process_Count"] == 2
    assert len(result["Processes"]) == 2

    # Verify process details
    assert result["Processes"][0]["Pid"] == "1234"
    assert result["Processes"][1]["Pid"] == "5678"


@patch("runscripts.CPMIP.monitor.pidstat.collector.execute_srun")
def test_with_container(mock_srun, mock_sysinfo_output, mock_pidstat_output):
    """
    GIVEN a container_sif path="/path/to/container.sif"
    WHEN collect_single_node is called
    THEN pidstat command contains exactly these elements:
      - "singularity" executable
      - "exec" subcommand
      - container path
      - pidstat inside container
    """
    mock_srun.side_effect = [
        (True, mock_sysinfo_output, ""),
        (True, mock_pidstat_output, ""),
    ]

    collect_single_node(
        node_name="nid001",
        pidstat_path="/usr/bin/pidstat",
        jobid="12345",
        container_sif="/path/to/container.sif",
        threads_per_core=1,
    )

    # Verify the second call (pidstat command) uses singularity
    pidstat_command = mock_srun.call_args_list[1][1]["command"]
    assert pidstat_command[0] == "singularity"
    assert pidstat_command[1] == "exec"
    assert "/path/to/container.sif" in pidstat_command


@patch("runscripts.CPMIP.monitor.pidstat.collector.execute_srun")
def test_missing_pidstat_path(mock_srun):
    """
    GIVEN pidstat_path is empty string
    WHEN collect_single_node is called
    THEN raise ValueError.
    """
    with pytest.raises(ValueError, match="pidstat_path is required"):
        collect_single_node(node_name="nid001", pidstat_path="", jobid="12345")


@patch("runscripts.CPMIP.monitor.pidstat.collector.execute_srun")
def test_sysinfo_failure(mock_srun):
    """
    GIVEN srun commands fail on sysinfo collection
    WHEN collect_single_node is called
    THEN raise RuntimeError.
    """
    mock_srun.side_effect = [
        (False, "", "srun: error: Node failure"),
        (False, "", "srun: error: Node failure"),
    ]

    with pytest.raises(RuntimeError, match="srun failed"):
        collect_single_node(
            node_name="nid001", pidstat_path="/usr/bin/pidstat", jobid="12345"
        )


@patch("runscripts.CPMIP.monitor.pidstat.collector.execute_srun")
def test_permission_denied(mock_srun, mock_sysinfo_output):
    """
    GIVEN pidstat command returns permission denied
    WHEN collect_single_node is called
    THEN raise RuntimeError with permission error message.
    """
    mock_srun.side_effect = [
        (True, mock_sysinfo_output, ""),
        (False, "", "Permission denied"),
    ]

    with pytest.raises(RuntimeError, match="Permission denied"):
        collect_single_node(
            node_name="nid001", pidstat_path="/usr/bin/pidstat", jobid="12345"
        )


@patch("runscripts.CPMIP.monitor.pidstat.collector.execute_srun")
def test_job_terminated(mock_srun, mock_sysinfo_output):
    """
    GIVEN job has been terminated
    WHEN collect_single_node attempts pidstat collection
    THEN raise RuntimeError with job terminated message.
    """
    mock_srun.side_effect = [
        (True, mock_sysinfo_output, ""),
        (False, "", "Job terminated"),
    ]

    with pytest.raises(RuntimeError, match="Job terminated"):
        collect_single_node(
            node_name="nid001", pidstat_path="/usr/bin/pidstat", jobid="12345"
        )


@patch("runscripts.CPMIP.monitor.pidstat.collector.execute_srun")
def test_multiple_nodes(mock_srun, mock_sysinfo_output, mock_pidstat_output):
    """
    GIVEN a job running on 2 nodes: ["nid001", "nid002"]
    WHEN collect_node_stats is called
    THEN return dict with exactly these keys and valid NodeStats for each
    """
    mock_srun.side_effect = [
        (True, mock_sysinfo_output, ""),
        (True, mock_pidstat_output, ""),
        (True, mock_sysinfo_output, ""),
        (True, mock_pidstat_output, ""),
    ]

    result = collect_node_stats(
        node_list=["nid001", "nid002"],
        pidstat_path="/usr/bin/pidstat",
        jobid="12345",
    )

    # Exact count and keys check
    assert len(result) == 2
    assert set(result.keys()) == {"nid001", "nid002"}

    # Verify both have valid structures
    assert "Summary" in result["nid001"]
    assert "Summary" in result["nid002"]
    assert result["nid001"]["Summary"]["Counts"]["Process_Count"] == 2
    assert result["nid002"]["Summary"]["Counts"]["Process_Count"] == 2


@patch("runscripts.CPMIP.monitor.pidstat.collector.execute_srun")
def test_empty_node_list(mock_srun):
    """
    GIVEN an empty node list
    WHEN collect_node_stats is called
    THEN return empty dict.
    """
    result = collect_node_stats(
        node_list=[], pidstat_path="/usr/bin/pidstat", jobid="12345"
    )
    assert result == {}


@patch("runscripts.CPMIP.monitor.pidstat.collector.execute_srun")
def test_cpu_normalization_with_tpc(
    mock_srun, mock_sysinfo_output, mock_pidstat_output
):
    """
    GIVEN pidstat output with:
      - Process 1234: CPU=30.50% -> (30.50/100)/4 = 0.07625 physical cores
      - Process 5678: CPU=12.00% -> (12.00/100)/4 = 0.03 physical cores
    AND TPC=4 (4 threads per physical core)
    WHEN collect_single_node calculates CPU usage
    THEN Total_Cpu_Physical_Cores is exactly 0.106 (rounded from 0.10625)
    """
    mock_srun.side_effect = [
        (True, mock_sysinfo_output, ""),
        (True, mock_pidstat_output, ""),
    ]

    result = collect_single_node(
        node_name="nid001",
        pidstat_path="/usr/bin/pidstat",
        jobid="12345",
        threads_per_core=4,
    )

    # Exact calculation:
    # Process 1: 30.50% / 100 / 4 = 0.07625
    # Process 2: 12.00% / 100 / 4 = 0.03
    # Sum: 0.10625, rounded to 2 decimals = 0.11
    assert result["Summary"]["Cpu_Related"]["Total_Cpu_Physical_Cores"] == 0.11


@patch("runscripts.CPMIP.monitor.pidstat.collector.execute_srun")
def test_zero_memory_limit(mock_srun, mock_sysinfo_output, mock_pidstat_output):
    """
    GIVEN job_mem_limit_bytes=0 (unlimited memory)
    WHEN collect_single_node calculates memory percentages
    THEN Job_Memory_Of_Job_Limit_Percent is exactly 0.0 for summary and all processes
    """
    mock_srun.side_effect = [
        (True, mock_sysinfo_output, ""),
        (True, mock_pidstat_output, ""),
    ]

    result = collect_single_node(
        node_name="nid001",
        pidstat_path="/usr/bin/pidstat",
        jobid="12345",
        job_mem_limit_bytes=0,
    )

    # Exact check - must be 0.0 for unlimited jobs
    assert result["Summary"]["Memory_Related"]["Job_Memory_Of_Job_Limit_Percent"] == 0.0

    # Verify all processes also have 0.0
    for process in result["Processes"]:
        assert process["Memory_Related"]["Memory_Percent_Of_Job_Limit"] == 0.0
