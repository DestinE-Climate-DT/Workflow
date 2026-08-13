"""Tests for collecting child-pipeline tsuite results into the parent.

The behaviour under test is the one that made a green re-run publish the
failed attempt's numbers: collect runs once, so what it publishes has to name
its own sources, and a second attempt has to be able to tell it was superseded.
"""

from __future__ import annotations

import os
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from wftools.tsuite_collect import (
    RECEIPT_RETENTION,
    Source,
    collect,
    merge_metrics,
    parse_provenance,
    provenance_metrics,
    receipt_path,
)

_NOW = datetime(2026, 8, 11, 9, 47, tzinfo=timezone.utc)

_REPORT = """<?xml version='1.0' encoding='utf-8'?>
<testsuite name="tsuite" tests="1" failures="0" skipped="0" errors="0" timestamp="2026-08-11T09:47:00">
  <testcase name="ifs-nemo-lowres/LOCAL_SETUP" classname="{expid}" />
</testsuite>
"""


def _shared(tmp_path: Path, pipeline_id: str = "12345") -> Path:
    path = tmp_path / "results" / pipeline_id
    path.mkdir(parents=True)
    return path


def _write_attempt(
    shared: Path, expid: str, job: str, *, core_hours: str = "1.5"
) -> None:
    """Populate the shared dir the way one child chain's jobs would."""
    (shared / f"tsuite-report-{expid}.xml").write_text(_REPORT.format(expid=expid))
    (shared / f"metrics-{expid}.txt").write_text(
        f"total_jobs 12\nfailed_jobs 0\ncore_hours_used {core_hours}\n"
    )
    (shared / f"resources-{expid}.json").write_text(f'{{"expid": "{expid}"}}')
    (shared / "provenance.txt").write_text(
        f"expid={expid} type=ifs-nemo-lowres phase=monitor job={job} "
        f"url=https://gitlab.example/-/jobs/{job} at=2026-08-11T09:47:00Z\n"
    )


class TestParseProvenance:
    def test_reads_key_value_tokens(self) -> None:
        (source,) = parse_provenance(
            "expid=a007 type=ifs-nemo-lowres phase=monitor job=99 "
            "url=https://gitlab.example/-/jobs/99 at=2026-08-11T09:47:00Z"
        )
        assert source == Source(
            expid="a007",
            type_name="ifs-nemo-lowres",
            phase="monitor",
            job="99",
            url="https://gitlab.example/-/jobs/99",
            at="2026-08-11T09:47:00Z",
        )

    def test_ignores_blank_lines_and_stray_tokens(self) -> None:
        sources = parse_provenance("\nexpid=a007 garbage\n\n")
        assert [s.expid for s in sources] == ["a007"]


class TestMergeMetrics:
    def test_sums_across_files_and_formats_integers_without_decimals(
        self, tmp_path: Path
    ) -> None:
        (tmp_path / "a.txt").write_text("total_jobs 12\ncore_hours_used 1.5\n")
        (tmp_path / "b.txt").write_text("total_jobs 4\ncore_hours_used 2.25\n")
        assert merge_metrics(sorted(tmp_path.glob("*.txt"))) == {
            "core_hours_used": "3.7500",
            "total_jobs": "16",
        }

    def test_skips_malformed_and_non_numeric_lines(self, tmp_path: Path) -> None:
        (tmp_path / "a.txt").write_text("total_jobs 12\nnot a number here\nhpc n/a\n")
        assert merge_metrics([tmp_path / "a.txt"]) == {"total_jobs": "12"}


