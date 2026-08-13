from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

from wftools.domain.models import TestCase, TestSuite


def to_xml(suite: TestSuite, output: Path) -> None:
    """Write TestSuite as JUnit XML.

    Produces a ``<testsuite>`` document compatible with GitLab's JUnit
    report parser.  Cases are sorted by name; ``<properties>``,
    ``<failure>``, ``<skipped>``, and ``<system-out>`` elements mirror
    the structure that ``tests/tsuite_results_to_junit.py`` emitted.
    """
    testsuite_el = ET.Element("testsuite")
    testsuite_el.set("name", suite.name)
    testsuite_el.set("tests", str(suite.total))
    testsuite_el.set("failures", str(suite.failures))
    testsuite_el.set("skipped", str(suite.skipped_count))
    testsuite_el.set("errors", "0")
    testsuite_el.set("timestamp", suite.timestamp)

    for case in sorted(suite.cases, key=lambda c: c.name):
        tc_el = ET.SubElement(testsuite_el, "testcase")
        tc_el.set("name", case.name)

        # classname: TestCase carries one; plain TestResult does not.
        if isinstance(case, TestCase) and case.classname is not None:
            tc_el.set("classname", case.classname)
        else:
            tc_el.set("classname", "")

        # Duration attribute (only when present)
        if isinstance(case, TestCase) and case.duration is not None:
            tc_el.set("time", f"{case.duration:.1f}")

        # Properties -- only for TestCase instances with slurm data
        if isinstance(case, TestCase):
            _maybe_add_properties(tc_el, case)

        # Skipped element
        if case.skipped:
            skip_el = ET.SubElement(tc_el, "skipped")
            status_str = (
                case.status if isinstance(case, TestCase) and case.status else "WAITING"
            )
            skip_el.set("message", f"Job status: {status_str}")

        elif not case.passed:
            # Failure element
            error_summary = ""
            if isinstance(case, TestCase) and case.error_summary:
                error_summary = case.error_summary
            elif isinstance(case, TestCase) and case.status:
                error_summary = f"status: {case.status}"
            else:
                error_summary = "status: FAILED"

            failure_el = ET.SubElement(tc_el, "failure")
            failure_el.set("message", error_summary)

            body_parts = [f"Error: {error_summary}"]
            if case.error:
                tail_lines = case.error.splitlines()[-50:]
                body_parts.append("\n--- last 50 lines of .err log ---")
                body_parts.append("\n".join(tail_lines))
            else:
                body_parts.append("No error details available.")
            failure_el.text = "\n\n".join(body_parts)

        # system-out: full error content for deep debugging
        if case.error:
            sysout_el = ET.SubElement(tc_el, "system-out")
            sysout_el.text = case.error

    tree = ET.ElementTree(testsuite_el)
    ET.indent(tree, space="  ")

    output.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output, encoding="unicode", xml_declaration=True)


def _maybe_add_properties(tc_el: ET.Element, case: TestCase) -> None:
    """Add ``<properties>`` child to *tc_el* when the case carries metadata."""
    if not (
        case.slurm and (case.slurm.slurm_id or case.slurm.platform or case.slurm.queue)
    ):
        return

    props_el = ET.SubElement(tc_el, "properties")

    if case.slurm:
        if case.slurm.slurm_id:
            _add_property(props_el, "slurm_job_id", case.slurm.slurm_id)
        if case.slurm.platform:
            _add_property(props_el, "platform", case.slurm.platform)
        if case.slurm.queue:
            _add_property(props_el, "queue", case.slurm.queue)


def _add_property(parent: ET.Element, name: str, value: str) -> None:
    prop = ET.SubElement(parent, "property")
    prop.set("name", name)
    prop.set("value", value)
