"""Persist :class:`ResourceUsage` records into a shared SQLite database.

A queryable mirror of the per-experiment JSON artifact, never the source of
truth: every failure warns and returns False, so accounting can never turn a
merge request red.  The file is shared by every developer's CI job and is only
ever added to, never rebuilt -- a new column is declared in `_SCHEMA` and
deployed files gain it, and their history, on the next write.
"""

from __future__ import annotations

import json
import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator, Optional

from loguru import logger

from wftools.resources.models import ResourceUsage

#: Alongside Autosubmit's own databases, in the setgid group-writable dir.
DEFAULT_DB_PATH = "/appl/AS/AUTOSUBMIT_DATA/ci_resources.db"

#: Bumped only for a change `_add_columns` cannot make in place -- a renamed or
#: retyped column.  Not for an added one: that would stop every older writer.
SCHEMA_VERSION = 1

#: Group-writable: every developer's CI job writes this same file.
_DB_MODE = 0o664

_SCHEMA = """
CREATE TABLE IF NOT EXISTS ci_run (
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
    node_hours_billed REAL NOT NULL DEFAULT 0,
    core_hours_used   REAL NOT NULL DEFAULT 0,
    core_hours_billed REAL NOT NULL DEFAULT 0,
    gpu_hours      REAL    NOT NULL DEFAULT 0,
    elapsed_s      REAL    NOT NULL DEFAULT 0,
    energy_joules  REAL    NOT NULL DEFAULT 0,
    peak_rss_bytes INTEGER,
    run_count      INTEGER,
    raw_json       TEXT
);

CREATE TABLE IF NOT EXISTS ci_job (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id        INTEGER NOT NULL REFERENCES ci_run(id) ON DELETE CASCADE,
    -- A SLURM id for scheduled jobs, a PID for login-node and VM ones.
    slurm_job_id  TEXT    NOT NULL,
    job_name      TEXT,
    state         TEXT,
    execution     TEXT    NOT NULL DEFAULT 'slurm',
    platform      TEXT,
    nodes         INTEGER NOT NULL DEFAULT 0,
    cpus          INTEGER NOT NULL DEFAULT 0,
    cores         INTEGER NOT NULL DEFAULT 0,
    nodes_billed  INTEGER NOT NULL DEFAULT 0,
    cores_billed  INTEGER NOT NULL DEFAULT 0,
    gpus          INTEGER NOT NULL DEFAULT 0,
    elapsed_s     REAL    NOT NULL DEFAULT 0,
    -- Derived on the model, stored so queries never restate the formulas.
    core_hours_used   REAL NOT NULL DEFAULT 0,
    core_hours_billed REAL NOT NULL DEFAULT 0,
    node_hours_billed REAL NOT NULL DEFAULT 0,
    gpu_hours         REAL NOT NULL DEFAULT 0,
    energy_joules REAL,
    max_rss_bytes INTEGER,
    -- Autosubmit's run id/attempt; `run_id` above is the FK into ci_run.
    as_run_id     INTEGER,
    attempt       INTEGER,
    section       TEXT
);

CREATE INDEX IF NOT EXISTS idx_ci_run_expid    ON ci_run(expid);
CREATE INDEX IF NOT EXISTS idx_ci_run_commit   ON ci_run(commit_sha);
CREATE INDEX IF NOT EXISTS idx_ci_run_pipeline ON ci_run(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_ci_job_run      ON ci_job(run_id);
CREATE INDEX IF NOT EXISTS idx_ci_job_section  ON ci_job(section);
"""

#: How to populate a column added to a table that already holds rows; anything
#: absent here keeps its `_SCHEMA` DEFAULT.
_BACKFILL = {
    "ci_job": {
        "core_hours_used": "cores * elapsed_s / 3600.0",
        "core_hours_billed": "cores_billed * elapsed_s / 3600.0",
        "node_hours_billed": "nodes_billed * elapsed_s / 3600.0",
        "gpu_hours": "gpus * elapsed_s / 3600.0",
    },
}


def _resolve(db_path: Optional[str | Path]) -> Path:
    """Explicit path, else ``$CI_RESOURCES_DB``, else the deployed default."""
    return Path(db_path or os.environ.get("CI_RESOURCES_DB") or DEFAULT_DB_PATH)


def _read(query: str, params: tuple, db_path: Optional[str | Path]) -> list[dict]:
    """Run a read-only (``mode=ro``) query and return dict rows; [] on any failure."""
    path = _resolve(db_path)
    if not path.is_file():
        logger.warning("Resources DB {} not found.", path)
        return []

    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=30.0)
        try:
            conn.row_factory = sqlite3.Row
            return [dict(row) for row in conn.execute(query, params)]
        finally:
            conn.close()
    except sqlite3.Error as err:
        logger.warning("Could not read {}: {}", path, err)
        return []


