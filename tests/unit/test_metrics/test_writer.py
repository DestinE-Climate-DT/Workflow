from __future__ import annotations

from pathlib import Path

from wftools.domain.models import TestCase, TestResult, TestSuite
from wftools.metrics.writer import to_metrics


def job(name: str, **kwargs) -> TestCase:
    """A case as `report parse` builds it: an Autosubmit job."""
    return TestCase(name=name, full_job_name=f"a006_{name}", classname="a006", **kwargs)


class TestToMetricsBasic:
    """Correct counts for a mixed suite."""

    def test_to_metrics_basic(self, tmp_path: Path) -> None:
        suite = TestSuite(
            timestamp="2026-04-15T10:00:00",
            cases=[
                job("pass1", passed=True),
                job("pass2", passed=True),
                job("fail1", passed=False),
                job("skip1", passed=False, skipped=True),
            ],
        )
        out = tmp_path / "metrics.txt"
        to_metrics(suite, out)

        lines = out.read_text().splitlines()
        assert lines == [
            "completed_jobs 2",
            "failed_jobs 1",
            "skipped_jobs 1",
            "total_jobs 4",
        ]


class TestToMetricsPhaseCases:
    """Phase-level cases are not jobs and must not inflate the counts."""

    def test_phase_cases_excluded(self, tmp_path: Path) -> None:
        suite = TestSuite(
            timestamp="2026-04-15T10:00:00",
            cases=[
                job("SIM", passed=True),
                # `report add`, with and without --classname.
                TestCase(name="ifs-nemo-lowres_monitor", passed=True, classname="a006"),
                TestResult(name="ifs-nemo-lowres_resources", passed=True),
            ],
        )
        out = tmp_path / "metrics.txt"
        to_metrics(suite, out)

        lines = out.read_text().splitlines()
        assert lines == [
            "completed_jobs 1",
            "failed_jobs 0",
            "skipped_jobs 0",
            "total_jobs 1",
        ]

    def test_failing_phase_case_does_not_count_as_a_failed_job(
        self, tmp_path: Path
    ) -> None:
        suite = TestSuite(
            timestamp="2026-04-15T10:00:00",
            cases=[
                job("SIM", passed=True),
                TestCase(
                    name="ifs-nemo-lowres_monitor", passed=False, classname="a006"
                ),
            ],
        )
        out = tmp_path / "metrics.txt"
        to_metrics(suite, out)

        content = out.read_text()
        assert "failed_jobs 0" in content
        assert "total_jobs 1" in content


class TestToMetricsEmpty:
    """Empty suite produces all zeros."""

    def test_to_metrics_empty(self, tmp_path: Path) -> None:
        suite = TestSuite(timestamp="2026-04-15T10:00:00")
        out = tmp_path / "metrics.txt"
        to_metrics(suite, out)

        lines = out.read_text().splitlines()
        assert lines == [
            "completed_jobs 0",
            "failed_jobs 0",
            "skipped_jobs 0",
            "total_jobs 0",
        ]


class TestToMetricsFormat:
    """Verify exact line format: key<space>value, trailing newline."""

    def test_to_metrics_format(self, tmp_path: Path) -> None:
        suite = TestSuite(
            timestamp="2026-04-15T10:00:00",
            cases=[
                job("a", passed=True),
                job("b", passed=False),
                job("c", passed=False, skipped=True),
            ],
        )
        out = tmp_path / "metrics.txt"
        to_metrics(suite, out)

        content = out.read_text()
        # Must end with a newline
        assert content.endswith("\n")
        # Exactly 4 lines
        assert content.count("\n") == 4
        # Each line matches "word space digit(s)"
        for line in content.strip().splitlines():
            key, value = line.split(" ", 1)
            assert key.endswith("_jobs")
            int(value)  # must be parseable as int
