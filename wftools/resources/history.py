"""Read an experiment's job records out of Autosubmit's history database.

One ``job_data`` row per job per ``autosubmit run`` invocation, of which only
the latest carries ``last=1``.  All of them are read: every attempt consumed
resources, and login-node/VM jobs are recorded nowhere else.  Always read-only.
"""

from __future__ import annotations

import configparser
import os
import re
import sqlite3
from pathlib import Path
from typing import List, Optional

from loguru import logger

from wftools.resources.models import JobHistory

#: Fallback for deployments whose autosubmitrc does not declare `historicdb`.
_FALLBACK_HISTORY_DIRS = ("/esarchive/autosubmit/as_metadata/data",)

#: A 14-digit YYYYMMDDHHMMSS is a submit timestamp, not a SLURM id.
_TIMESTAMP = re.compile(r"(19|20)\d{12}")


def history_dirs() -> List[str]:
    """Candidate directories holding ``job_data_<expid>.db``, best first."""
    dirs: List[str] = []
    parser = configparser.ConfigParser()
    for rc in (
        os.environ.get("AUTOSUBMIT_CONFIGURATION", ""),
        os.path.expanduser("~/.autosubmitrc"),
        "/etc/autosubmitrc",
    ):
        if not rc or not os.path.isfile(rc):
            continue
        try:
            parser.read(rc)
        except configparser.Error:
            continue
        if parser.has_option("historicdb", "path"):
            dirs.append(parser.get("historicdb", "path"))
    dirs.extend(_FALLBACK_HISTORY_DIRS)
    return dirs


def find_history_db(expid: str, dirs: Optional[List[str]] = None) -> Optional[Path]:
    """Locate ``job_data_<expid>.db``, or None if no candidate directory has it."""
    for directory in dirs if dirs is not None else history_dirs():
        candidate = Path(directory) / f"job_data_{expid}.db"
        if candidate.is_file():
            return candidate
    return None


#: Read when present; older history schemas carry only the first few.
_COLUMNS = (
    "job_id",
    "job_name",
    "run_id",
    "counter",
    "last",
    "platform",
    "status",
    "ncpus",
    "nnodes",
    "start",
    "finish",
)


def _select(conn: sqlite3.Connection) -> List[sqlite3.Row]:
    present = {row[1] for row in conn.execute("PRAGMA table_info(job_data)")}
    columns = [c for c in _COLUMNS if c in present]
    conn.row_factory = sqlite3.Row
    return conn.execute(
        f"SELECT {', '.join(columns)} FROM job_data "
        "WHERE job_id IS NOT NULL AND job_id > 0"
    ).fetchall()


def job_records(expid: str, db_path: Optional[str | Path] = None) -> List[JobHistory]:
    """Return every job attempt Autosubmit recorded for `expid`.

    Keyed by ``(job_name, counter, job_id)`` so a recycled login-node PID is not
    mistaken for a duplicate.
    """
    path = Path(db_path) if db_path else find_history_db(expid)
    if path is None or not path.is_file():
        logger.warning("No history DB found for {}; accounting will be empty.", expid)
        return []

    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        try:
            rows = _select(conn)
        finally:
            conn.close()
    except sqlite3.Error as err:
        logger.warning("Could not read history DB {}: {}", path, err)
        return []

    records: dict[tuple, JobHistory] = {}
    for row in rows:
        fields = {k: v for k, v in dict(row).items() if v is not None}
        job_id = str(fields.pop("job_id"))
        if _TIMESTAMP.fullmatch(job_id):
            continue
        fields["last"] = bool(fields.get("last", 1))
        if not fields.get("job_name"):
            fields.pop("job_name", None)
        record = JobHistory(job_id=job_id, **fields)
        records.setdefault((record.job_name, record.counter, job_id), record)

    return sorted(records.values(), key=lambda r: (r.job_id, r.job_name or ""))
