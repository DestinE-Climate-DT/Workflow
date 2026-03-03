"""Unit tests for monitor-specific converter utilities.

Tests conversion functions used in the monitor module for parsing
SLURM output with size/count suffixes and TPC conversions.
"""

import pytest

from runscripts.CPMIP.monitor.utils.converters import (
    convert_to_int,
    convert_to_float,
    convert_size_to_bytes,
    convert_to_physical_cores,
)


class TestConvertToInt:
    """Test suite for convert_to_int with SLURM binary units."""

    @pytest.mark.parametrize(
        "value,expected",
        [
            # Basic integers
            ("42", 42),
            ("0", 0),
            (123, 123),
            # Base-1024 suffixes
            ("512K", 512 * 1024),
            ("4M", 4 * 1024**2),
            ("8G", 8 * 1024**3),
            ("1T", 1 * 1024**4),
            # Lowercase suffixes
            ("256k", 256 * 1024),
            # Decimal values (truncated)
            ("1.5M", int(1.5 * 1024**2)),
            # Whitespace handling
            ("  512M  ", 512 * 1024**2),
        ],
    )
    def test_convert_to_int_success(self, value, expected):
        """
        GIVEN valid integer string with optional suffixes
        WHEN convert_to_int is called
        THEN return integer value.
        """
        assert convert_to_int(value) == expected

    @pytest.mark.parametrize(
        "value,default,expected",
        [
            (None, 0, 0),
            ("", 0, 0),
            ("Unknown", 0, 0),
            ("invalid", 42, 42),
            ("N/A", 999, 999),
        ],
    )
    def test_convert_to_int_with_defaults(self, value, default, expected):
        """
        GIVEN invalid value and default provided
        WHEN convert_to_int is called
        THEN return default value.
        """
        assert convert_to_int(value, default) == expected


class TestConvertToFloat:
    """Test suite for convert_to_float with SLURM binary units."""

    @pytest.mark.parametrize(
        "value,expected",
        [
            ("3.14", 3.14),
            ("0.0", 0.0),
            (1.5, 1.5),
            ("0.5M", 0.5 * 1024**2),
            ("1.5G", 1.5 * 1024**3),
            ("100", 100.0),
            ("512K", 512 * 1024.0),
        ],
    )
    def test_convert_to_float_success(self, value, expected):
        """
        GIVEN valid float string with optional suffixes
        WHEN convert_to_float is called
        THEN return float value.
        """
        assert convert_to_float(value) == pytest.approx(expected)

    @pytest.mark.parametrize(
        "value,default,expected",
        [
            (None, 0.0, 0.0),
            ("", 0.0, 0.0),
            ("Unknown", 1.5, 1.5),
            ("invalid", 99.9, 99.9),
        ],
    )
    def test_convert_to_float_with_defaults(self, value, default, expected):
        """
        GIVEN invalid value and default provided
        WHEN convert_to_float is called
        THEN return default value.
        """
        assert convert_to_float(value, default) == pytest.approx(expected)


class TestConvertSizeToBytes:
    """Test suite for convert_size_to_bytes with regex parsing."""

    @pytest.mark.parametrize(
        "size_str,expected",
        [
            ("512M", 512 * 1024**2),
            ("2G", 2 * 1024**3),
            ("4096K", 4096 * 1024),
            ("1T", 1 * 1024**4),
            ("1024", 1024),
            ("0", 0),
            ("  512M  ", 512 * 1024**2),
            ("1.5G", int(1.5 * 1024**3)),
        ],
    )
    def test_convert_size_to_bytes_valid(self, size_str, expected):
        """
        GIVEN size string with unit (K/M/G/T)
        WHEN convert_size_to_bytes is called
        THEN convert to bytes correctly.
        """
        assert convert_size_to_bytes(size_str) == expected

    @pytest.mark.parametrize(
        "size_str,expected",
        [
            ("", 0),
            (None, 0),
            ("XYZ", 0),
        ],
    )
    def test_convert_size_to_bytes_invalid(self, size_str, expected):
        """
        GIVEN invalid format string
        WHEN convert_size_to_bytes is called
        THEN return 0.
        """
        assert convert_size_to_bytes(size_str) == expected


class TestConvertToPhysicalCores:
    """Test suite for TPC-based logical → physical core conversion."""

    @pytest.mark.parametrize(
        "logical,tpc,expected",
        [
            (128, 2, 64),  # Hyperthreading enabled
            (64, 1, 64),  # SMT disabled
            (0, 2, 1),  # Zero cores → minimum 1
            (127, 2, 63),  # Odd number
            (4096, 2, 2048),  # Large values
            # Real-world scenarios
            (128, 2, 64),  # LUMI-C node
            (48, 1, 48),  # MareNostrum node
        ],
    )
    def test_convert_to_physical_cores_valid(self, logical, tpc, expected):
        """
        GIVEN logical cores and valid TPC
        WHEN convert_to_physical_cores is called
        THEN return logical / TPC with floor division.
        """
        assert convert_to_physical_cores(logical, tpc) == expected

    def test_convert_to_physical_cores_zero_tpc(self):
        """
        GIVEN TPC is 0 or invalid
        WHEN convert_to_physical_cores is called
        THEN return logical count.
        """
        result = convert_to_physical_cores(128, 0)
        assert result == 128
