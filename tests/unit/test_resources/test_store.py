"""Tests for the SQLite resource store.

The store is shared between developers' CI jobs on one VM, so the cases that
matter are: the schema is created on demand, a re-run replaces rather than
duplicates, the file is left group-writable, and every failure is non-fatal.
"""

from __future__ import annotations

import os
import sqlite3
import stat

import pytest

from wftools.resources import store
from wftools.resources.models import JobUsage, ResourceUsage


def _usage(expid="a006", pipeline_id=42, **kwargs) -> ResourceUsage:
    defaults = dict(
        expid=expid,
        pipeline_id=pipeline_id,
        commit_sha="deadbeefcafe",
        mr_iid=7,
        type_name="ifs-nemo-e2e",
        hpc="lumi",
        job_count=2,
        node_hours=1.5,
        core_hours_used=96.0,
        core_hours_billed=128.0,
        elapsed_s=3600.0,
        energy_joules=7.2e6,
        peak_rss_bytes=1024,
        gpu_hours=4.0,
        run_ids=[1, 2],
        jobs=[
            JobUsage(
                job_id="111",
                job_name="SIM",
                state="COMPLETED",
                nodes=1,
                cpus=128,
                gpus=4,
                run_id=1,
                counter=0,
            ),
            JobUsage(
                job_id="222",
                job_name="DN",
                state="COMPLETED",
                nodes=1,
                cpus=64,
                run_id=2,
                counter=1,
            ),
        ],
    )
    defaults.update(kwargs)
    return ResourceUsage(**defaults)


class TestSave:
    def test_creates_schema_and_rows(self, tmp_path):
        db = tmp_path / "ci_resources.db"
        assert store.save(_usage(), db) is True

        con = sqlite3.connect(db)
        runs = con.execute(
            "SELECT expid, pipeline_id, commit_sha, type_name, hpc, job_count, "
            "node_hours, core_hours_used, core_hours_billed FROM ci_run"
        ).fetchall()
        jobs = con.execute("SELECT slurm_job_id, job_name, cpus FROM ci_job").fetchall()
        version = con.execute("PRAGMA user_version").fetchone()[0]
        con.close()

        assert runs == [
            ("a006", 42, "deadbeefcafe", "ifs-nemo-e2e", "lumi", 2, 1.5, 96.0, 128.0)
        ]
        assert sorted(jobs) == [("111", "SIM", 128), ("222", "DN", 64)]
        assert version == store.SCHEMA_VERSION

    def test_stores_gpu_and_run_provenance(self, tmp_path):
        """GPU hours and which run/attempt each allocation came from."""
        db = tmp_path / "ci_resources.db"
        store.save(_usage(), db)

        con = sqlite3.connect(db)
        run = con.execute("SELECT gpu_hours, run_count FROM ci_run").fetchone()
        jobs = con.execute(
            "SELECT slurm_job_id, gpus, as_run_id, attempt FROM ci_job "
            "ORDER BY slurm_job_id"
        ).fetchall()
        con.close()

        assert run == (4.0, 2)
        assert jobs == [("111", 4, 1, 0), ("222", 0, 2, 1)]

    def test_rerun_replaces_instead_of_duplicating(self, tmp_path):
        db = tmp_path / "ci_resources.db"
        store.save(_usage(node_hours=1.0), db)
        store.save(_usage(node_hours=9.0), db)

        con = sqlite3.connect(db)
        rows = con.execute("SELECT node_hours FROM ci_run").fetchall()
        # The cascade must take the superseded run's jobs with it.
        job_count = con.execute("SELECT count(*) FROM ci_job").fetchone()[0]
        con.close()

        assert rows == [(9.0,)]
        assert job_count == 2

    def test_null_pipeline_id_still_deduplicates(self, tmp_path):
        """SQLite treats NULLs as distinct in UNIQUE, hence the `IS` comparison."""
        db = tmp_path / "ci_resources.db"
        store.save(_usage(pipeline_id=None), db)
        store.save(_usage(pipeline_id=None), db)

        con = sqlite3.connect(db)
        count = con.execute("SELECT count(*) FROM ci_run").fetchone()[0]
        con.close()
        assert count == 1

    def test_distinct_pipelines_accumulate(self, tmp_path):
        db = tmp_path / "ci_resources.db"
        store.save(_usage(pipeline_id=1), db)
        store.save(_usage(pipeline_id=2), db)

        con = sqlite3.connect(db)
        count = con.execute("SELECT count(*) FROM ci_run").fetchone()[0]
        con.close()
        assert count == 2

    def test_raw_json_round_trips(self, tmp_path):
        db = tmp_path / "ci_resources.db"
        store.save(_usage(), db)

        con = sqlite3.connect(db)
        raw = con.execute("SELECT raw_json FROM ci_run").fetchone()[0]
        con.close()
        parsed = store.raw_usage(raw)
        assert parsed["expid"] == "a006"
        assert len(parsed["jobs"]) == 2

    @pytest.mark.skipif(os.name == "nt", reason="POSIX permission semantics")
    def test_file_is_group_writable(self, tmp_path):
        """The VM's 0027 umask would otherwise lock out the next developer."""
        db = tmp_path / "ci_resources.db"
        previous = os.umask(0o027)
        try:
            store.save(_usage(), db)
        finally:
            os.umask(previous)

        mode = stat.S_IMODE(db.stat().st_mode)
        assert mode & stat.S_IWGRP, f"not group-writable: {mode:o}"

    def test_umask_is_restored(self, tmp_path):
        before = os.umask(0o027)
        os.umask(before)
        store.save(_usage(), tmp_path / "ci_resources.db")
        after = os.umask(0o027)
        os.umask(after)
        assert after == before


