"""
Unit tests for pidstat builder module.

Tests the builder functionality - constructing TypedDicts from raw parsed data
with all normalizations, calculations, and business logic applied.

Architecture:
    Builder → normalizes data (KB→bytes, %→cores) + constructs TypedDicts
    Receives TPC, memory limits, applies business rules
"""

import pytest
from typing import Dict, Any

from runscripts.CPMIP.monitor.pidstat.builder import (
    build_process_entry,
    build_process_entries,
    build_node_summary,
    build_node_general_info,
    build_error_node_stats,
)


# Test Data Builders (Factory Pattern)
def create_raw_process(
    pid: str = "12345",
    cpu_total_pct: float = 10.0,
    rss_kb: int = 1024,
    vss_kb: int = 2048,
    mem_pct: float = 0.5,
    command: str = "python",
    **overrides,
) -> Dict[str, Any]:
    """
    Factory function to create raw process data dict.

    Mimics output from parser - raw values without normalization.
    """
    data = {
        "pid": pid,
        "uid": "1000",
        "time": "10:00:00",
        "command": command,
        "cpu_user_pct": cpu_total_pct * 0.6,
        "cpu_system_pct": cpu_total_pct * 0.4,
        "cpu_guest_pct": 0.0,
        "cpu_wait_pct": 0.0,
        "cpu_total_pct": cpu_total_pct,
        "cpu_processor_id": "0",
        "vss_kb": vss_kb,
        "rss_kb": rss_kb,
        "mem_pct": mem_pct,
        "minflt_per_sec": 100.0,
        "majflt_per_sec": 0.0,
        "cswch_per_sec": 50.0,
        "nvcswch_per_sec": 10.0,
    }
    data.update(overrides)
    return data


class TestBuildProcessEntry:
    """Test suite for building individual ProcessEntry TypedDicts."""

    def test_build_entry_normalizes_cpu_percentage_to_physical_cores(self):
        """
        GIVEN raw process with 20% CPU (logical cores)
        AND TPC=2 (Threads Per Core)
        WHEN build_process_entry is called
        THEN CPU is normalized to physical cores (20% / 100 / 2 = 0.1 cores)
        """

        raw = create_raw_process(cpu_total_pct=20.0)
        tpc = 2

        entry = build_process_entry(raw, threads_per_core=tpc, job_mem_limit_bytes=0)

        expected_cores = 20.0 / 100.0 / tpc  # 0.1 physical cores
        assert entry["Cpu_Related"]["Cpu_Physical_Cores"] == pytest.approx(
            expected_cores, abs=0.001
        )

    def test_build_entry_converts_memory_kb_to_bytes(self):
        """
        GIVEN raw process with RSS=1024 KB and VSS=2048 KB
        WHEN built
        THEN RSS is converted to 1,048,576 bytes and VSS to 2,097,152 bytes
        """

        raw = create_raw_process(rss_kb=1024, vss_kb=2048)

        entry = build_process_entry(raw, threads_per_core=1, job_mem_limit_bytes=0)

        # Exact verification - no fuzzy comparisons
        assert entry["Memory_Related"]["Rss_Bytes"] == 1_048_576  # 1024 * 1024
        assert entry["Memory_Related"]["Vss_Bytes"] == 2_097_152  # 2048 * 1024

    def test_build_entry_preserves_raw_memory_percentage(self):
        """
        GIVEN raw process with mem_pct=0.5 (from pidstat)
        WHEN built
        THEN Memory_Percent_Of_Node preserves the raw value from pidstat
        """

        raw = create_raw_process(rss_kb=1024, mem_pct=0.5)

        entry = build_process_entry(raw, threads_per_core=1, job_mem_limit_bytes=0)

        # The builder preserves the raw mem_pct from pidstat
        assert entry["Memory_Related"]["Memory_Percent_Of_Node"] == 0.5

    def test_build_entry_with_memory_limit_calculates_limit_percentage(self):
        """
        GIVEN process with RSS=512 KB (524,288 bytes)
        AND job memory limit = 1 MB (1,048,576 bytes)
        WHEN built
        THEN limit percentage is exactly 50.0%
        """

        raw = create_raw_process(rss_kb=512)
        limit_bytes = 1_048_576  # 1 MB in bytes

        entry = build_process_entry(
            raw,
            threads_per_core=1,
            job_mem_limit_bytes=limit_bytes,
        )

        # Exact calculation: (524,288 / 1,048,576) * 100 = 50.0
        assert entry["Memory_Related"]["Memory_Percent_Of_Job_Limit"] == 50.0

    def test_build_entry_without_memory_limit_sets_zero_limit_percentage(self):
        """
        GIVEN process data with job_mem_limit_bytes=0 (unlimited)
        WHEN built
        THEN Memory_Percent_Of_Job_Limit is exactly 0.0
        """

        raw = create_raw_process(rss_kb=512)

        entry = build_process_entry(raw, threads_per_core=1, job_mem_limit_bytes=0)

        # Exact check - must be 0.0, not just "close to zero"
        assert entry["Memory_Related"]["Memory_Percent_Of_Job_Limit"] == 0.0

    def test_build_entry_preserves_pid_uid_and_command(self):
        """
        GIVEN raw process with PID=9999, UID=1000, Command="my_app --flag"
        WHEN built
        THEN these exact values are preserved without modification
        """

        raw = create_raw_process(pid="9999", uid="1000", command="my_app --flag")

        entry = build_process_entry(raw, threads_per_core=1, job_mem_limit_bytes=0)

        # Exact string matching - not just presence
        assert entry["Pid"] == "9999"
        assert entry["Uid"] == "1000"
        assert entry["Command"] == "my_app --flag"

    @pytest.mark.parametrize(
        "tpc,cpu_pct,expected_cores",
        [
            (1, 100.0, 1.0),  # No SMT: 100% = 1 core
            (2, 100.0, 0.5),  # SMT: 100% = 0.5 physical cores
            (2, 200.0, 1.0),  # SMT: 200% = 1 physical core
            (2, 50.0, 0.25),  # SMT: 50% = 0.25 physical cores
            (4, 400.0, 1.0),  # Quad-thread: 400% = 1 physical core
        ],
    )
    def test_build_entry_cpu_normalization_with_various_tpc(
        self, tpc: int, cpu_pct: float, expected_cores: float
    ):
        """
        GIVEN various TPC values and CPU percentages
        WHEN process entry is built
        THEN CPU is exactly normalized to physical cores (formula: cpu_pct / 100 / TPC)
        """

        raw = create_raw_process(cpu_total_pct=cpu_pct)

        entry = build_process_entry(raw, threads_per_core=tpc, job_mem_limit_bytes=0)

        # Verify exact calculation with tight tolerance
        assert entry["Cpu_Related"]["Cpu_Physical_Cores"] == expected_cores


