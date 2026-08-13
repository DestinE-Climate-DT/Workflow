"""Tests for reading job records out of Autosubmit's history database.

Two behaviours matter: **every** recorded attempt is returned, not just the
``last=1`` row (superseded rows are the majority of the HPC cost), and rows for
login-node jobs come back complete enough to account for on their own.
"""

from __future__ import annotations

import sqlite3

from wftools.resources.history import find_history_db, history_dirs, job_records

_SCHEMA = """
CREATE TABLE job_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    counter INTEGER, job_name TEXT, job_id INTEGER, run_id INTEGER, last INTEGER
);
"""


def _make_db(tmp_path, expid, rows):
    db = tmp_path / f"job_data_{expid}.db"
    con = sqlite3.connect(db)
    con.executescript(_SCHEMA)
    con.executemany(
        "INSERT INTO job_data (counter, job_name, job_id, run_id, last) "
        "VALUES (?,?,?,?,?)",
        rows,
    )
    con.commit()
    con.close()
    return db


class TestJobRecords:
    def test_includes_superseded_attempts(self, tmp_path):
        """The bug this guards: `WHERE last=1` would return 1 of 3 allocations."""
        db = _make_db(
            tmp_path,
            "a006",
            [
                (0, "a006_SIM", 111, 1, 0),
                (1, "a006_SIM", 222, 2, 0),
                (2, "a006_SIM", 333, 3, 1),
            ],
        )
        records = job_records("a006", db)
        assert [r.job_id for r in records] == ["111", "222", "333"]
        assert [r.counter for r in records] == [0, 1, 2]
        assert [r.run_id for r in records] == [1, 2, 3]
        assert [r.last for r in records] == [False, False, True]

    def test_skips_rows_with_no_id(self, tmp_path):
        """job_id 0 means Autosubmit never recorded one."""
        db = _make_db(
            tmp_path,
            "a006",
            [(0, "a006_LOCAL_SETUP", 0, 1, 1), (0, "a006_SIM", 999, 1, 1)],
        )
        assert [r.job_id for r in job_records("a006", db)] == ["999"]

    def test_rejects_timestamp_shaped_ids(self, tmp_path):
        """A 14-digit YYYYMMDDHHMMSS is a submit time, not a SLURM id."""
        db = _make_db(
            tmp_path,
            "a006",
            [(0, "a006_SIM", 20260806120000, 1, 1), (0, "a006_DN", 4242, 1, 1)],
        )
        assert [r.job_id for r in job_records("a006", db)] == ["4242"]

    def test_deduplicates_repeated_ids(self, tmp_path):
        db = _make_db(
            tmp_path,
            "a006",
            [(0, "a006_SIM", 111, 1, 0), (0, "a006_SIM", 111, 1, 1)],
        )
        assert [r.job_id for r in job_records("a006", db)] == ["111"]

    def test_missing_db_returns_empty(self, tmp_path):
        assert job_records("a999", tmp_path / "absent.db") == []

    def test_corrupt_db_returns_empty(self, tmp_path):
        db = tmp_path / "job_data_a006.db"
        db.write_text("not a database")
        assert job_records("a006", db) == []

    def test_does_not_mutate_the_database(self, tmp_path):
        db = _make_db(tmp_path, "a006", [(0, "a006_SIM", 111, 1, 1)])
        before = db.read_bytes()
        job_records("a006", db)
        assert db.read_bytes() == before


_ROW_DEFAULTS = {
    "counter": 0,
    "run_id": 1,
    "last": 1,
    "platform": "MN5-LOGIN",
    "status": "COMPLETED",
    "ncpus": 4,
    "nnodes": 0,
    "start": 100,
    "finish": 200,
}


class TestFullSchema:
    """The columns login-node accounting needs, which older schemas may lack."""

    _FULL = """
    CREATE TABLE job_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        counter INTEGER, job_name TEXT, job_id INTEGER, run_id INTEGER,
        last INTEGER, platform TEXT, status TEXT, ncpus INTEGER,
        nnodes INTEGER, start INTEGER, finish INTEGER
    );
    """

    def _db(self, tmp_path, *rows):
        db = tmp_path / "job_data_a006.db"
        con = sqlite3.connect(db)
        con.executescript(self._FULL)
        columns = list(_ROW_DEFAULTS) + ["job_name", "job_id"]
        con.executemany(
            f"INSERT INTO job_data ({', '.join(columns)}) "
            f"VALUES ({', '.join(':' + c for c in columns)})",
            [{**_ROW_DEFAULTS, **row} for row in rows],
        )
        con.commit()
        con.close()
        return db

    def test_reads_platform_and_runtime(self, tmp_path):
        db = self._db(
            tmp_path,
            {"job_name": "a006_REMOTE_SETUP", "job_id": 4009345, "finish": 1880},
        )
        record = job_records("a006", db)[0]
        assert record.platform == "MN5-LOGIN"
        assert record.ncpus == 4
        assert record.elapsed_s == 1780.0

    def test_unfinished_job_has_no_elapsed(self, tmp_path):
        db = self._db(tmp_path, {"job_name": "a006_SIM", "job_id": 999, "finish": 0})
        assert job_records("a006", db)[0].elapsed_s == 0.0

    def test_a_pid_reused_by_another_job_is_kept(self, tmp_path):
        """Login-node PIDs recycle; deduplicating on id alone would lose one."""
        db = self._db(
            tmp_path,
            {"job_name": "a006_INI", "job_id": 300},
            {"job_name": "a006_AQUA_SETUP", "job_id": 300, "start": 300, "finish": 360},
        )
        records = job_records("a006", db)
        assert len(records) == 2
        assert {r.job_name for r in records} == {"a006_INI", "a006_AQUA_SETUP"}


class TestDbDiscovery:
    def test_find_history_db_searches_given_dirs(self, tmp_path):
        _make_db(tmp_path, "a006", [(0, "a006_SIM", 111, 1, 1)])
        found = find_history_db("a006", [str(tmp_path / "nope"), str(tmp_path)])
        assert found is not None and found.name == "job_data_a006.db"

    def test_find_history_db_returns_none_when_absent(self, tmp_path):
        assert find_history_db("a999", [str(tmp_path)]) is None

    def test_history_dirs_reads_autosubmitrc(self, tmp_path, monkeypatch):
        rc = tmp_path / "autosubmitrc"
        rc.write_text("[historicdb]\npath = /some/metadata/data\n")
        monkeypatch.setenv("AUTOSUBMIT_CONFIGURATION", str(rc))
        assert "/some/metadata/data" in history_dirs()
