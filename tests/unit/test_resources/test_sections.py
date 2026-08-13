"""Tests for grouping jobs by Autosubmit section and by execution class."""

from __future__ import annotations

from wftools.resources.models import JobUsage
from wftools.resources.sections import summarize


def _job(section, cores, cores_billed, elapsed_s=3600.0, gpus=0):
    return JobUsage(
        job_id=section,
        job_name=f"a006_19900101_fc0_1_{section}",
        section=section,
        nodes=1,
        nodes_billed=1,
        cores=cores,
        cores_billed=cores_billed,
        gpus=gpus,
        elapsed_s=elapsed_s,
        energy_joules=100.0,
    )


class TestSummarize:
    def test_groups_and_totals_by_section(self):
        rows = summarize(
            [_job("SIM", 128, 128), _job("SIM", 128, 128), _job("DQC", 8, 8)]
        )
        by_section = {row.section: row for row in rows}
        assert set(by_section) == {"SIM", "DQC"}
        assert by_section["SIM"].job_count == 2
        assert by_section["SIM"].core_hours_used == 256.0
        assert by_section["DQC"].core_hours_used == 8.0

    def test_reports_billed_separately(self):
        rows = summarize([_job("SIM", 130, 256)])
        assert rows[0].core_hours_used == 130.0
        assert rows[0].core_hours_billed == 256.0

    def test_average_per_job(self):
        rows = summarize([_job("SIM", 128, 128), _job("SIM", 128, 128, elapsed_s=7200)])
        assert rows[0].core_hours_billed == 384.0
        assert rows[0].core_hours_billed_avg == 192.0

    def test_sorted_alphabetically(self):
        rows = summarize(
            [_job("TRANSFER", 1, 1), _job("AQUA", 1, 1), _job("SIM", 1, 1)]
        )
        assert [row.section for row in rows] == ["AQUA", "SIM", "TRANSFER"]

    def test_jobs_without_a_section_are_skipped(self):
        assert summarize([JobUsage(job_id="1")]) == []