class TestBuildProcessEntries:
    """Test suite for building lists of ProcessEntry TypedDicts."""

    def test_build_entries_processes_all_raw_data(self):
        """
        GIVEN list of 3 raw process dicts with PIDs 1, 2, 3
        WHEN build_process_entries is called
        THEN exactly 3 ProcessEntry TypedDicts are returned with correct PIDs in order
        """

        raw_list = [
            create_raw_process(pid="1", cpu_total_pct=10.0),
            create_raw_process(pid="2", cpu_total_pct=20.0),
            create_raw_process(pid="3", cpu_total_pct=30.0),
        ]

        entries = build_process_entries(
            raw_list, threads_per_core=2, job_mem_limit_bytes=0
        )

        # Verify exact count and order
        assert len(entries) == 3
        assert entries[0]["Pid"] == "1"
        assert entries[1]["Pid"] == "2"
        assert entries[2]["Pid"] == "3"

    def test_build_entries_applies_normalizations_to_all(self):
        """
        GIVEN 2 raw processes with 100% and 200% CPU
        AND TPC=2
        WHEN built
        THEN first process has exactly 0.5 physical cores, second has exactly 1.0
        """

        raw_list = [
            create_raw_process(pid="1", cpu_total_pct=100.0),
            create_raw_process(pid="2", cpu_total_pct=200.0),
        ]

        entries = build_process_entries(
            raw_list, threads_per_core=2, job_mem_limit_bytes=0
        )

        # Exact values - formula: (cpu_pct / 100) / TPC
        assert entries[0]["Cpu_Related"]["Cpu_Physical_Cores"] == 0.5
        assert entries[1]["Cpu_Related"]["Cpu_Physical_Cores"] == 1.0