class TestProvenanceMetrics:
    def test_labels_carry_expid_and_child_job(self) -> None:
        metrics = provenance_metrics(
            [
                Source(
                    expid="a007", type_name="ifs-nemo-lowres", phase="monitor", job="99"
                )
            ],
            _NOW,
        )
        assert metrics["tsuite_collected_at"] == str(int(_NOW.timestamp()))
        assert (
            'tsuite_source{expid="a007",type="ifs-nemo-lowres",phase="monitor",job="99"}'
            in metrics
        )

    def test_sources_without_an_expid_are_dropped(self) -> None:
        metrics = provenance_metrics([Source(phase="monitor", job="99")], _NOW)
        assert list(metrics) == ["tsuite_collected_at"]


class TestCollect:
    def test_publishes_reports_metrics_and_extras(self, tmp_path: Path) -> None:
        shared = _shared(tmp_path)
        _write_attempt(shared, "a006", "111")
        reports = tmp_path / "reports"

        result = collect(
            shared, reports, job_url="https://gitlab.example/-/jobs/1", now=_NOW
        )

        assert result.status == "collected"
        assert [p.name for p in result.reports] == ["tsuite-report-a006.xml"]
        assert [p.name for p in result.extras] == ["resources-a006.json"]
        assert (reports / "metrics-all.txt").exists()
        assert result.metrics["core_hours_used"] == "1.5000"

    def test_stamps_source_expid_and_child_job_into_the_report(
        self, tmp_path: Path
    ) -> None:
        shared = _shared(tmp_path)
        _write_attempt(shared, "a006", "111")
        reports = tmp_path / "reports"

        collect(shared, reports, now=_NOW)

        root = ET.parse(reports / "tsuite-report-a006.xml").getroot()
        props = {p.get("name"): p.get("value") for p in root.iter("property")}
        assert props["source_expid"] == "a006"
        assert props["child_job_monitor"] == "111"
        assert props["collected_at"] == _NOW.isoformat()

    def test_publishes_the_per_phase_report_beside_the_monitor_one(
        self, tmp_path: Path
    ) -> None:
        """The resources job forwards its own XML under a `.resources` infix."""
        shared = _shared(tmp_path)
        _write_attempt(shared, "a006", "111")
        (shared / "tsuite-report-a006.resources.xml").write_text(
            _REPORT.format(expid="a006")
        )
        reports = tmp_path / "reports"

        result = collect(shared, reports, now=_NOW)

        assert [p.name for p in result.reports] == [
            "tsuite-report-a006.resources.xml",
            "tsuite-report-a006.xml",
        ]
        # The infix must not leak into the expid the report is stamped with.
        root = ET.parse(reports / "tsuite-report-a006.resources.xml").getroot()
        props = {p.get("name"): p.get("value") for p in root.iter("property")}
        assert props["source_expid"] == "a006"

    def test_metrics_name_the_expid_behind_the_numbers(self, tmp_path: Path) -> None:
        shared = _shared(tmp_path)
        _write_attempt(shared, "a006", "111")
        reports = tmp_path / "reports"

        collect(shared, reports, now=_NOW)

        text = (reports / "metrics.txt").read_text()
        assert 'tsuite_source{expid="a006"' in text
        assert "core_hours_used 1.5000" in text
        assert (reports / "provenance.txt").read_text().startswith("expid=a006")

    def test_leaves_a_receipt_and_removes_the_shared_dir(self, tmp_path: Path) -> None:
        shared = _shared(tmp_path)
        _write_attempt(shared, "a006", "111")

        collect(
            shared,
            tmp_path / "reports",
            job_url="https://gitlab.example/-/jobs/1",
            now=_NOW,
        )

        assert not shared.exists()
        receipt = receipt_path(shared).read_text()
        assert "expids=a006" in receipt
        assert "collect_job_url=https://gitlab.example/-/jobs/1" in receipt

    def test_expired_receipts_are_pruned(self, tmp_path: Path) -> None:
        """Receipts outlive their results dir, so collection reclaims its own."""
        shared = _shared(tmp_path)
        _write_attempt(shared, "a006", "111")
        stale = shared.parent / "collected-00001.txt"
        stale.write_text("collected_at=old\n")
        expired = (_NOW - RECEIPT_RETENTION - timedelta(days=1)).timestamp()
        os.utime(stale, (expired, expired))
        recent = shared.parent / "collected-00002.txt"
        recent.write_text("collected_at=recent\n")

        collect(shared, tmp_path / "reports", now=_NOW)

        assert not stale.exists()
        assert recent.exists()
        assert receipt_path(shared).exists()

    def test_rerun_collects_the_new_attempt_alone(self, tmp_path: Path) -> None:
        """The recovery path: retrying collect must not merge the two attempts."""
        shared = _shared(tmp_path)
        _write_attempt(shared, "a006", "111", core_hours="0.05")
        reports = tmp_path / "reports"
        collect(shared, reports, now=_NOW)

        # The manual re-run repopulates the emptied dir with a second expid.
        shared.mkdir(parents=True)
        _write_attempt(shared, "a007", "222", core_hours="11.48")

        result = collect(shared, reports, now=_NOW)

        assert result.status == "collected"
        assert result.prior_receipt, "the superseded collection should be reported"
        assert result.metrics["core_hours_used"] == "11.4800"
        assert 'tsuite_source{expid="a007"' in (reports / "metrics.txt").read_text()
        assert 'tsuite_source{expid="a006"' not in (reports / "metrics.txt").read_text()
        # The superseded attempt must not survive into the republished JUnit,
        # or tsuite-required would fail the gate on a green re-run.
        assert not (reports / "tsuite-report-a006.xml").exists()
        assert not (reports / "resources-a006.json").exists()
        assert (reports / "tsuite-report-a007.xml").exists()

    def test_collection_leaves_other_jobs_artifacts_alone(self, tmp_path: Path) -> None:
        shared = _shared(tmp_path)
        _write_attempt(shared, "a006", "111")
        reports = tmp_path / "reports"
        reports.mkdir()
        (reports / "tsuite-prepare.xml").write_text("<testsuite/>")

        collect(shared, reports, now=_NOW)

        assert (reports / "tsuite-prepare.xml").exists()

    def test_missing_dir_without_a_receipt_is_empty_not_stale(
        self, tmp_path: Path
    ) -> None:
        result = collect(tmp_path / "results" / "12345", tmp_path / "reports", now=_NOW)
        assert result.status == "empty"

    def test_missing_dir_after_a_receipt_is_stale(self, tmp_path: Path) -> None:
        shared = _shared(tmp_path)
        _write_attempt(shared, "a006", "111")
        collect(shared, tmp_path / "reports", now=_NOW)

        result = collect(shared, tmp_path / "reports", now=_NOW)

        assert result.status == "stale"
        assert "expids=a006" in result.prior_receipt

    def test_reports_dir_exists_even_with_nothing_to_collect(
        self, tmp_path: Path
    ) -> None:
        reports = tmp_path / "reports"
        collect(tmp_path / "results" / "12345", reports, now=_NOW)
        assert reports.is_dir()

    def test_survives_a_report_that_is_not_parseable(self, tmp_path: Path) -> None:
        shared = _shared(tmp_path)
        _write_attempt(shared, "a006", "111")
        (shared / "tsuite-report-a006.xml").write_text("<testsuite>truncated")
        reports = tmp_path / "reports"

        result = collect(shared, reports, now=_NOW)

        assert result.status == "collected"
        assert (
            reports / "tsuite-report-a006.xml"
        ).read_text() == "<testsuite>truncated"


@pytest.mark.parametrize(
    "shared_name, expected",
    [("12345", "collected-12345.txt"), ("7", "collected-7.txt")],
)
def test_receipt_sits_beside_the_shared_dir(
    tmp_path: Path, shared_name, expected
) -> None:
    """Beside, not inside -- collect deletes the dir it just read."""
    shared = tmp_path / "results" / shared_name
    assert receipt_path(shared) == tmp_path / "results" / expected
