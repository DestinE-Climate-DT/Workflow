from __future__ import annotations

import pytest
from pydantic import ValidationError

from wftools.domain.models import SlurmMetadata, TestCase, TestResult, TestSuite


class TestTestResultConstruction:
    """Test TestResult construction and default values."""

    def test_minimal_construction(self):
        result = TestResult(name="smoke-test", passed=True)
        assert result.name == "smoke-test"
        assert result.passed is True
        assert result.skipped is False
        assert result.error is None
        assert result.timestamp  # non-empty, auto-generated

    def test_full_construction(self):
        result = TestResult(
            name="prepare",
            passed=False,
            skipped=False,
            timestamp="2026-04-15T10:00:00",
            error="Something went wrong",
        )
        assert result.name == "prepare"
        assert result.passed is False
        assert result.timestamp == "2026-04-15T10:00:00"
        assert result.error == "Something went wrong"

    def test_skipped_defaults_false(self):
        result = TestResult(name="check", passed=True)
        assert result.skipped is False

    def test_timestamp_auto_generated(self):
        r1 = TestResult(name="a", passed=True)
        r2 = TestResult(name="b", passed=False)
        # Both should have an ISO-formatted timestamp
        assert "T" in r1.timestamp
        assert "T" in r2.timestamp


class TestTestCaseWithSlurmMetadata:
    """Test TestCase construction including slurm metadata."""

    def test_default_slurm_metadata(self):
        tc = TestCase(name="SIM", passed=True)
        assert isinstance(tc.slurm, SlurmMetadata)
        assert tc.slurm.slurm_id is None
        assert tc.slurm.platform is None
        assert tc.slurm.queue is None

    def test_with_slurm_metadata(self):
        tc = TestCase(
            name="SIM [fc0_1]",
            passed=True,
            full_job_name="a006_19900101_fc0_1_SIM",
            classname="a006",
            status="COMPLETED",
            slurm=SlurmMetadata(
                slurm_id="123456",
                platform="lumi-gpu",
                queue="standard-g",
            ),
            duration=3600.5,
        )
        assert tc.slurm.slurm_id == "123456"
        assert tc.slurm.platform == "lumi-gpu"
        assert tc.slurm.queue == "standard-g"
        assert tc.duration == 3600.5
        assert tc.full_job_name == "a006_19900101_fc0_1_SIM"
        assert tc.classname == "a006"
        assert tc.status == "COMPLETED"

    def test_testcase_inherits_test_result_fields(self):
        tc = TestCase(
            name="LOCAL_SETUP",
            passed=False,
            error="segfault in libfoo",
        )
        assert tc.name == "LOCAL_SETUP"
        assert tc.passed is False
        assert tc.error == "segfault in libfoo"

    def test_error_summary_field(self):
        tc = TestCase(
            name="SIM",
            passed=False,
            error_summary="ValueError: bad input",
        )
        assert tc.error_summary == "ValueError: bad input"


class TestTestSuiteProperties:
    """Test TestSuite total/failures/skipped_count with mixed results."""

    def test_empty_suite(self):
        suite = TestSuite()
        assert suite.total == 0
        assert suite.failures == 0
        assert suite.skipped_count == 0

    def test_all_passed(self):
        suite = TestSuite(
            cases=[
                TestResult(name="a", passed=True),
                TestResult(name="b", passed=True),
                TestCase(name="c", passed=True),
            ]
        )
        assert suite.total == 3
        assert suite.failures == 0
        assert suite.skipped_count == 0

    def test_mixed_results(self):
        suite = TestSuite(
            cases=[
                TestResult(name="pass1", passed=True),
                TestResult(name="fail1", passed=False),
                TestCase(name="skip1", passed=False, skipped=True),
                TestCase(name="fail2", passed=False, status="FAILED"),
                TestResult(name="pass2", passed=True),
                TestCase(name="skip2", passed=False, skipped=True),
            ]
        )
        assert suite.total == 6
        assert suite.failures == 2  # fail1, fail2 (not skipped ones)
        assert suite.skipped_count == 2  # skip1, skip2

    def test_all_failed(self):
        suite = TestSuite(
            cases=[
                TestResult(name="f1", passed=False),
                TestResult(name="f2", passed=False),
            ]
        )
        assert suite.total == 2
        assert suite.failures == 2
        assert suite.skipped_count == 0

    def test_all_skipped(self):
        suite = TestSuite(
            cases=[
                TestResult(name="s1", passed=False, skipped=True),
                TestCase(name="s2", passed=False, skipped=True),
            ]
        )
        assert suite.total == 2
        assert suite.failures == 0
        assert suite.skipped_count == 2

    def test_suite_name_and_timestamp(self):
        suite = TestSuite()
        assert suite.name == "tsuite"
        assert "T" in suite.timestamp


