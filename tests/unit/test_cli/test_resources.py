from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest
from click.testing import CliRunner

from wftools.cli.main import cli


@pytest.fixture()
def runner() -> CliRunner:
    return CliRunner()


@pytest.fixture(autouse=True)
def isolated_db(tmp_path, monkeypatch):
    """Keep `report` off the deployed store.

    Without this the default path is used, so running the suite on the CI VM
    would write test rows into the real `ci_resources.db`.
    """
    monkeypatch.setenv("CI_RESOURCES_DB", str(tmp_path / "ci_resources.db"))


SACCT = (
    "1001|a006_SIM|COMPLETED|2|256|01:00:00|7200000|\n"
    "1002|a006_AQUA|COMPLETED|1|64|00:30:00|900000|\n"
)


class TestResourcesReport:
    def test_writes_json_and_metrics(self, runner: CliRunner, tmp_path: Path) -> None:
        sacct_file = tmp_path / "sacct.txt"
        sacct_file.write_text(SACCT)
        json_out = tmp_path / "resources.json"
        metrics_out = tmp_path / "metrics.txt"

        result = runner.invoke(
            cli,
            [
                "resources",
                "report",
                "a006",
                str(sacct_file),
                "--json",
                str(json_out),
                "--metrics",
                str(metrics_out),
            ],
        )
        assert result.exit_code == 0, result.output

        data = json.loads(json_out.read_text())
        assert data["expid"] == "a006"
        assert data["job_count"] == 2
        assert data["node_hours"] == 2.5

        metrics = metrics_out.read_text()
        assert "node_hours 2.5000" in metrics
        assert "hpc_jobs 2" in metrics

    def test_missing_sacct_file_errors(self, runner: CliRunner, tmp_path: Path) -> None:
        result = runner.invoke(
            cli,
            ["resources", "report", "a006", str(tmp_path / "nope.txt")],
        )
        assert result.exit_code != 0


class TestResourcesExecutions:
    def test_reports_login_jobs_separately(
        self, runner: CliRunner, tmp_path: Path
    ) -> None:
        history = _history_db(
            tmp_path,
            "a006",
            [
                ("a006_SIM", 1001, "MARENOSTRUM5", 256, 3600),
                ("a006_REMOTE_SETUP", 4009345, "MARENOSTRUM5-LOGIN", 4, 1800),
            ],
        )
        sacct_file = tmp_path / "sacct.txt"
        sacct_file.write_text(SACCT)

        report = runner.invoke(
            cli,
            [
                "resources",
                "report",
                "a006",
                str(sacct_file),
                "--history-db",
                str(history),
                "--json",
                str(tmp_path / "resources.json"),
                "--metrics",
                str(tmp_path / "metrics.txt"),
            ],
        )
        assert report.exit_code == 0, report.output

        result = runner.invoke(cli, ["resources", "executions", "--expid", "a006"])
        assert result.exit_code == 0, result.output
        assert "slurm" in result.output
        assert "login" in result.output


class TestResourcesJobIds:
    def test_lists_login_pids_alongside_slurm_ids(
        self, runner: CliRunner, tmp_path: Path
    ) -> None:
        """sacct is what tells them apart, so both must be offered to it."""
        history = _history_db(
            tmp_path,
            "a006",
            [
                ("a006_SIM", 1001, "MARENOSTRUM5", 256, 3600),
                ("a006_INI", 300, "MARENOSTRUM5-LOGIN", 4, 10),
                ("a006_AQUA_SETUP", 300, "MARENOSTRUM5-LOGIN", 4, 60),
            ],
        )
        result = runner.invoke(
            cli, ["resources", "job-ids", "a006", "--db", str(history)]
        )
        assert result.exit_code == 0, result.output
        # The recycled PID is queried once, not twice.
        assert result.output.strip() == "1001,300"


def _history_db(tmp_path: Path, expid: str, rows: list) -> Path:
    db = tmp_path / f"job_data_{expid}.db"
    con = sqlite3.connect(db)
    con.executescript(
        "CREATE TABLE job_data (id INTEGER PRIMARY KEY AUTOINCREMENT, counter "
        "INTEGER, job_name TEXT, job_id INTEGER, run_id INTEGER, last INTEGER, "
        "platform TEXT, status TEXT, ncpus INTEGER, nnodes INTEGER, start "
        "INTEGER, finish INTEGER);"
    )
    con.executemany(
        "INSERT INTO job_data (counter, job_name, job_id, run_id, last, platform, "
        "status, ncpus, nnodes, start, finish) VALUES (0,?,?,1,1,?,'COMPLETED',?,0,"
        "100,?)",
        [
            (name, jid, platform, ncpus, 100 + secs)
            for name, jid, platform, ncpus, secs in rows
        ],
    )
    con.commit()
    con.close()
    return db