class TestSaveIsNonFatal:
    def test_missing_directory_warns_and_returns_false(self, tmp_path):
        assert store.save(_usage(), tmp_path / "nope" / "ci.db") is False

    def test_corrupt_file_returns_false(self, tmp_path):
        db = tmp_path / "ci_resources.db"
        db.write_text("this is not a database")
        assert store.save(_usage(), db) is False

    def test_newer_schema_is_left_alone(self, tmp_path):
        db = tmp_path / "ci_resources.db"
        con = sqlite3.connect(db)
        con.execute(f"PRAGMA user_version={store.SCHEMA_VERSION + 1}")
        con.close()

        assert store.save(_usage(), db) is False
        con = sqlite3.connect(db)
        tables = con.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        ).fetchall()
        con.close()
        assert tables == []


#: A file written before several columns existed, and holding one (`cpu_hours`)
#: that `_SCHEMA` no longer declares.
_LEGACY_SCHEMA = """
CREATE TABLE ci_run (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    expid          TEXT    NOT NULL,
    pipeline_id    INTEGER,
    commit_sha     TEXT,
    mr_iid         INTEGER,
    type_name      TEXT,
    hpc            TEXT,
    created_at     TEXT    NOT NULL,
    job_count      INTEGER NOT NULL DEFAULT 0,
    node_hours     REAL    NOT NULL DEFAULT 0,
    cpu_hours      REAL    NOT NULL DEFAULT 0,
    elapsed_s      REAL    NOT NULL DEFAULT 0,
    energy_joules  REAL    NOT NULL DEFAULT 0,
    peak_rss_bytes INTEGER,
    raw_json       TEXT
);

CREATE TABLE ci_job (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id        INTEGER NOT NULL REFERENCES ci_run(id) ON DELETE CASCADE,
    slurm_job_id  TEXT    NOT NULL,
    job_name      TEXT,
    state         TEXT,
    nodes         INTEGER NOT NULL DEFAULT 0,
    cpus          INTEGER NOT NULL DEFAULT 0,
    cores         INTEGER NOT NULL DEFAULT 0,
    nodes_billed  INTEGER NOT NULL DEFAULT 0,
    cores_billed  INTEGER NOT NULL DEFAULT 0,
    gpus          INTEGER NOT NULL DEFAULT 0,
    elapsed_s     REAL    NOT NULL DEFAULT 0,
    energy_joules REAL,
    max_rss_bytes INTEGER,
    as_run_id     INTEGER,
    attempt       INTEGER,
    section       TEXT
);
"""


def _columns(db, table) -> set[str]:
    con = sqlite3.connect(db)
    try:
        return {row[1] for row in con.execute(f"PRAGMA table_info({table})")}
    finally:
        con.close()


