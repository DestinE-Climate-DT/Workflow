from __future__ import annotations

from pathlib import Path

from wftools.domain.models import SlurmMetadata, TestCase, TestResult, TestSuite
from wftools.junit.reader import from_xml
from wftools.junit.writer import to_xml


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _roundtrip(suite: TestSuite, tmp_path: Path) -> TestSuite:
    """Write a suite to XML and read it back."""
    out = tmp_path / "report.xml"
    to_xml(suite, out)
    return from_xml(out)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestRoundTrip:
    """Write -> read round-trip preserves key fields."""

    def test_roundtrip(self, tmp_path: Path) -> None:
        original = TestSuite(
            name="tsuite",
            timestamp="2026-04-15T10:00:00",
            cases=[
                TestCase(
                    name="SIM",
                    passed=True,
                    classname="a006",
                    status="COMPLETED",
                    duration=100.0,
                    slurm=SlurmMetadata(
                        slurm_id="12345",
                        platform="lumi",
                        queue="standard",
                    ),
                ),
                TestCase(
                    name="POST",
                    passed=False,
                    classname="a006",
                    error="traceback here",
                    error_summary="ValueError: oops",
                ),
                TestCase(
                    name="DQC",
                    passed=False,
                    skipped=True,
                    classname="a006",
                    status="WAITING",
                ),
                TestResult(
                    name="smoke_check",
                    passed=True,
                ),
            ],
        )
        restored = _roundtrip(original, tmp_path)

        assert restored.name == "tsuite"
        assert restored.timestamp == "2026-04-15T10:00:00"
        assert restored.total == 4

        # Find cases by name for comparison
        by_name = {c.name: c for c in restored.cases}

        # Passed TestCase
        sim = by_name["SIM"]
        assert isinstance(sim, TestCase)
        assert sim.passed is True
        assert sim.classname == "a006"
        assert sim.duration == 100.0
        assert sim.slurm.slurm_id == "12345"
        assert sim.slurm.platform == "lumi"
        assert sim.slurm.queue == "standard"

        # Failed TestCase
        post = by_name["POST"]
        assert isinstance(post, TestCase)
        assert post.passed is False
        assert post.error_summary == "ValueError: oops"
        assert post.error == "traceback here"

        # Skipped TestCase
        dqc = by_name["DQC"]
        assert dqc.skipped is True
        assert dqc.passed is False

        # Coarse TestResult (no classname -> read back as TestResult)
        smoke = by_name["smoke_check"]
        assert smoke.passed is True


class TestReadPassedCase:
    """Read a simple passed testcase from XML."""

    def test_read_passed_case(self, tmp_path: Path) -> None:
        suite = TestSuite(
            timestamp="2026-04-15T10:00:00",
            cases=[
                TestCase(
                    name="LOCAL_SETUP",
                    passed=True,
                    classname="a006",
                    duration=5.0,
                ),
            ],
        )
        restored = _roundtrip(suite, tmp_path)

        assert len(restored.cases) == 1
        case = restored.cases[0]
        assert case.name == "LOCAL_SETUP"
        assert case.passed is True
        assert case.skipped is False


class TestReadFailedCase:
    """Read a failed testcase, including error summary."""

    def test_read_failed_case(self, tmp_path: Path) -> None:
        suite = TestSuite(
            timestamp="2026-04-15T10:00:00",
            cases=[
                TestCase(
                    name="SIM",
                    passed=False,
                    classname="a006",
                    error_summary="Segmentation fault",
                    error="full stack trace here",
                ),
            ],
        )
        restored = _roundtrip(suite, tmp_path)

        assert len(restored.cases) == 1
        case = restored.cases[0]
        assert case.passed is False
        assert case.skipped is False
        assert isinstance(case, TestCase)
        assert case.error_summary == "Segmentation fault"
        assert case.error == "full stack trace here"


class TestReadSkippedCase:
    """Read a skipped testcase."""

    def test_read_skipped_case(self, tmp_path: Path) -> None:
        suite = TestSuite(
            timestamp="2026-04-15T10:00:00",
            cases=[
                TestCase(
                    name="DQC",
                    passed=False,
                    skipped=True,
                    classname="a006",
                    status="WAITING",
                ),
            ],
        )
        restored = _roundtrip(suite, tmp_path)

        assert len(restored.cases) == 1
        case = restored.cases[0]
        assert case.skipped is True
        assert case.passed is False
        assert isinstance(case, TestCase)
        assert case.status == "WAITING"
