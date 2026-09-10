"""
Unit tests for pidstat parser module.

Tests the pure parsing functionality - extracting raw data from pidstat output
without any calculations, normalizations, or business logic.

Architecture:
    Parser → extracts raw data (strings, ints, floats as-is)
    No TPC, no memory limits, no calculations
"""

import pytest

from runscripts.CPMIP.monitor.pidstat.parser import (
    parse_pidstat_line,
    parse_pidstat_output,
    filter_kernel_process,
)


class TestParsePidstatLine:
    """Test suite for parsing single pidstat output lines."""

    def test_parse_valid_line_extracts_all_fields(self):
        """
        GIVEN a valid pidstat line with all 17+ fields
        WHEN parse_pidstat_line is called
        THEN exactly these values are extracted:
          - pid="3318117", uid="6132", command="python"
          - cpu_total_pct=16.39, cpu_user_pct=10.66, cpu_system_pct=5.74
          - rss_kb=38284, vss_kb=39872, mem_pct=0.01
          - minflt_per_sec=132.79, cswch_per_sec=213.11
        """
        line = "09:18:36  6132  3318117  10.66  5.74  0.00  0.00  16.39  70  132.79  0.00  39872  38284  0.01  213.11  0.00  python"

        result = parse_pidstat_line(line)

        # Exact value checks - not just "presence"
        assert result["pid"] == "3318117"
        assert result["uid"] == "6132"
        assert result["command"] == "python"
        assert result["time"] == "09:18:36"
        assert result["cpu_total_pct"] == 16.39
        assert result["cpu_user_pct"] == 10.66
        assert result["cpu_system_pct"] == 5.74
        assert result["cpu_guest_pct"] == 0.0
        assert result["cpu_wait_pct"] == 0.0
        assert result["cpu_processor_id"] == "70"
        assert result["rss_kb"] == 38284
        assert result["vss_kb"] == 39872
        assert result["mem_pct"] == 0.01
        assert result["minflt_per_sec"] == 132.79
        assert result["majflt_per_sec"] == 0.0
        assert result["cswch_per_sec"] == 213.11
        assert result["nvcswch_per_sec"] == 0.0

    def test_parse_line_with_multi_word_command(self):
        """
        GIVEN a pidstat line with multi-word command
        WHEN parsed
        THEN command captures all words after column 16
        """
        line = "09:18:36  6132  12345  1.0  2.0  0.0  0.0  3.0  0  10.0  0.0  1024  512  0.1  5.0  0.0  python my_script.py --arg value"

        result = parse_pidstat_line(line)

        assert result["command"] == "python my_script.py --arg value"

    @pytest.mark.parametrize(
        "invalid_line",
        [
            "",  # Empty line
            "# Header line",  # Comment
            "Linux 5.10.0 (hostname)",  # Header
            "Average:  UID  PID",  # Summary line
            "09:18:36  6132",  # Too few columns
        ],
    )
    def test_parse_invalid_lines_returns_empty_dict(self, invalid_line: str):
        """
        GIVEN invalid or header lines
        WHEN parse_pidstat_line is called
        THEN empty dict is returned
        """
        result = parse_pidstat_line(invalid_line)

        assert result == {}

    def test_parse_line_with_zero_values(self):
        """
        GIVEN a pidstat line with all zero metrics
        WHEN parsed
        THEN zeros are preserved as-is
        """
        line = "09:18:36  0  999  0.00  0.00  0.00  0.00  0.00  0  0.00  0.00  0  0  0.00  0.00  0.00  idle"

        result = parse_pidstat_line(line)

        assert result["cpu_total_pct"] == 0.0
        assert result["rss_kb"] == 0
        assert result["mem_pct"] == 0.0

    def test_parse_line_handles_malformed_numbers_gracefully(self):
        """
        GIVEN a line with malformed numeric values
        WHEN parsed with exception handling
        THEN returns empty dict (skip malformed lines)
        """
        line = "09:18:36  6132  BADPID  10.66  5.74  0.00  0.00  16.39  70  132.79  0.00  39872  38284  0.01  213.11  0.00  python"

        result = parse_pidstat_line(line)

        assert result == {}