class TestBuildNodeSummary:
    """Test suite for building NodeSummary aggregations."""

    def test_build_summary_aggregates_total_cpu(self):
        """
        GIVEN 3 processes with CPU: 100%, 200%, 50% (TPC=2)
        WHEN node summary is built
        THEN Total_Cpu_Physical_Cores is exactly 1.75 (0.5 + 1.0 + 0.25)
        """
        # Arrange - Build real ProcessEntry TypedDicts
        raw_list = [
            create_raw_process(cpu_total_pct=100.0),  # = 0.5 physical cores
            create_raw_process(cpu_total_pct=200.0),  # = 1.0 physical cores
            create_raw_process(cpu_total_pct=50.0),  # = 0.25 physical cores
        ]
        processes = build_process_entries(
            raw_list, threads_per_core=2, job_mem_limit_bytes=0
        )

        summary = build_node_summary(processes, filtered_kernel_count=0)

        # Exact sum verification
        assert summary["Cpu_Related"]["Total_Cpu_Physical_Cores"] == 1.75

    def test_build_summary_aggregates_total_memory(self):
        """
        GIVEN processes with RSS: 1024 KB, 2048 KB, 3072 KB
        WHEN summarized
        THEN Total_Memory_Bytes is exactly 6,291,456 bytes (6 MB)
        """

        raw_list = [
            create_raw_process(rss_kb=1024),  # 1 MB = 1,048,576 bytes
            create_raw_process(rss_kb=2048),  # 2 MB = 2,097,152 bytes
            create_raw_process(rss_kb=3072),  # 3 MB = 3,145,728 bytes
        ]
        processes = build_process_entries(
            raw_list, threads_per_core=1, job_mem_limit_bytes=0
        )

        summary = build_node_summary(processes, filtered_kernel_count=0)

        # Exact sum: 1,048,576 + 2,097,152 + 3,145,728 = 6,291,456
        assert summary["Memory_Related"]["Total_Memory_Bytes"] == 6_291_456

    def test_build_summary_counts_processes(self):
        """
        GIVEN exactly 5 processes and filtered_kernel_count=2
        WHEN summarized
        THEN Process_Count is exactly 5 and Filtered_Kernel_Processes_Count is exactly 2
        """

        raw_list = [create_raw_process(pid=str(i)) for i in range(5)]
        processes = build_process_entries(
            raw_list, threads_per_core=1, job_mem_limit_bytes=0
        )

        summary = build_node_summary(processes, filtered_kernel_count=2)

        # Exact counts - not just "greater than zero"
        assert summary["Counts"]["Process_Count"] == 5
        assert summary["Counts"]["Filtered_Kernel_Processes_Count"] == 2


class TestBuildNodeGeneralInfo:
    """Test suite for building NodeGeneralInfo from system commands."""

    def test_build_general_info_extracts_cpu_count(self):
        """
        GIVEN lscpu output: CPU(s)=64, Thread(s) per core=2, Core(s) per socket=32, Socket(s)=1
        WHEN node general info is built
        THEN Total_Physical_Cores_Count is exactly 32 (Cores per socket * Sockets)
        """

        lscpu_output = """Architecture:        x86_64
CPU(s):              64
Thread(s) per core:  2
Core(s) per socket:  32
Socket(s):           1
"""
        load_output = "0.50 0.40 0.30"
        mem_output = "Mem: 65536000 10240000 50000000 0 5296000 55296000"

        info = build_node_general_info(lscpu_output, mem_output, load_output)

        # Exact verification: 32 cores/socket * 1 socket = 32 physical cores
        assert info["Cpu_Info"]["Total_Physical_Cores_Count"] == 32
        assert info["Cpu_Info"]["Threads_Per_Core_Count"] == 2

    def test_build_general_info_extracts_total_memory(self):
        """
        GIVEN free output with total memory = 65,536,000 KB
        WHEN built
        THEN Total_Bytes is exactly 67,108,864,000 bytes (65,536,000 * 1024)
        """

        lscpu_output = "CPU(s): 64"
        load_output = "0.50 0.40 0.30"
        mem_output = "Mem: 65536000 10240000 50000000 0 5296000 55296000"

        info = build_node_general_info(lscpu_output, mem_output, load_output)

        # Exact calculation: 65,536,000 KB * 1024 = 67,108,864,000 bytes
        assert info["Memory_Info"]["Total_Bytes"] == 67_108_864_000


class TestBuildErrorNodeStats:
    """Test suite for error state builders."""

    def test_build_error_stats_creates_empty_structure(self):
        """
        GIVEN node_name="node01" and error_message="Connection failed"
        WHEN error node stats is built
        THEN returns structure with all zeros and exact error message "node01: Connection failed"
        """

        error_stats = build_error_node_stats("node01", "Connection failed")

        # Verify exact zero values - not just "falsy"
        assert error_stats["Summary"]["Cpu_Related"]["Total_Cpu_Physical_Cores"] == 0.0
        assert error_stats["Summary"]["Memory_Related"]["Total_Memory_Bytes"] == 0
        assert error_stats["Summary"]["Counts"]["Process_Count"] == 0
        assert error_stats["Summary"]["Counts"]["Filtered_Kernel_Processes_Count"] == 0
        assert error_stats["Processes"] == []

        # Verify exact error message format
        assert error_stats["Node_General_Info"]["Status"] == "error"
        assert error_stats["Node_General_Info"]["Error"] == "node01: Connection failed"
