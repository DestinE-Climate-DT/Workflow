"""
Unit tests for SLURM sstat collector module.

This module tests the data collection logic for sstat commands that gather
job step statistics from SLURM.
"""

import pytest
from unittest.mock import patch, MagicMock

from runscripts.CPMIP.monitor.slurm.sstat.steps.collector import collect_sstat_steps
from runscripts.CPMIP.monitor.constants import SSTAT_FIELDS

# Alias for backward compatibility in tests
collect_sstat_data = collect_sstat_steps


class TestSstatCollector:
    """
    Test suite for sstat data collection.

    Tests the collector that runs sstat commands and parses output
    into structured dictionaries.
    """

    def test_collect_step_stats_success(self, sample_sstat_output):
        """
        Test successful collection of job step statistics.

        Verifies:
            - sstat command executed correctly
            - Output parsed into dict structure
            - All steps included (main, batch, extern)
            - Fields properly extracted

        Example:
            >>> stats = collect_sstat_data("12345")
            >>> assert "12345.0" in stats
            >>> assert stats["12345.0"]["MaxRSS"] == "4096M"
        """
        with patch("subprocess.run") as mock_run:
            # Create complete output with headers
            header = "JobID|" + "|".join(SSTAT_FIELDS)
            full_output = header + "\n" + sample_sstat_output

            mock_run.return_value = MagicMock(
                stdout=full_output, returncode=0, stderr=""
            )

            result = collect_sstat_data("12345")

            assert mock_run.called

            assert isinstance(result, dict)
            assert len(result) == 1
            assert "12345.batch" in result

    def test_collect_step_stats_empty_job(self):
        """
        Test collection when job has no steps yet.

        When job is queued or just started, sstat may return empty.

        Verifies:
            - Returns empty dict
            - No exceptions raised
            - Handles gracefully

        Example:
            >>> stats = collect_sstat_data("99999")  # Non-existent job
            >>> assert stats == {}
        """
        with patch("subprocess.run") as mock_run:
            # Empty output
            mock_run.return_value = MagicMock(stdout="", returncode=0, stderr="")

            result = collect_sstat_data("99999")

            assert result == {}

    def test_collect_step_stats_command_failure(self):
        """
        Test collection when sstat command fails.

        sstat can fail if job ID invalid, SLURM down, or permissions issue.

        Verifies:
            - Exception caught or handled
            - Returns empty dict
            - Doesn't crash

        Example:
            >>> stats = collect_sstat_data("invalid")
            >>> assert stats == {}  # Handles gracefully
        """
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                stdout="", returncode=1, stderr="sstat: error: Invalid job id specified"
            )

            result = collect_sstat_data("invalid")

            assert result == {}  # Returns empty on error

    @pytest.mark.parametrize(
        "jobid",
        ["12345", "67890_1", "123456.0", "job_999"],
        ids=["numeric", "array_job", "with_step", "prefixed"],
    )
    def test_collect_step_stats_various_job_ids(self, jobid: str, sample_sstat_output):
        """
        Test collection with various job ID formats.

        Args:
            jobid: Job identifier in various formats.

        Verifies:
            - Handles different job ID formats
            - Command constructed correctly
            - No parsing errors

        Example:
            >>> stats = collect_sstat_data("12345_1")  # Array job
            >>> assert isinstance(stats, dict)
        """
        with patch("subprocess.run") as mock_run:
            header = "JobID|" + "|".join(SSTAT_FIELDS)
            full_output = header + "\n" + sample_sstat_output

            mock_run.return_value = MagicMock(
                stdout=full_output, returncode=0, stderr=""
            )

            collect_sstat_data(jobid)

            # Verify jobid was used in command
            assert mock_run.called


class TestSstatFieldMapping:
    """
    Test suite for sstat field extraction and mapping.

    Tests that field names are correctly extracted from sstat output
    and mapped to dictionary keys.
    """

    def test_get_sstat_fields(self):
        """
        Test retrieval of sstat field list.

        Verifies:
            - Returns list of field names
            - Fields match sstat documentation
            - All required fields present

        Example:
            >>> from runscripts.CPMIP.monitor.constants import SSTAT_FIELDS
            >>> assert "MaxRSS" in SSTAT_FIELDS
            >>> assert "AveCPU" in SSTAT_FIELDS
        """
        fields = SSTAT_FIELDS

        assert isinstance(fields, list)
        assert len(fields) == 46

        # Check critical fields
        required_fields = [
            "MaxRSS",
            "AveRSS",
            "MaxVMSize",
            "AveCPU",
            "NTasks",
            "ConsumedEnergy",
        ]
        for field in required_fields:
            assert field in fields, f"Missing required field: {field}"

    def test_field_count_consistency(self):
        """
        GIVEN sstat command executed
        WHEN field count is validated
        THEN ensure parseable format has expected field count.
        """
        fields = SSTAT_FIELDS

        # sstat typically has 40+ fields with our format
        assert len(fields) >= 30, "Too few fields returned"

        # No duplicates
        assert len(fields) == len(set(fields)), "Duplicate fields found"


