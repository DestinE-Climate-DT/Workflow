from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

from wftools.domain.models import SlurmMetadata, TestCase, TestResult, TestSuite
from wftools.junit.writer import to_xml


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _write_and_parse(suite: TestSuite, tmp_path: Path) -> ET.Element:
    """Write *suite* to XML and return the parsed root element."""
    out = tmp_path / "report.xml"
    to_xml(suite, out)
    return ET.parse(out).getroot()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestToXmlBasic:
    """Core structure: testsuite attributes, passed and failed cases."""

    def test_to_xml_basic(self, tmp_path: Path) -> None:
        suite = TestSuite(
            timestamp="2026-04-15T10:00:00",
            cases=[
                TestCase(
                    name="SIM",
                    passed=True,
                    classname="a006",
                    status="COMPLETED",
                ),
                TestCase(
                    name="POST",
                    passed=False,
                    classname="a006",
                    status="FAILED",
                    error_summary="Segfault",
                ),
            ],
        )
        root = _write_and_parse(suite, tmp_path)

        assert root.tag == "testsuite"
        assert root.get("name") == "tsuite"
        assert root.get("tests") == "2"
        assert root.get("failures") == "1"
        assert root.get("skipped") == "0"
        assert root.get("errors") == "0"
        assert root.get("timestamp") == "2026-04-15T10:00:00"

        testcases = root.findall("testcase")
        assert len(testcases) == 2

        # Passed case should have no failure or skipped children
        passed_tc = [tc for tc in testcases if tc.get("name") == "SIM"][0]
        assert passed_tc.find("failure") is None
        assert passed_tc.find("skipped") is None

        # Failed case should have a failure element
        failed_tc = [tc for tc in testcases if tc.get("name") == "POST"][0]
        failure = failed_tc.find("failure")
        assert failure is not None
        assert failure.get("message") == "Segfault"


class TestToXmlProperties:
    """Property elements from URL and SLURM metadata."""

    def test_to_xml_properties(self, tmp_path: Path) -> None:
        suite = TestSuite(
            timestamp="2026-04-15T10:00:00",
            cases=[
                TestCase(
                    name="SIM",
                    passed=True,
                    classname="a006",
                    slurm=SlurmMetadata(
                        slurm_id="99999",
                        platform="lumi-gpu",
                        queue="standard-g",
                    ),
                ),
            ],
        )
        root = _write_and_parse(suite, tmp_path)

        tc = root.find("testcase")
        props = tc.find("properties")
        assert props is not None

        prop_dict = {p.get("name"): p.get("value") for p in props.findall("property")}
        assert prop_dict["slurm_job_id"] == "99999"
        assert prop_dict["platform"] == "lumi-gpu"
        assert prop_dict["queue"] == "standard-g"


class TestToXmlFailureBody:
    """Failure body contains the error summary and last 50 lines of error."""

    def test_to_xml_failure_body(self, tmp_path: Path) -> None:
        # Build error content with 60 lines so "last 50" truncation applies
        error_lines = [f"line {i}: some trace output" for i in range(60)]
        error_content = "\n".join(error_lines)

        suite = TestSuite(
            timestamp="2026-04-15T10:00:00",
            cases=[
                TestCase(
                    name="SIM",
                    passed=False,
                    classname="a006",
                    status="FAILED",
                    error_summary="ValueError: bad input",
                    error=error_content,
                ),
            ],
        )
        root = _write_and_parse(suite, tmp_path)

        tc = root.find("testcase")
        failure = tc.find("failure")
        assert failure is not None
        body = failure.text

        assert "Error: ValueError: bad input" in body
        assert "--- last 50 lines of .err log ---" in body
        # The last 50 lines should start at line 10 (indices 10..59)
        assert "line 10:" in body
        assert "line 59:" in body
        # Line 9 should NOT appear in the tail
        assert "line 9:" not in body

        # system-out should contain the full error content
        sysout = tc.find("system-out")
        assert sysout is not None
        assert "line 0:" in sysout.text
        assert "line 59:" in sysout.text


class TestToXmlSkipped:
    """Skipped cases produce a <skipped> element."""

    def test_to_xml_skipped(self, tmp_path: Path) -> None:
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
        root = _write_and_parse(suite, tmp_path)

        tc = root.find("testcase")
        skipped = tc.find("skipped")
        assert skipped is not None
        assert skipped.get("message") == "Job status: WAITING"
        # Skipped should not produce a failure element
        assert tc.find("failure") is None


class TestToXmlDuration:
    """Duration attribute on testcase."""

    def test_to_xml_duration(self, tmp_path: Path) -> None:
        suite = TestSuite(
            timestamp="2026-04-15T10:00:00",
            cases=[
                TestCase(
                    name="SIM",
                    passed=True,
                    classname="a006",
                    duration=42.5,
                ),
            ],
        )
        root = _write_and_parse(suite, tmp_path)

        tc = root.find("testcase")
        assert tc.get("time") == "42.5"


class TestToXmlEmptySuite:
    """Empty suite writes valid XML with 0 tests."""

    def test_to_xml_empty_suite(self, tmp_path: Path) -> None:
        suite = TestSuite(timestamp="2026-04-15T10:00:00")
        out = tmp_path / "empty.xml"
        to_xml(suite, out)

        assert out.exists()
        root = ET.parse(out).getroot()
        assert root.get("tests") == "0"
        assert root.get("failures") == "0"
        assert root.get("skipped") == "0"
        assert root.findall("testcase") == []


class TestToXmlSorted:
    """Cases appear sorted by name regardless of insertion order."""

    def test_to_xml_sorted(self, tmp_path: Path) -> None:
        suite = TestSuite(
            timestamp="2026-04-15T10:00:00",
            cases=[
                TestCase(name="ZEBRA", passed=True, classname="a006"),
                TestCase(name="ALPHA", passed=True, classname="a006"),
                TestCase(name="MIDDLE", passed=True, classname="a006"),
            ],
        )
        root = _write_and_parse(suite, tmp_path)

        names = [tc.get("name") for tc in root.findall("testcase")]
        assert names == ["ALPHA", "MIDDLE", "ZEBRA"]


class TestToXmlCoarseResult:
    """Plain TestResult (not TestCase) has no properties element."""

    def test_to_xml_coarse_result(self, tmp_path: Path) -> None:
        suite = TestSuite(
            timestamp="2026-04-15T10:00:00",
            cases=[
                TestResult(name="smoke_check", passed=True),
            ],
        )
        root = _write_and_parse(suite, tmp_path)

        tc = root.find("testcase")
        assert tc.get("name") == "smoke_check"
        assert tc.get("classname") == ""
        assert tc.get("time") is None
        assert tc.find("properties") is None