@contextmanager
def _connect(db_path: Path) -> Iterator[sqlite3.Connection]:
    """Open `db_path`, creating it group-writable, with WAL and FK enforcement.

    The umask widens only around the connect call, which also creates the
    ``-wal`` / ``-shm`` sidecars; the login umask (0027) would leave all three
    unwritable by the next developer's job.
    """
    previous_umask = os.umask(0o002)
    try:
        conn = sqlite3.connect(str(db_path), timeout=30.0)
    finally:
        os.umask(previous_umask)

    try:
        # Best effort: only the owner may chmod; a co-developer's run carries on.
        try:
            os.chmod(db_path, _DB_MODE)
        except OSError:
            pass
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA busy_timeout=30000")
        conn.execute("PRAGMA foreign_keys=ON")  # off by default; ci_job cascades
        yield conn
    finally:
        conn.close()


def _column_ddl(decl_type: str, notnull: int, default: Optional[str]) -> str:
    ddl = decl_type
    if notnull:
        ddl += " NOT NULL"
    if default is not None:
        ddl += f" DEFAULT {default}"
    return ddl


def canonical_schema() -> dict[str, dict[str, str]]:
    """Each table `_SCHEMA` declares, mapped to its columns' ``ALTER``-ready DDL.

    Key and foreign-key columns are left out: SQLite can add neither.
    """
    conn = sqlite3.connect(":memory:")
    try:
        conn.executescript(_SCHEMA)
        tables = {}
        for (table,) in conn.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%'"
        ):
            keys = {row[3] for row in conn.execute(f"PRAGMA foreign_key_list({table})")}
            tables[table] = {
                name: _column_ddl(decl_type, notnull, default)
                for _, name, decl_type, notnull, default, pk in conn.execute(
                    f"PRAGMA table_info({table})"
                )
                if not pk and name not in keys
            }
        return tables
    finally:
        conn.close()


def _add_columns(conn: sqlite3.Connection) -> None:
    """Add every column `_SCHEMA` declares that an existing table is missing.

    `CREATE TABLE IF NOT EXISTS` is a no-op once a table exists, so this is what
    brings a deployed file up to date.  Nothing is ever dropped.
    """
    for table, columns in canonical_schema().items():
        present = {row[1] for row in conn.execute(f"PRAGMA table_info({table})")}
        missing = {c: ddl for c, ddl in columns.items() if c not in present}
        if not missing:
            continue

        added = []
        for column, ddl in missing.items():
            try:
                conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {ddl}")
                added.append(column)
            except sqlite3.OperationalError as err:
                # Another job added it between the read above and this write.
                logger.debug("Could not add {}.{}: {}", table, column, err)
        backfill = {
            c: expr for c, expr in _BACKFILL.get(table, {}).items() if c in added
        }
        if backfill:
            assignments = ", ".join(f"{c} = {expr}" for c, expr in backfill.items())
            conn.execute(f"UPDATE {table} SET {assignments}")
        logger.info("Added {} column(s) to {}.", len(added), table)


def _ensure_schema(conn: sqlite3.Connection) -> bool:
    """Create or upgrade the schema. False if the file is newer than this code."""
    found = conn.execute("PRAGMA user_version").fetchone()[0]
    if found > SCHEMA_VERSION:
        logger.warning(
            "Resources DB schema v{} is newer than this writer (v{}); not writing.",
            found,
            SCHEMA_VERSION,
        )
        return False
    conn.executescript(_SCHEMA)
    _add_columns(conn)
    if found < SCHEMA_VERSION:
        conn.execute(f"PRAGMA user_version={SCHEMA_VERSION}")
    return True