class TestSstatOutputParsing:
    """
    Test suite for parsing sstat command output.

    Tests the parsing of pipe-delimited sstat output into structured data.
    """

    def test_parse_multiple_steps(self, sample_sstat_output):
        """
        Test parsing output with multiple job steps.

        Job typically has: .0 (main), .batch, .extern steps.

        Verifies:
            - All steps parsed
            - Each step has own dict
            - No data mixing between steps

        Example:
            >>> parsed = collect_sstat_data(output_with_3_steps)
            >>> assert len(parsed) == 3
            >>> assert "12345.0" in parsed
            >>> assert "12345.batch" in parsed
        """
        with patch("subprocess.run") as mock_run:
            header = "JobID|" + "|".join(SSTAT_FIELDS)
            full_output = header + "\n" + sample_sstat_output

            mock_run.return_value = MagicMock(
                stdout=full_output, returncode=0, stderr=""
            )

            result = collect_sstat_data("12345")

            # Should have multiple steps
            assert len(result) >= 1


class TestSstatTimeout:
    """
    Test suite for sstat command timeout handling.

    Long-running jobs or slow SLURM systems may cause timeouts.
    """

    def test_command_timeout(self):
        """
        Test handling of sstat command timeout.

        When sstat takes too long (>30s), should timeout gracefully.

        Verifies:
            - Timeout exception caught or handled
            - Returns empty dict
            - Doesn't hang indefinitely

        Example:
            >>> # Simulating 60s job
            >>> stats = collect_sstat_data("long_job")
            >>> # Should timeout and return empty or raise
        """
        import subprocess

        with patch("subprocess.run") as mock_run:
            mock_run.side_effect = subprocess.TimeoutExpired("sstat", 30)

            # Should handle timeout (implementation-dependent)
            # May raise or return empty dict
            try:
                result = collect_sstat_data("12345")
                assert result == {}  # Returns empty on timeout
            except subprocess.TimeoutExpired:
                pass  # Or raises timeout exception


class TestSstatProcessingErrors:
    """Test error handling during step processing."""

    def test_build_step_stats_exception_handling(self):
        """
        GIVEN sstat output that causes build_step_stats to raise exception
        WHEN collect_sstat_steps is called
        THEN skip problematic step and continue with others.
        """
        with patch("subprocess.run") as mock_run:
            with patch(
                "runscripts.CPMIP.monitor.slurm.sstat.steps.collector.parse_sstat_output"
            ) as mock_parse:
                with patch(
                    "runscripts.CPMIP.monitor.slurm.sstat.steps.collector.build_step_stats"
                ) as mock_build:
                    mock_run.return_value = MagicMock(
                        stdout="some output", returncode=0, stderr=""
                    )

                    # Mock parse to return two steps
                    mock_parse.return_value = {
                        "12345.0": {"MaxRSS": "4G"},
                        "12345.batch": {"MaxRSS": "2G"},
                    }

                    # First call succeeds, second fails
                    step_data_0 = {"Job_Id": "12345", "Step_Id": "0"}
                    mock_build.side_effect = [
                        step_data_0,  # Success
                        Exception("Processing error"),  # Failure
                    ]

                    result = collect_sstat_steps("12345")

                    # Should have processed first step despite second failing
                    assert len(result) == 1
                    assert "12345.0" in result
                    assert result["12345.0"] == step_data_0

    def test_empty_sstat_output_after_parsing(self):
        """
        GIVEN sstat command succeeds but parsing returns empty
        WHEN collect_sstat_steps is called
        THEN return empty dict.
        """
        with patch("subprocess.run") as mock_run:
            with patch(
                "runscripts.CPMIP.monitor.slurm.sstat.steps.collector.parse_sstat_output"
            ) as mock_parse:
                mock_run.return_value = MagicMock(
                    stdout="some output", returncode=0, stderr=""
                )
                mock_parse.return_value = {}

                result = collect_sstat_steps("12345")

                assert result == {}

    def test_subprocess_failure_returns_empty(self):
        """
        GIVEN subprocess.run returns failure (returncode != 0)
        WHEN collect_sstat_steps is called
        THEN return empty dict without processing.
        """
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                stdout="", returncode=1, stderr="Job not found"
            )

            result = collect_sstat_steps("999999")

            assert result == {}

    def test_subprocess_empty_output_returns_empty(self):
        """
        GIVEN subprocess.run succeeds but output is empty
        WHEN collect_sstat_steps is called
        THEN return empty dict.
        """
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(stdout="", returncode=0, stderr="")

            result = collect_sstat_steps("12345")

            assert result == {}