class TestParsePidstatOutput:
    """Test suite for parsing complete pidstat command output."""

    def test_parse_output_with_multiple_processes(self):
        """
        GIVEN pidstat output with exactly 2 process lines
        WHEN parse_pidstat_output is called
        THEN return list with exactly 2 dicts with correct PIDs and commands
        """
        output = """Linux 5.10.0 (nid001) 	11/18/2025
# Time        UID       PID    %usr %system  %guest   %wait    %CPU   CPU  minflt/s  majflt/s     VSZ      RSS   %MEM  cswch/s nvcswch/s  Command
09:18:36        0      1234    5.0    2.0     0.0     0.0     7.0     0     10.0      0.0    1024      512    0.1     5.0      0.0  process1
09:18:36        0      5678    3.0    1.0     0.0     0.0     4.0     1     20.0      0.0    2048     1024    0.2     3.0      0.0  process2
"""

        result = parse_pidstat_output(output)

        # Exact count and verification
        assert len(result) == 2

        # First process exact values
        assert result[0]["pid"] == "1234"
        assert result[0]["command"] == "process1"
        assert result[0]["cpu_total_pct"] == 7.0
        assert result[0]["rss_kb"] == 512

        # Second process exact values
        assert result[1]["pid"] == "5678"
        assert result[1]["command"] == "process2"
        assert result[1]["cpu_total_pct"] == 4.0
        assert result[1]["rss_kb"] == 1024

    def test_parse_empty_output_returns_empty_list(self):
        """
        GIVEN empty pidstat output
        WHEN parsed
        THEN empty list is returned
        """
        result = parse_pidstat_output("")

        assert result == []

    def test_parse_output_skips_header_and_comments(self):
        """
        GIVEN output with headers and comment lines
        WHEN parsed
        THEN only valid data lines are extracted
        """
        output = """# This is a comment
Linux 5.10.0 (hostname)
Average:      UID       PID    %usr
09:18:36        0      1234    5.0    2.0     0.0     0.0     7.0     0     10.0      0.0    1024      512    0.1     5.0      0.0  valid
"""

        result = parse_pidstat_output(output)

        assert len(result) == 1
        assert result[0]["pid"] == "1234"


class TestFilterKernelProcess:
    """Test suite for kernel process filtering."""

    @pytest.mark.parametrize(
        "kernel_command,expected",
        [
            ("[kworker/0:1]", True),
            ("[migration/0]", True),
            ("[ksoftirqd/0]", True),
            ("python my_script.py", False),
            ("./run.sh", False),
            ("kworker_thread", True),  # Contains kernel pattern
            ("migration_helper", True),  # Contains kernel pattern
        ],
    )
    def test_filter_identifies_kernel_processes(
        self, kernel_command: str, expected: bool
    ):
        """
        GIVEN various process command strings
        WHEN filter_kernel_process is called
        THEN correct identification of kernel vs user processes
        """
        result = filter_kernel_process(kernel_command)

        assert (
            result == expected
        ), f"Command '{kernel_command}' should be filtered={expected}"

    def test_filter_handles_empty_command(self):
        """
        GIVEN empty command
        WHEN filtered
        THEN returns False (not a kernel process)
        """
        assert not filter_kernel_process("")


