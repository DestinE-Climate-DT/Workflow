from __future__ import annotations

import re
from pathlib import Path

from wftools.autosubmit.constants import ERROR_FILE_CAP
from wftools.domain.models import SlurmMetadata
from wftools.util import strip_ansi


def find_job_err(log_dir: Path, job_name: str) -> str | None:
    """Find the most recent ``.err`` file for a job in a log directory.

    Autosubmit names retry files like
    ``a006_19900101_fc0_1_SIM.20260414102949.err``.  Multiple retries may
    exist; we sort by modification time and take the newest.

    Parameters
    ----------
    log_dir:
        Directory containing log files (e.g. ``LOG_{expid}``).
    job_name:
        Full Autosubmit job name (e.g. ``a006_19900101_fc0_1_SIM``).

    Returns
    -------
    str | None
        Stripped ANSI content of the newest ``.err`` file, capped at
        ``ERROR_FILE_CAP`` bytes (tail-biased), or ``None`` if nothing
        matches.
    """
    if not log_dir.is_dir():
        return None

    err_files = sorted(
        log_dir.glob(f"{job_name}.*.err"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    if not err_files:
        return None

    content = strip_ansi(err_files[0].read_text())

    if len(content) > ERROR_FILE_CAP:
        content = "... [truncated] ...\n" + content[-ERROR_FILE_CAP:]

    return content


def get_job_duration(log_dir: Path, job_name: str) -> float | None:
    """Compute job wall-clock duration from the STAT file.

    Autosubmit writes epoch timestamps to a ``_STAT_`` file in the LOG
    directory.  If the file contains at least two timestamps, the duration
    is ``last - first`` (in seconds).

    Parameters
    ----------
    log_dir:
        Directory containing log files.
    job_name:
        Full Autosubmit job name.

    Returns
    -------
    float | None
        Wall-clock seconds, or ``None`` when unavailable.
    """
    if not log_dir.is_dir():
        return None

    stat_files = sorted(log_dir.glob(f"*{job_name}*STAT*"), reverse=True)
    if not stat_files:
        return None

    try:
        lines = stat_files[0].read_text().strip().splitlines()
        timestamps = [float(ln.strip()) for ln in lines if ln.strip()]
        if len(timestamps) >= 2:
            return timestamps[-1] - timestamps[0]
    except (OSError, ValueError):
        pass

    return None


def parse_jobs_status_log(aslogs_dir: Path, expid: str) -> dict[str, SlurmMetadata]:
    """Parse SLURM metadata from Autosubmit jobs status log files.

    Reads both ``jobs_failed_status.log`` and ``jobs_active_status.log``
    from *aslogs_dir*.  The files use fixed-width columns where the job
    name and job ID may run together without whitespace.

    Parameters
    ----------
    aslogs_dir:
        Path to the ASLOGS directory of the experiment.
    expid:
        Experiment identifier (e.g. ``a006``).

    Returns
    -------
    dict[str, SlurmMetadata]
        Mapping of job_name to its SLURM metadata.
    """
    log_files = [
        aslogs_dir / "jobs_failed_status.log",
        aslogs_dir / "jobs_active_status.log",
    ]

    line_re = re.compile(
        rf"^({re.escape(expid)}\S+?)(\d{{5,}})\s+"
        r"(COMPLETED|FAILED|RUNNING|WAITING|UNKNOWN|SUSPENDED|HELD|ABORTED)\s+"
        r"(\S+)\s+(\S+)?"
    )

    metadata: dict[str, SlurmMetadata] = {}
    for log_file in log_files:
        if not log_file.is_file():
            continue
        try:
            lines = log_file.read_text().splitlines()
        except OSError:
            continue
        for line in lines[1:]:  # skip header
            m = line_re.match(line.strip())
            if m:
                job_name = m.group(1)
                metadata[job_name] = SlurmMetadata(
                    slurm_id=m.group(2),
                    platform=m.group(4),
                    queue=m.group(5) or "",
                )

    return metadata