class TestUpgradeInPlace:
    """The file accumulates every pipeline's accounting: upgrade it, never reset it."""

    def _legacy_db(self, tmp_path):
        db = tmp_path / "ci_resources.db"
        con = sqlite3.connect(db)
        con.executescript(_LEGACY_SCHEMA)
        con.execute("INSERT INTO ci_run (expid, created_at) VALUES ('a005', 'then')")
        con.execute(
            "INSERT INTO ci_job (run_id, slurm_job_id, section, cores, cores_billed, "
            "nodes_billed, gpus, elapsed_s) VALUES (1, '999', 'SIM', 128, 256, 2, 4, "
            "3600.0)"
        )
        con.commit()
        con.close()
        return db

    def test_save_succeeds_against_a_legacy_file(self, tmp_path):
        assert store.save(_usage(), self._legacy_db(tmp_path)) is True

    def test_history_survives_the_upgrade(self, tmp_path):
        db = self._legacy_db(tmp_path)
        store.save(_usage(expid="a006"), db)

        assert sorted(r["expid"] for r in store.summarize(db)) == ["a005", "a006"]

    @pytest.mark.parametrize("table", ["ci_run", "ci_job"])
    def test_upgraded_file_has_every_column_a_fresh_one_has(self, tmp_path, table):
        legacy = self._legacy_db(tmp_path)
        store.save(_usage(), legacy)
        fresh = tmp_path / "fresh.db"
        store.save(_usage(), fresh)

        assert _columns(legacy, table) >= _columns(fresh, table)

    @pytest.mark.parametrize("table", ["ci_run", "ci_job"])
    def test_a_new_column_reaches_a_deployed_file(self, tmp_path, table, monkeypatch):
        """The whole point: declaring a column is all a future change needs."""
        declaration = f"CREATE TABLE IF NOT EXISTS {table} ("
        monkeypatch.setattr(
            store,
            "_SCHEMA",
            store._SCHEMA.replace(
                declaration, f"{declaration}\n    added_later TEXT DEFAULT 'x',"
            ),
        )
        db = self._legacy_db(tmp_path)

        assert store.save(_usage(), db) is True
        assert "added_later" in _columns(db, table)

    def test_removed_columns_are_left_in_place(self, tmp_path):
        """Dropping one from `_SCHEMA` must not disturb a file that still has it."""
        db = self._legacy_db(tmp_path)
        store.save(_usage(), db)

        assert "cpu_hours" in _columns(db, "ci_run")

    def test_existing_rows_are_backfilled_not_zeroed(self, tmp_path):
        db = self._legacy_db(tmp_path)
        store.save(_usage(), db)

        assert store.sections(db, expid="a005") == [
            {
                "name": "SIM",
                "job_count": 1,
                "core_hours_used": 128.0,
                "core_hours_billed": 256.0,
                "node_hours_billed": 2.0,
                "gpu_hours": 4.0,
                "elapsed_s": 3600.0,
            }
        ]

    def test_one_column_failing_does_not_lose_the_write(self, tmp_path, monkeypatch):
        """Two jobs racing: the loser's ALTER conflicts, its run still lands."""
        real = store.canonical_schema

        def with_an_unaddable_column():
            schema = real()
            schema["ci_run"]["impossible"] = "TEXT NOT NULL"
            return schema

        monkeypatch.setattr(store, "canonical_schema", with_an_unaddable_column)
        db = self._legacy_db(tmp_path)

        assert store.save(_usage(), db) is True
        assert "run_count" in _columns(db, "ci_run")

    def test_backfills_name_columns_that_exist(self):
        """A backfill left behind by a rename would fail on a deployed file only."""
        canonical = store.canonical_schema()
        for table, columns in store._BACKFILL.items():
            assert set(columns) <= set(canonical[table])


class TestSummarize:
    def test_returns_newest_first(self, tmp_path):
        db = tmp_path / "ci_resources.db"
        store.save(_usage(expid="a006", pipeline_id=1), db)
        store.save(_usage(expid="a007", pipeline_id=2), db)

        rows = store.summarize(db)
        assert [r["expid"] for r in rows] == ["a007", "a006"]

    def test_filters_by_expid(self, tmp_path):
        db = tmp_path / "ci_resources.db"
        store.save(_usage(expid="a006", pipeline_id=1), db)
        store.save(_usage(expid="a007", pipeline_id=2), db)

        rows = store.summarize(db, expid="a006")
        assert [r["expid"] for r in rows] == ["a006"]

    def test_missing_db_returns_empty(self, tmp_path):
        assert store.summarize(tmp_path / "absent.db") == []

    def test_does_not_create_the_database(self, tmp_path):
        db = tmp_path / "absent.db"
        store.summarize(db)
        assert not db.exists()


class TestDbPathResolution:
    def test_env_var_is_used_when_no_explicit_path(self, tmp_path, monkeypatch):
        db = tmp_path / "from_env.db"
        monkeypatch.setenv("CI_RESOURCES_DB", str(db))
        assert store.save(_usage()) is True
        assert db.exists()

    def test_explicit_path_wins_over_env(self, tmp_path, monkeypatch):
        monkeypatch.setenv("CI_RESOURCES_DB", str(tmp_path / "from_env.db"))
        explicit = tmp_path / "explicit.db"
        store.save(_usage(), explicit)
        assert explicit.exists()
        assert not (tmp_path / "from_env.db").exists()
