from __future__ import annotations

import time
from pathlib import Path


from wftools.autosubmit.constants import ERROR_FILE_CAP
from wftools.autosubmit.filesystem import (
    find_job_err,
    get_job_duration,
    parse_jobs_status_log,
)
from wftools.domain.models import SlurmMetadata


class TestFindJobErr:
    def test_latest(self, tmp_path: Path) -> None:
        """When multiple .err files exist, the newest by mtime is returned."""
        old = tmp_path / "a006_SIM.20260101000000.err"
        old.write_text("old error content")

        # Ensure a measurable mtime gap
        time.sleep(0.05)

        new = tmp_path / "a006_SIM.20260102000000.err"
        new.write_text("new error content")

        result = find_job_err(tmp_path, "a006_SIM")
        assert result is not None
        assert "new error content" in result

    def test_missing_dir(self, tmp_path: Path) -> None:
        """Non-existent directory returns None."""
        missing = tmp_path / "nonexistent"
        assert find_job_err(missing, "a006_SIM") is None

    def test_no_match(self, tmp_path: Path) -> None:
        """Existing directory with no matching files returns None."""
        (tmp_path / "other_job.20260101.err").write_text("irrelevant")
        assert find_job_err(tmp_path, "a006_SIM") is None

    def test_truncation(self, tmp_path: Path) -> None:
        """Files larger than ERROR_FILE_CAP are truncated with a prefix."""
        big_content = "X" * (ERROR_FILE_CAP + 1000)
        err_file = tmp_path / "a006_SIM.20260101000000.err"
        err_file.write_text(big_content)

        result = find_job_err(tmp_path, "a006_SIM")
        assert result is not None
        assert result.startswith("... [truncated] ...\n")
        # The truncated content should be the tail portion
        # Total length: prefix + ERROR_FILE_CAP
        body = result[len("... [truncated] ...\n") :]
        assert len(body) == ERROR_FILE_CAP


class TestGetJobDuration:
    def test_normal(self, tmp_path: Path) -> None:
        """STAT file with two timestamps returns their difference."""
        stat = tmp_path / "a006_SIM_STAT"
        stat.write_text("1000.0\n1120.5\n")

        result = get_job_duration(tmp_path, "a006_SIM")
        assert result is not None
        assert abs(result - 120.5) < 0.01

    def test_single_timestamp(self, tmp_path: Path) -> None:
        """Only one timestamp returns None."""
        stat = tmp_path / "a006_SIM_STAT"
        stat.write_text("1000.0\n")

        assert get_job_duration(tmp_path, "a006_SIM") is None

    def test_missing(self, tmp_path: Path) -> None:
        """No STAT file returns None."""
        assert get_job_duration(tmp_path, "a006_SIM") is None

    def test_missing_dir(self, tmp_path: Path) -> None:
        """Non-existent directory returns None."""
        missing = tmp_path / "nonexistent"
        assert get_job_duration(missing, "a006_SIM") is None

    def test_three_timestamps(self, tmp_path: Path) -> None:
        """Multiple timestamps: last - first."""
        stat = tmp_path / "a006_SIM_STAT"
        stat.write_text("100.0\n200.0\n350.0\n")

        result = get_job_duration(tmp_path, "a006_SIM")
        assert result is not None
        assert abs(result - 250.0) < 0.01


class TestParseJobsStatusLog:
    def test_basic(self, tmp_path: Path) -> None:
        """Parse sample log files and verify metadata extraction.

        Real Autosubmit logs use fixed-width columns where the job name
        and numeric job ID run together without whitespace.
        """
        failed_log = tmp_path / "jobs_failed_status.log"
        failed_log.write_text(
            "JobName  JobId  Status  Platform  Queue\n"
            "a006_19900101_fc0_1_SIM12345   FAILED  lumi    gpu\n"
        )

        active_log = tmp_path / "jobs_active_status.log"
        active_log.write_text(
            "JobName  JobId  Status  Platform  Queue\n"
            "a006_19900101_fc0_2_SIM12346   COMPLETED  lumi    gpu\n"
        )

        result = parse_jobs_status_log(tmp_path, "a006")
        assert len(result) == 2

        sim1 = result["a006_19900101_fc0_1_SIM"]
        assert isinstance(sim1, SlurmMetadata)
        assert sim1.slurm_id == "12345"
        assert sim1.platform == "lumi"
        assert sim1.queue == "gpu"

        sim2 = result["a006_19900101_fc0_2_SIM"]
        assert sim2.slurm_id == "12346"
        assert sim2.platform == "lumi"

    def test_missing_files(self, tmp_path: Path) -> None:
        """Missing log files produce empty dict (no crash)."""
        result = parse_jobs_status_log(tmp_path, "a006")
        assert result == {}

    def test_empty_log(self, tmp_path: Path) -> None:
        """Log with only a header produces empty dict."""
        log = tmp_path / "jobs_failed_status.log"
        log.write_text("JobName  JobId  Status  Platform  Queue\n")

        result = parse_jobs_status_log(tmp_path, "a006")
        assert result == {}
