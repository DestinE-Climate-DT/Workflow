from __future__ import annotations

import json
from pathlib import Path

from wftools.resources.models import JobHistory
from wftools.resources.writer import build_usage, to_json, to_metrics

SACCT = (
    "1001|a006_SIM|COMPLETED|2|256|01:00:00|7200000|\n"
    "1001.batch|batch|COMPLETED|1|128|01:00:00|7200000|4G\n"
    "1002|a006_AQUA|COMPLETED|1|64|00:30:00|900000|\n"
)


def _login(job_id, job_name, platform, seconds, ncpus=4):
    return JobHistory(
        job_id=job_id,
        job_name=job_name,
        platform=platform,
        status="COMPLETED",
        ncpus=ncpus,
        start=1_000_000,
        finish=1_000_000 + seconds,
        run_id=1,
        counter=0,
    )


class TestBuildUsage:
    def test_totals(self) -> None:
        usage = build_usage("a006", SACCT)
        assert usage.expid == "a006"
        assert usage.job_count == 2
        assert usage.node_hours == 2.5  # 2*1h + 1*0.5h
        # No hpc given -> unknown machine: cores fall back to raw NCPUS.
        assert usage.core_hours_used == 288.0  # 256*1 + 64*0.5
        assert usage.core_hours_billed == 288.0
        assert usage.energy_joules == 8100000.0
        assert usage.energy_kwh == 8100000.0 / 3.6e6
        assert usage.peak_rss_bytes == 4 * 1024**3

    def test_no_jobs(self) -> None:
        usage = build_usage("a006", "")
        assert usage.job_count == 0
        assert usage.node_hours == 0.0
        assert usage.peak_rss_bytes is None


class TestLoginNodeJobs:
    """Jobs the scheduler never saw still consume cores, so they are accounted.

    The bug this guards: `sacct` returns nothing for a login-node PID, so every
    REMOTE_SETUP / INI / SYNC_LRA job silently vanished from the footprint.
    """

    def test_accounted_from_history_when_sacct_has_nothing(self) -> None:
        history = [
            _login("4009345", "a006_REMOTE_SETUP", "MARENOSTRUM5-LOGIN", 1800),
            _login("196482", "a006_SYNC_LRA", "LUMI-LOGIN", 135, ncpus=1),
            _login("1068260", "a006_LOCAL_SETUP", "local", 4, ncpus=1),
        ]
        usage = build_usage("a006", "", history=history)

        assert usage.job_count == 3
        assert [j.execution for j in usage.jobs] == ["login", "login", "local"]
        # 4 cores * 0.5 h + 1 * 135 s + 1 * 4 s
        assert usage.core_hours_used == 2.0 + 135 / 3600.0 + 4 / 3600.0
        assert usage.core_hours_billed == 0.0
        assert usage.node_hours == 0.0

    def test_sections_and_states_survive(self) -> None:
        history = [_login("4009345", "a006_REMOTE_SETUP", "MARENOSTRUM5-LOGIN", 1800)]
        usage = build_usage("a006", "", history=history)
        assert usage.jobs[0].section == "REMOTE_SETUP"
        assert usage.jobs[0].state == "COMPLETED"
        assert usage.jobs[0].platform == "MARENOSTRUM5-LOGIN"

    def test_unfinished_job_costs_nothing(self) -> None:
        record = _login("4009345", "a006_REMOTE_SETUP", "MARENOSTRUM5-LOGIN", 0)
        record.finish = 0
        usage = build_usage("a006", "", history=[record])
        assert usage.job_count == 1
        assert usage.core_hours_used == 0.0

    def test_split_by_execution(self) -> None:
        history = [
            JobHistory(job_id="1001", job_name="a006_SIM", platform="MARENOSTRUM5"),
            _login("4009345", "a006_REMOTE_SETUP", "MARENOSTRUM5-LOGIN", 1800),
        ]
        usage = build_usage("a006", SACCT, history=history)

        by_execution = {e.execution: e for e in usage.executions}
        assert by_execution["slurm"].job_count == 2  # 1001 matched, 1002 unclaimed
        assert by_execution["login"].job_count == 1
        assert by_execution["login"].core_hours_billed == 0.0
        assert usage.slurm_job_count == 2
        assert usage.unscheduled.core_hours_used == 2.0

    def test_pid_colliding_with_a_slurm_id_is_not_a_slurm_job(self) -> None:
        """A different job name under the same id means the id is a PID."""
        history = [_login("1001", "a006_REMOTE_SETUP", "MARENOSTRUM5-LOGIN", 3600)]
        usage = build_usage("a006", SACCT, history=history)

        by_name = {j.job_name: j for j in usage.jobs}
        assert by_name["a006_REMOTE_SETUP"].execution == "login"
        # The real allocation is still counted, not consumed by the collision.
        assert by_name["a006_SIM"].execution == "slurm"
        assert by_name["a006_SIM"].cpus == 256

    def test_another_users_job_under_a_colliding_pid_is_dropped(self) -> None:
        """A PID can alias a live id: sacct then answers with a stranger's job.

        The bug this guards: that allocation was billed to us, which on LUMI put
        two orders of magnitude of someone else's compute in our footprint.
        """
        sacct = (
            "78161|gmx|COMPLETED|16|4096|00:00:02|||billing=4096,cpu=4096,node=16|\n"
        )
        history = [_login("78161", "a006_19900101_fc0_1_1_DN", "LUMI-LOGIN", 21)]
        usage = build_usage("a006", sacct, history=history, hpc="lumi")

        assert [j.job_name for j in usage.jobs] == ["a006_19900101_fc0_1_1_DN"]
        assert usage.slurm_job_count == 0
        assert usage.core_hours_billed == 0.0
        assert usage.node_hours == 0.0
        assert "gmx" not in {s.section for s in usage.sections}


class TestWriters:
    def test_to_json_roundtrip(self, tmp_path: Path) -> None:
        usage = build_usage("a006", SACCT)
        out = tmp_path / "resources.json"
        to_json(usage, out)
        data = json.loads(out.read_text())
        assert data["expid"] == "a006"
        assert data["job_count"] == 2
        assert len(data["jobs"]) == 2

    def test_to_metrics_keys(self, tmp_path: Path) -> None:
        usage = build_usage("a006", SACCT)
        out = tmp_path / "metrics.txt"
        to_metrics(usage, out)
        content = out.read_text()
        assert content.endswith("\n")
        keys = {line.split()[0] for line in content.splitlines()}
        assert {
            "hpc_jobs",
            "login_jobs",
            "login_core_hours",
            "login_job_elapsed_hours",
            "node_hours",
            "core_hours_used",
            "core_hours_billed",
            "gpu_hours",
            "job_elapsed_hours",
            "energy_kwh",
        } <= keys
        # Summed over jobs, so it must not claim to be the run's wall time.
        assert "elapsed_hours" not in keys
        # Every value must be a parseable number (collector sums them as floats).
        for line in content.splitlines():
            float(line.split()[1])