def _insert(conn: sqlite3.Connection, usage: ResourceUsage) -> int:
    """Replace any previous record for this (expid, pipeline_id) and insert.

    Delete-then-insert, not UPSERT: ``pipeline_id`` may be NULL, which UNIQUE
    treats as distinct and ``IS`` compares as equal.
    """
    conn.execute(
        "DELETE FROM ci_run WHERE expid = ? AND pipeline_id IS ?",
        (usage.expid, usage.pipeline_id),
    )
    cur = conn.execute(
        """
        INSERT INTO ci_run (
            expid, pipeline_id, commit_sha, mr_iid, type_name, hpc, created_at,
            job_count, node_hours, node_hours_billed, core_hours_used,
            core_hours_billed, gpu_hours, elapsed_s, energy_joules,
            peak_rss_bytes, run_count, raw_json
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
        (
            usage.expid,
            usage.pipeline_id,
            usage.commit_sha,
            usage.mr_iid,
            usage.type_name,
            usage.hpc,
            usage.timestamp,
            usage.job_count,
            usage.node_hours,
            usage.node_hours_billed,
            usage.core_hours_used,
            usage.core_hours_billed,
            usage.gpu_hours,
            usage.elapsed_s,
            usage.energy_joules,
            usage.peak_rss_bytes,
            len(usage.run_ids),
            usage.model_dump_json(),
        ),
    )
    # SQLite 3.34 has no INSERT ... RETURNING.
    run_id = cur.lastrowid
    conn.executemany(
        """
        INSERT INTO ci_job (
            run_id, slurm_job_id, job_name, state, execution, platform,
            nodes, cpus, cores, nodes_billed, cores_billed, gpus, elapsed_s,
            core_hours_used, core_hours_billed, node_hours_billed, gpu_hours,
            energy_joules, max_rss_bytes, as_run_id, attempt, section
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
        [
            (
                run_id,
                job.job_id,
                job.job_name,
                job.state,
                job.execution,
                job.platform,
                job.nodes,
                job.cpus,
                job.cores,
                job.nodes_billed,
                job.cores_billed,
                job.gpus,
                job.elapsed_s,
                job.core_hours_used,
                job.core_hours_billed,
                job.node_hours_billed,
                job.gpu_hours,
                job.energy_joules,
                job.max_rss_bytes,
                job.run_id,
                job.counter,
                job.section,
            )
            for job in usage.jobs
        ],
    )
    return run_id


def save(usage: ResourceUsage, db_path: Optional[str | Path] = None) -> bool:
    """Write `usage` and its jobs to the store; False and a warning on failure."""
    path = _resolve(db_path)
    if not path.parent.is_dir():
        logger.warning(
            "Resources DB directory {} does not exist; skipping.", path.parent
        )
        return False

    try:
        with _connect(path) as conn:
            with conn:  # BEGIN ... COMMIT, or ROLLBACK on exception
                if not _ensure_schema(conn):
                    return False
                run_id = _insert(conn, usage)
    except sqlite3.Error as err:
        logger.warning("Could not write resources to {}: {}", path, err)
        return False
    except OSError as err:
        logger.warning("Could not open resources DB {}: {}", path, err)
        return False

    logger.info(
        "Stored {} ({} jobs) in {} as run id {}.",
        usage.expid,
        usage.job_count,
        path,
        run_id,
    )
    return True


def summarize(
    db_path: Optional[str | Path] = None, expid: Optional[str] = None
) -> list[dict]:
    """Read back stored runs (newest first) -- for `destine resources history`."""
    query = (
        "SELECT expid, pipeline_id, commit_sha, type_name, hpc, created_at, "
        "job_count, node_hours, core_hours_used, core_hours_billed, gpu_hours, "
        "energy_joules, run_count FROM ci_run"
    )
    params: tuple = ()
    if expid:
        query += " WHERE expid = ?"
        params = (expid,)
    return _read(query + " ORDER BY id DESC", params, db_path)


def raw_usage(row_json: str) -> dict:
    """Parse a stored ``raw_json`` blob back into a plain dict."""
    return json.loads(row_json)


def sections(
    db_path: Optional[str | Path] = None, expid: Optional[str] = None
) -> list[dict]:
    """Per-section totals, aggregated straight out of ``ci_job``."""
    return _grouped_jobs("j.section", "j.section IS NOT NULL", expid, db_path)


def executions(
    db_path: Optional[str | Path] = None, expid: Optional[str] = None
) -> list[dict]:
    """Per-execution totals: what SLURM ran, versus login-node and VM jobs."""
    return _grouped_jobs("j.execution", "1", expid, db_path)


def _grouped_jobs(
    column: str, where: str, expid: Optional[str], db_path: Optional[str | Path]
) -> list[dict]:
    query = (
        f"SELECT {column} AS name, count(*) AS job_count, "
        "sum(j.core_hours_used) AS core_hours_used, "
        "sum(j.core_hours_billed) AS core_hours_billed, "
        "sum(j.node_hours_billed) AS node_hours_billed, "
        "sum(j.gpu_hours) AS gpu_hours, sum(j.elapsed_s) AS elapsed_s "
        f"FROM ci_job j JOIN ci_run r ON r.id = j.run_id WHERE {where}"
    )
    params: tuple = ()
    if expid:
        query += " AND r.expid = ?"
        params = (expid,)
    return _read(
        query + f" GROUP BY {column} ORDER BY core_hours_used DESC", params, db_path
    )
