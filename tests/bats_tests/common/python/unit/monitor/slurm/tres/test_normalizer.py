"""Tests for TRES normalizer module."""

import pytest

from runscripts.CPMIP.monitor.slurm.tres.normalizer import normalize_tres_keys_and_units


class TestNormalizeTresKeysAndUnits:
    """Tests for normalize_tres_keys_and_units function."""

    @pytest.mark.parametrize(
        "cpu,tpc,expected",
        [
            ("128", 2, 64),  # TPC=2 divides logical cores
            ("64", 1, 64),  # TPC=1 no conversion
            ("256", 4, 64),  # TPC=4 divides logical cores
            ("128", None, 128),  # TPC=None defaults to 1
        ],
    )
    def test_normalize_cpu_count(self, cpu, tpc, expected):
        """Test CPU count normalization with various TPC values."""
        tres_dict = {"cpu": cpu}
        result = normalize_tres_keys_and_units(tres_dict, threads_per_core=tpc)
        assert result["Cpu_Count"] == expected

    @pytest.mark.parametrize(
        "duration,expected_seconds",
        [
            ("01:30:45", 5445.0),  # HH:MM:SS format
            ("2-05:30:15", 192615.0),  # D-HH:MM:SS format
        ],
    )
    def test_normalize_cpu_time_duration(self, duration, expected_seconds):
        """Test CPU time duration conversion from various formats."""
        tres_dict = {"cpu": duration}
        result = normalize_tres_keys_and_units(tres_dict)
        assert result["Cpu_Time_Seconds"] == expected_seconds

    @pytest.mark.parametrize(
        "mem_value,expected_bytes",
        [
            ("187G", 187 * 1024**3),
            ("512000M", 512000 * 1024**2),
            ("45678K", 45678 * 1024),
            ("1T", 1024**4),
            ("100g", 100 * 1024**3),  # case insensitive
            ("1.5G", int(1.5 * 1024**3)),  # fractional
        ],
    )
    def test_normalize_mem_sizes(self, mem_value, expected_bytes):
        """Test memory size conversion with K/M/G/T suffixes."""
        tres_dict = {"mem": mem_value}
        result = normalize_tres_keys_and_units(tres_dict)
        assert result["Mem_Bytes"] == expected_bytes

    def test_normalize_node_count(self):
        """
        GIVEN TRES with node=4
        WHEN normalize_tres_keys_and_units is called
        THEN convert to Node_Count integer.
        """
        tres_dict = {"node": "4"}
        result = normalize_tres_keys_and_units(tres_dict)

        assert result["Node_Count"] == 4

    def test_normalize_billing_with_tpc_2(self):
        """
        GIVEN TRES with billing=128 and TPC=2
        WHEN normalize_tres_keys_and_units is called
        THEN convert to PHYSICAL cores (128/2=64).
        """
        tres_dict = {"billing": "128"}
        result = normalize_tres_keys_and_units(tres_dict, threads_per_core=2)

        assert result["Billing_Count"] == 64

    def test_normalize_energy(self):
        """
        GIVEN TRES with energy value
        WHEN normalize_tres_keys_and_units is called
        THEN convert to Energy_Joules as float.
        """
        tres_dict = {"energy": "1234.56"}
        result = normalize_tres_keys_and_units(tres_dict)

        assert result["Energy_Joules"] == 1234.56

    def test_normalize_complete_allocation_tres(self):
        """
        GIVEN complete AllocTRES string
        WHEN normalize_tres_keys_and_units is called
        THEN normalize all fields correctly.
        """
        tres_dict = {"cpu": "128", "mem": "256G", "node": "4", "billing": "128"}
        result = normalize_tres_keys_and_units(tres_dict, threads_per_core=2)

        assert result["Cpu_Count"] == 64  # 128 / 2
        assert result["Mem_Bytes"] == 256 * 1024 * 1024 * 1024
        assert result["Node_Count"] == 4
        assert result["Billing_Count"] == 64  # 128 / 2

    def test_normalize_complete_usage_tres(self):
        """
        GIVEN complete usage TRES with durations
        WHEN normalize_tres_keys_and_units is called
        THEN normalize time and size fields.
        """
        tres_dict = {"cpu": "01:30:00", "mem": "100G", "energy": "5000"}
        result = normalize_tres_keys_and_units(tres_dict)

        assert result["Cpu_Time_Seconds"] == 5400.0  # 1.5 hours
        assert result["Mem_Bytes"] == 100 * 1024 * 1024 * 1024
        assert result["Energy_Joules"] == 5000.0

    def test_normalize_empty_dict(self):
        """
        GIVEN empty TRES dict
        WHEN normalize_tres_keys_and_units is called
        THEN return empty dict.
        """
        result = normalize_tres_keys_and_units({})
        assert result == {}

    def test_normalize_unknown_key_with_duration(self):
        """
        GIVEN TRES with unknown key containing duration
        WHEN normalize_tres_keys_and_units is called
        THEN infer as _Seconds and convert.
        """
        tres_dict = {"customtime": "00:45:30"}
        result = normalize_tres_keys_and_units(tres_dict)

        assert result["Customtime_Seconds"] == 2730.0  # 45*60 + 30

    def test_normalize_unknown_key_with_size(self):
        """
        GIVEN TRES with unknown key containing size
        WHEN normalize_tres_keys_and_units is called
        THEN infer as _Bytes and convert.
        """
        tres_dict = {"customsize": "50M"}
        result = normalize_tres_keys_and_units(tres_dict)

        assert result["Customsize_Bytes"] == 50 * 1024 * 1024

    def test_normalize_unknown_key_with_plain_number(self):
        """
        GIVEN TRES with unknown key containing plain number
        WHEN normalize_tres_keys_and_units is called
        THEN infer as _Bytes (matches bytes regex).
        """
        tres_dict = {"customcount": "42"}
        result = normalize_tres_keys_and_units(tres_dict)

        # Plain numbers match the bytes regex pattern
        assert result["Customcount_Bytes"] == 42

    def test_normalize_zero_values(self):
        """
        GIVEN TRES with zero values
        WHEN normalize_tres_keys_and_units is called
        THEN preserve zeros (CPU converts to min 1 physical core).
        """
        tres_dict = {"cpu": "0", "mem": "0", "node": "0"}
        result = normalize_tres_keys_and_units(tres_dict)

        # CPU "0" logical cores converts to minimum 1 physical core
        assert result["Cpu_Count"] == 1
        assert result["Mem_Bytes"] == 0
        assert result["Node_Count"] == 0
