"""Tests for system parser module."""

import pytest

from runscripts.CPMIP.monitor.system.parser import (
    parse_lscpu_output,
    parse_free_output,
    parse_uptime_output,
)


class TestParseLscpuOutput:
    """Tests for parse_lscpu_output function."""

    @pytest.mark.parametrize(
        "tpc,cores_per_socket,sockets,expected_cores",
        [
            (2, 28, 2, 56),  # Standard hyperthreading
            (1, 32, 2, 64),  # No hyperthreading
            (4, 16, 2, 32),  # Quad-thread
            (2, 24, 1, 24),  # Single socket
        ],
    )
    def test_parse_lscpu_topology_variations(
        self, tpc, cores_per_socket, sockets, expected_cores
    ):
        """
        GIVEN lscpu output with various topology configurations
        WHEN parse_lscpu_output is called
        THEN calculate physical cores correctly.
        """
        lscpu_output = f"""Thread(s) per core:              {tpc}
Core(s) per socket:              {cores_per_socket}
Socket(s):                       {sockets}
Model name:                      Test CPU"""

        result = parse_lscpu_output(lscpu_output)

        assert result["Threads_Per_Core_Count"] == tpc
        assert result["Cores_Per_Socket_Count"] == cores_per_socket
        assert result["Sockets_Count"] == sockets
        assert result["Total_Physical_Cores_Count"] == expected_cores

    def test_parse_complete_lscpu(self):
        """
        GIVEN complete lscpu output with all topology fields
        WHEN parse_lscpu_output is called
        THEN extract all fields including model name.
        """
        lscpu_output = """Architecture:                    x86_64
CPU op-mode(s):                  32-bit, 64-bit
Thread(s) per core:              2
Core(s) per socket:              28
Socket(s):                       2
CPU(s):                          112
Model name:                      Intel(R) Xeon(R) Platinum 8380"""

        result = parse_lscpu_output(lscpu_output)

        assert result["Threads_Per_Core_Count"] == 2
        assert result["Cores_Per_Socket_Count"] == 28
        assert result["Sockets_Count"] == 2
        assert result["Model"] == "Intel(R) Xeon(R) Platinum 8380"
        assert result["Total_Physical_Cores_Count"] == 56

    def test_parse_lscpu_fallback_from_logical_cpus(self):
        """
        GIVEN lscpu missing cores/sockets but has CPU(s) and TPC
        WHEN parse_lscpu_output is called
        THEN fallback to calculating from logical CPUs.
        """
        lscpu_output = """Thread(s) per core:              2
CPU(s):                          112"""

        result = parse_lscpu_output(lscpu_output)

        assert result["Total_Physical_Cores_Count"] == 56  # 112 / 2

    @pytest.mark.parametrize(
        "lscpu_output",
        [
            "",  # Empty string
            "CPU_ERROR: command failed",  # Error marker
        ],
    )
    def test_parse_lscpu_empty_or_error(self, lscpu_output):
        """
        GIVEN empty or error lscpu output
        WHEN parse_lscpu_output is called
        THEN return empty dict.
        """
        result = parse_lscpu_output(lscpu_output)
        assert result == {}

    def test_parse_lscpu_missing_fields(self):
        """
        GIVEN lscpu output with missing fields
        WHEN parse_lscpu_output is called
        THEN still extract available fields.
        """
        lscpu_output = """Core(s) per socket:              28
Socket(s):                       2
Model name:                      Intel Xeon"""

        result = parse_lscpu_output(lscpu_output)

        assert "Threads_Per_Core_Count" not in result
        assert result["Cores_Per_Socket_Count"] == 28
        assert result["Sockets_Count"] == 2
        assert result["Model"] == "Intel Xeon"


class TestParseFreOutput:
    """Tests for parse_free_output function."""

    def test_parse_complete_free_output(self):
        """
        GIVEN complete free -k output
        WHEN parse_free_output is called
        THEN extract total, used, free, available memory in bytes.
        """
        free_output = """              total        used        free      shared  buff/cache   available
Mem:      263568128    78521856    66241280     2351232   118804992   180419200
Swap:      10485760           0    10485760"""

        result = parse_free_output(free_output)

        assert result is not None
        assert result["Total_Bytes"] == 263568128 * 1024
        assert result["Used_Bytes"] == 78521856 * 1024
        assert result["Free_Bytes"] == 66241280 * 1024
        assert result["Available_Bytes"] == 180419200 * 1024

    @pytest.mark.parametrize(
        "free_output",
        [
            "",  # Empty
            "MEM_ERROR: command failed",  # Error marker
            "              total        used\nSwap:      10485760           0    10485760",  # No Mem: line
            "              total        used\nMem:      100000000    50000000",  # Insufficient columns
        ],
    )
    def test_parse_free_invalid_inputs(self, free_output):
        """
        GIVEN invalid or incomplete free output
        WHEN parse_free_output is called
        THEN return None.
        """
        result = parse_free_output(free_output)
        assert result is None

    def test_parse_free_large_values(self):
        """
        GIVEN system with large memory (>1TB)
        WHEN parse_free_output is called
        THEN handle large numbers correctly.
        """
        free_output = """              total        used        free      shared  buff/cache   available
Mem:     1073741824   500000000   400000000     1000000   173741824   572000000"""

        result = parse_free_output(free_output)

        assert result is not None
        assert result["Total_Bytes"] == 1073741824 * 1024  # ~1TB


class TestParseUptimeOutput:
    """Tests for parse_uptime_output function."""

    @pytest.mark.parametrize(
        "uptime_output, expected_1, expected_5, expected_15",
        [
            (
                "10:23:45 up 5 days, 12:34,  2 users,  load average: 1.23, 2.34, 3.45",
                1.23,
                2.34,
                3.45,
            ),
            (
                "14:30:00 up 100 days,  5 users,  load average: 45.67, 50.12, 48.90",
                45.67,
                50.12,
                48.90,
            ),
            (
                "09:15:30 up 1 day,  1 user,  load average: 0.01, 0.05, 0.10",
                0.01,
                0.05,
                0.10,
            ),
            (
                "00:00:00 up 1 min,  0 users,  load average: 0.00, 0.00, 0.00",
                0.0,
                0.0,
                0.0,
            ),
        ],
    )
    def test_parse_uptime_various_loads(
        self, uptime_output, expected_1, expected_5, expected_15
    ):
        """
        GIVEN uptime output with various load averages
        WHEN parse_uptime_output is called
        THEN extract load averages correctly.
        """
        result = parse_uptime_output(uptime_output)

        assert result is not None
        assert result["Min_1"] == pytest.approx(expected_1)
        assert result["Min_5"] == pytest.approx(expected_5)
        assert result["Min_15"] == pytest.approx(expected_15)

    @pytest.mark.parametrize(
        "uptime_output",
        [
            "",  # Empty
            "10:23:45 up 5 days, 12:34,  2 users",  # No load average
            "10:23:45 up 5 days,  load average: abc, def, ghi",  # Malformed
        ],
    )
    def test_parse_uptime_invalid_inputs(self, uptime_output):
        """
        GIVEN invalid or incomplete uptime output
        WHEN parse_uptime_output is called
        THEN return None or handle gracefully.
        """
        result = parse_uptime_output(uptime_output)
        assert result is None or all(v == 0.0 for v in result.values())
