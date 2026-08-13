from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

from wftools.domain.models import SlurmMetadata, TestCase, TestResult, TestSuite


def from_xml(path: Path) -> TestSuite:
    """Parse JUnit XML back into a TestSuite.

    This is a minimal reader for round-trip testing and future tooling.
    It reconstructs ``TestCase`` objects when enough metadata is present,
    falling back to ``TestResult`` for bare ``<testcase>`` elements.
    """
    tree = ET.parse(path)
    root = tree.getroot()

    suite_name = root.get("name", "tsuite")
    suite_timestamp = root.get("timestamp", "")

    cases: list[TestCase | TestResult] = []

    for tc_el in root.findall("testcase"):
        name = tc_el.get("name", "")
        classname = tc_el.get("classname", "") or None
        time_str = tc_el.get("time")
        duration = float(time_str) if time_str else None

        # Determine pass/skip/fail state
        skipped_el = tc_el.find("skipped")
        failure_el = tc_el.find("failure")

        skipped = skipped_el is not None
        if failure_el is not None:
            passed = False
        elif skipped:
            # Skipped jobs are not passed -- match the convention used in
            # the domain model tests (passed=False, skipped=True).
            passed = False
        else:
            passed = True

        # Extract failure message
        error_summary = failure_el.get("message") if failure_el is not None else None

        # Extract full error from system-out
        sysout_el = tc_el.find("system-out")
        error = sysout_el.text if sysout_el is not None else None

        # Extract SLURM metadata from properties
        slurm_id = _get_property(tc_el, "slurm_job_id")
        platform = _get_property(tc_el, "platform")
        queue = _get_property(tc_el, "queue")

        # Extract status from skipped message if present
        status: str | None = None
        if skipped_el is not None:
            msg = skipped_el.get("message", "")
            if msg.startswith("Job status: "):
                status = msg[len("Job status: ") :]

        # Decide whether this is a full TestCase or a plain TestResult.
        has_case_fields = (
            classname is not None
            or duration is not None
            or error_summary is not None
            or status is not None
            or slurm_id is not None
        )

        if has_case_fields:
            slurm = SlurmMetadata(
                slurm_id=slurm_id,
                platform=platform,
                queue=queue,
            )
            cases.append(
                TestCase(
                    name=name,
                    passed=passed,
                    skipped=skipped,
                    error=error,
                    error_summary=error_summary,
                    classname=classname,
                    status=status,
                    slurm=slurm,
                    duration=duration,
                )
            )
        else:
            cases.append(
                TestResult(
                    name=name,
                    passed=passed,
                    skipped=skipped,
                    error=error,
                )
            )

    return TestSuite(
        name=suite_name,
        timestamp=suite_timestamp,
        cases=cases,
    )


def _get_property(tc_el: ET.Element, prop_name: str) -> str | None:
    """Extract a named property value from a ``<testcase>`` element."""
    props_el = tc_el.find("properties")
    if props_el is None:
        return None
    for prop in props_el.findall("property"):
        if prop.get("name") == prop_name:
            return prop.get("value")
    return None