# Integration test - parser + real-like data
class TestParserIntegration:
    """Integration tests with realistic pidstat output patterns."""

    def test_parse_realistic_pidstat_output_end_to_end(self):
        """
        GIVEN realistic pidstat output from HPC node with 3 processes
        WHEN parsed completely
        THEN all processes extracted with exact raw values:
          - Process 3318117: python, CPU=16.39%, RSS=38284 KB
          - Process 1234: [kworker/0:1] (kernel), CPU=0.15%, RSS=512 KB
          - Process 3318118: python3, CPU=7.50%, RSS=18432 KB
        """
        output = """Linux 5.10.0 (nid001234) 	11/18/2025 	_x86_64_	(112 CPU)

# Time        UID       PID    %usr %system  %guest   %wait    %CPU   CPU  minflt/s  majflt/s     VSZ      RSS   %MEM  cswch/s nvcswch/s  Command
09:18:36     6132   3318117   10.66    5.74    0.00    0.00   16.39    70    132.79      0.00    39872    38284   0.01   213.11      0.00  python
09:18:36        0      1234    0.10    0.05    0.00    0.00    0.15     0      1.00      0.00     1024      512   0.00     2.00      0.00  [kworker/0:1]
09:18:36     6132   3318118    5.20    2.30    0.00    0.00    7.50    71     50.00      0.00    20480    18432   0.01   100.00      0.00  python3
"""

        processes = parse_pidstat_output(output)

        # Exact count
        assert len(processes) == 3

        # First process - exact values
        assert processes[0]["pid"] == "3318117"
        assert processes[0]["uid"] == "6132"
        assert processes[0]["cpu_total_pct"] == 16.39
        assert processes[0]["rss_kb"] == 38284
        assert processes[0]["command"] == "python"
        assert processes[0]["cswch_per_sec"] == 213.11

        # Second process - kernel process
        assert processes[1]["pid"] == "1234"
        assert processes[1]["command"] == "[kworker/0:1]"
        assert filter_kernel_process(processes[1]["command"]) is True
        assert processes[1]["cpu_total_pct"] == 0.15

        # Third process - exact values
        assert processes[2]["pid"] == "3318118"
        assert processes[2]["cpu_total_pct"] == 7.50
        assert processes[2]["rss_kb"] == 18432
        assert processes[2]["cswch_per_sec"] == 100.0

    def test_parse_real_production_pidstat_output(self, real_pidstat_output):
        """
        GIVEN real pidstat output from production glogin4 node
        WHEN parsed
        THEN exactly 39 kernel processes are extracted with specific properties:
          - First process: PID=17, command="ksoftirqd/0", CPU=0.0%, cswch=11.90/s
          - Second process: PID=18, command="rcu_preempt", CPU=0.79%, cswch=234.13/s
          - All processes: UID=0, RSS=0, VSS=0, MEM=0.0%
          - All processes: identified as kernel processes by filter
          - CPU IDs range: 0 to 125 (126 cores)
        """
        processes = parse_pidstat_output(real_pidstat_output)

        # Exact count
        assert len(processes) == 39

        # First process - exact values
        first_process = processes[0]
        assert first_process["pid"] == "17"
        assert first_process["uid"] == "0"
        assert first_process["command"] == "ksoftirqd/0"
        assert first_process["cpu_total_pct"] == 0.0
        assert first_process["cpu_user_pct"] == 0.0
        assert first_process["cpu_system_pct"] == 0.0
        assert first_process["rss_kb"] == 0
        assert first_process["vss_kb"] == 0
        assert first_process["mem_pct"] == 0.0
        assert first_process["cswch_per_sec"] == 11.90
        assert first_process["nvcswch_per_sec"] == 0.0

        # Second process - exact values
        rcu_process = processes[1]
        assert rcu_process["pid"] == "18"
        assert rcu_process["command"] == "rcu_preempt"
        assert rcu_process["cpu_total_pct"] == 0.79
        assert rcu_process["cpu_user_pct"] == 0.0
        assert rcu_process["cpu_system_pct"] == 0.79
        assert rcu_process["cswch_per_sec"] == 234.13
        assert rcu_process["nvcswch_per_sec"] == 0.0

        # All processes verification
        for process in processes:
            # All should be kernel processes
            assert filter_kernel_process(process["command"]) is True
            # All should be owned by root
            assert process["uid"] == "0"
            # All should have zero memory
            assert process["rss_kb"] == 0
            assert process["vss_kb"] == 0

        # CPU ID range verification
        cpu_ids = [int(p["cpu_processor_id"]) for p in processes]
        assert min(cpu_ids) == 0
        assert max(cpu_ids) == 125
