"""Tests for the MR-blocking gate, `destine tsuite required`.

The behaviour under test is what a resources failure is allowed to do: it has
to reach the gate (the accounting job reports its verdict in its own XML), but
that XML must never stand in for the monitor one -- a chain that died before
monitor would otherwise be gated as a pass.
"""

from __future__ import annotations

from pathlib import Path

from wftools.tsuite import check_required, is_primary_report, xml_files_for_type

_SUITE = """<?xml version='1.0' encoding='utf-8'?>
<testsuite name="tsuite" tests="1" failures="{failures}" skipped="0" errors="0">
  <testcase name="{case}" classname="a006">{body}</testcase>
</testsuite>
"""


def _write(reports: Path, name: str, case: str, *, failed: bool = False) -> Path:
    body = '<failure message="boom">boom</failure>' if failed else ""
    path = reports / name
    path.write_text(_SUITE.format(case=case, body=body, failures=int(failed)))
    return path


def _monitor(reports: Path, type_name: str, **kwargs) -> Path:
    return _write(reports, "tsuite-report-a006.xml", f"{type_name}/SIM", **kwargs)


def _resources(reports: Path, type_name: str, **kwargs) -> Path:
    return _write(
        reports,
        "tsuite-report-a006.resources.xml",
        f"{type_name}/resources",
        **kwargs,
    )


_DETECTED = [{"type": "ifs-nemo-lowres"}]


class TestIsPrimaryReport:
    def test_monitor_report_is_primary(self) -> None:
        assert is_primary_report(Path("tsuite-report-a006.xml"))

    def test_phase_report_is_not(self) -> None:
        assert not is_primary_report(Path("tsuite-report-a006.resources.xml"))


class TestXmlFilesForType:
    def test_resources_report_is_matched_to_its_type(self, tmp_path: Path) -> None:
        """The phase scripts prefix their case names, same as the job cases."""
        _resources(tmp_path, "ifs-nemo-lowres")
        assert xml_files_for_type(tmp_path, "ifs-nemo-lowres") == [
            tmp_path / "tsuite-report-a006.resources.xml"
        ]

    def test_other_types_are_not_matched(self, tmp_path: Path) -> None:
        _resources(tmp_path, "ifs-nemo-lowres")
        assert xml_files_for_type(tmp_path, "nemo-standalone") == []


class TestCheckRequired:
    def test_passes_when_both_reports_are_clean(self, tmp_path: Path) -> None:
        _monitor(tmp_path, "ifs-nemo-lowres")
        _resources(tmp_path, "ifs-nemo-lowres")

        passed, failed = check_required(_DETECTED, tmp_path)
        assert passed == ["ifs-nemo-lowres"]
        assert failed == []

    def test_resources_failure_gates(self, tmp_path: Path) -> None:
        """A green monitor no longer hides broken accounting."""
        _monitor(tmp_path, "ifs-nemo-lowres")
        _resources(tmp_path, "ifs-nemo-lowres", failed=True)

        passed, failed = check_required(_DETECTED, tmp_path)
        assert passed == []
        assert len(failed) == 1
        assert "tsuite-report-a006.resources.xml" in failed[0][1]

    def test_resources_report_alone_is_not_a_pass(self, tmp_path: Path) -> None:
        """The chain died before monitor: no per-job results, so not a pass."""
        _resources(tmp_path, "ifs-nemo-lowres")

        passed, failed = check_required(_DETECTED, tmp_path)
        assert passed == []
        assert failed[0][1].startswith("did not run")

    def test_missing_reports_still_fail(self, tmp_path: Path) -> None:
        passed, failed = check_required(_DETECTED, tmp_path)
        assert passed == []
        assert failed[0][1].startswith("did not run")

    def test_undetected_types_never_gate(self, tmp_path: Path) -> None:
        passed, failed = check_required([], tmp_path)
        assert (passed, failed) == ([], [])