class TestClassnameValidation:
    """Test classname (expid) validation: 4-char accepted, 3/5-char rejected."""

    def test_valid_4_char_classname(self):
        tc = TestCase(name="SIM", passed=True, classname="a006")
        assert tc.classname == "a006"

    def test_none_classname_accepted(self):
        tc = TestCase(name="SIM", passed=True, classname=None)
        assert tc.classname is None

    def test_3_char_classname_rejected(self):
        with pytest.raises(ValidationError, match="exactly 4 characters"):
            TestCase(name="SIM", passed=True, classname="abc")

    def test_5_char_classname_rejected(self):
        with pytest.raises(ValidationError, match="exactly 4 characters"):
            TestCase(name="SIM", passed=True, classname="abcde")

    def test_1_char_classname_rejected(self):
        with pytest.raises(ValidationError, match="exactly 4 characters"):
            TestCase(name="SIM", passed=True, classname="x")

    def test_empty_string_classname_rejected(self):
        with pytest.raises(ValidationError, match="exactly 4 characters"):
            TestCase(name="SIM", passed=True, classname="")


class TestSerializationRoundTrip:
    """Test model_dump_json / model_validate_json round-trip."""

    def test_test_result_round_trip(self):
        original = TestResult(
            name="smoke",
            passed=True,
            timestamp="2026-04-15T12:00:00",
            error="some error text",
        )
        json_str = original.model_dump_json()
        restored = TestResult.model_validate_json(json_str)
        assert restored.name == original.name
        assert restored.passed == original.passed
        assert restored.timestamp == original.timestamp
        assert restored.error == original.error

    def test_test_case_round_trip(self):
        original = TestCase(
            name="SIM [fc0_1]",
            passed=False,
            full_job_name="a006_19900101_fc0_1_SIM",
            classname="a006",
            error="Segmentation fault",
            error_summary="Segmentation fault",
            status="FAILED",
            slurm=SlurmMetadata(
                slurm_id="999999",
                platform="lumi-gpu",
                queue="standard-g",
            ),
            duration=1234.5,
        )
        json_str = original.model_dump_json()
        restored = TestCase.model_validate_json(json_str)
        assert restored.name == original.name
        assert restored.passed == original.passed
        assert restored.classname == original.classname
        assert restored.slurm.slurm_id == "999999"
        assert restored.slurm.platform == "lumi-gpu"
        assert restored.duration == 1234.5

    def test_test_suite_round_trip(self):
        suite = TestSuite(
            name="integration",
            timestamp="2026-04-15T14:00:00",
            cases=[
                TestResult(name="a", passed=True, timestamp="2026-04-15T14:00:01"),
                TestCase(
                    name="b",
                    passed=False,
                    classname="x001",
                    timestamp="2026-04-15T14:00:02",
                ),
            ],
        )
        json_str = suite.model_dump_json()
        restored = TestSuite.model_validate_json(json_str)
        assert restored.name == "integration"
        assert restored.timestamp == "2026-04-15T14:00:00"
        assert len(restored.cases) == 2
        assert restored.total == 2
        assert restored.failures == 1

    def test_slurm_metadata_round_trip(self):
        original = SlurmMetadata(
            slurm_id="42",
            platform="mn5",
            queue="acc",
        )
        json_str = original.model_dump_json()
        restored = SlurmMetadata.model_validate_json(json_str)
        assert restored.slurm_id == "42"
        assert restored.platform == "mn5"
        assert restored.queue == "acc"
