"""
Unit tests for timestamp conversion utilities.

Tests for SLURM timestamp formatting and duration conversion.
"""

import pytest
from runscripts.CPMIP.monitor.utils.timestamps import (
    convert_duration_to_seconds,
    convert_slurm_timestamp,
)


class TestConvertDurationToSeconds:
    """Tests for convert_duration_to_seconds function."""

    @pytest.mark.parametrize(
        "duration, expected",
        [
            # Days-Hours:Minutes:Seconds format
            ("2-04:30:15", 189015.0),  # 2*86400 + 4*3600 + 30*60 + 15
            # Hours:Minutes:Seconds format
            ("04:30:15", 16215.0),
            # Minutes:Seconds format
            ("30:15", 1815.0),
            # Seconds only
            ("45", 45.0),
            # Decimal seconds
            ("1-00:00:30.5", 86430.5),
            # Edge cases
            ("N/A", 0.0),
            ("", 0.0),
            # Large values
            ("365-00:00:00", 31536000.0),
            # Whitespace handling
            ("  2-04:30:15  ", 189015.0),
        ],
    )
    def test_convert_duration_various_formats(self, duration, expected):
        """
        GIVEN duration in various formats (HH:MM:SS, D-HH:MM:SS, edge cases)
        WHEN convert_duration_to_seconds is called
        THEN convert to total seconds correctly.
        """
        result = convert_duration_to_seconds(duration)
        assert result == pytest.approx(expected, rel=1e-6)


class TestConvertSlurmTimestamp:
    """Tests for convert_slurm_timestamp function."""

    @pytest.mark.parametrize(
        "input_ts, expected",
        [
            # ISO format (already formatted)
            ("2025-10-30T15:30:59", "2025-10-30T15:30:59"),
            # Space separator
            ("2025-10-30 15:30:59", "2025-10-30T15:30:59"),
            # Edge cases
            ("N/A", "N/A"),
            ("Unknown", "N/A"),
            ("", "N/A"),
        ],
    )
    def test_convert_timestamp_formats(self, input_ts, expected):
        """
        GIVEN various timestamp formats
        WHEN convert_slurm_timestamp is called
        THEN convert to ISO format or handle edge cases.
        """
        result = convert_slurm_timestamp(input_ts)
        assert result == expected

    def test_convert_timestamp_with_timezone(self):
        """
        GIVEN timestamp with timezone
        WHEN convert_slurm_timestamp is called
        THEN handle timezone correctly.
        """
        timestamp = "2025-10-30T15:30:59Z"
        result = convert_slurm_timestamp(timestamp)
        assert result == "2025-10-30T15:30:59"


class TestTimestampIntegration:
    """Integration tests for timestamp utilities."""

    def test_duration_and_timestamp_together(self):
        """
        GIVEN both duration and timestamp conversions
        WHEN functions are called
        THEN maintain consistency.
        """
        elapsed = "2-04:30:15"
        start_time = "2025-10-28 10:00:00"

        seconds = convert_duration_to_seconds(elapsed)
        formatted_start = convert_slurm_timestamp(start_time)

        assert seconds == 189015.0
        assert formatted_start == "2025-10-28T10:00:00"

    @pytest.mark.parametrize(
        "duration, expected",
        [
            ("00:05:00", 300.0),  # Short: 5 minutes
            ("02:00:00", 7200.0),  # Medium: 2 hours
            ("7-00:00:00", 604800.0),  # Long: 7 days
        ],
    )
    def test_realistic_job_durations(self, duration, expected):
        """
        GIVEN realistic SLURM job durations
        WHEN convert_duration_to_seconds is called
        THEN convert accurately.
        """
        assert convert_duration_to_seconds(duration) == expected
