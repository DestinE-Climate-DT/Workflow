from __future__ import annotations

import re
from collections.abc import Callable
from datetime import datetime
from pathlib import Path

from loguru import logger
from pydantic import ValidationError

from wftools.autosubmit.constants import (
    AS_DATA_ROOT,
    FAILED_STATUSES,
    SKIPPED_STATUSES,
)
from wftools.autosubmit.filesystem import (
    find_job_err,
    get_job_duration,
    parse_jobs_status_log,
)
from wftools.autosubmit.job_names import split_job_name
from wftools.domain.models import SlurmMetadata, TestCase
from wftools.resources.models import ResourceUsage
from wftools.util import extract_error_summary, strip_ansi


def extract_job_type(expid: str, job_name: str) -> str:
    """Display name for a job: its section plus the coordinates identifying it.

    Suitable for GitLab test-history tracking -- the section is stable across
    experiments, the context identifies the specific member/chunk/split::

        a006_LOCAL_SETUP        -> LOCAL_SETUP
        a006_19900101_fc0_1_SIM -> SIM [fc0_1]
    """
    parts = split_job_name(expid, job_name)
    if parts.section is None:
        return job_name
    return f"{parts.section} [{parts.context}]" if parts.context else parts.section


def extract_job_errors(expid: str, run_log: str) -> dict[str, str]:
    """Extract per-job error snippets from the autosubmit run log.

    Scans for lines matching ``Job {expid}_xxx is (FAILED|ABORTED)`` and
    returns surrounding context (200 chars before, 500 chars after) for
    each failed job.

    Parameters
    ----------
    expid:
        Experiment identifier (e.g. ``a006``).
    run_log:
        Full text of the Autosubmit run log.

    Returns
    -------
    dict[str, str]
        Mapping of job_name to error context snippet.
    """
    errors: dict[str, str] = {}
    failed_pattern = re.compile(rf"Job ({re.escape(expid)}_\S+) is (FAILED|ABORTED)")
    for match in failed_pattern.finditer(run_log):
        job_name = match.group(1)
        start = max(0, match.start() - 200)
        end = min(len(run_log), match.end() + 500)
        errors[job_name] = run_log[start:end].strip()
    return errors


def parse_status_tree(
    expid: str,
    status_text: str,
    *,
    slurm_metadata: dict[str, SlurmMetadata] | None = None,
    job_errors: dict[str, str] | None = None,
    err_finder: Callable[[str], str | None] | None = None,
    duration_finder: Callable[[str], float | None] | None = None,
    name_prefix: str = "",
) -> list[TestCase]:
    """Parse an Autosubmit status tree into a list of ``TestCase`` objects.

    This is a **pure** function: it receives all data through its
    arguments and performs no filesystem I/O.

    Parameters
    ----------
    expid:
        Experiment identifier (e.g. ``a006``).
    status_text:
        Raw output from ``autosubmit monitor -txt --hide``.
    slurm_metadata:
        Optional mapping of job_name to ``SlurmMetadata``.
    job_errors:
        Optional mapping of job_name to error context snippet from the
        run log.
    err_finder:
        Optional callable ``(job_name) -> err_content | None`` for
        fetching ``.err`` file content.
    duration_finder:
        Optional callable ``(job_name) -> seconds | None`` for fetching
        job wall-clock duration.

    Returns
    -------
    list[TestCase]
        One ``TestCase`` per job found in the tree.
    """
    if slurm_metadata is None:
        slurm_metadata = {}
    if job_errors is None:
        job_errors = {}

    status_re = re.compile(r"\[(\w+)\]\s*$")

    cases: list[TestCase] = []

    for line in status_text.splitlines():
        cleaned = strip_ansi(line)
        cleaned = re.sub(r"^[\s|]+", "", cleaned).strip()

        if not cleaned:
            continue
        if cleaned.startswith("#"):
            continue

        first_token = cleaned.split()[0]
        if not first_token.startswith(expid):
            continue

        job_name = first_token

        status_match = status_re.search(cleaned)
        if not status_match:
            continue
        status = status_match.group(1)

        passed = status == "COMPLETED"
        skipped = status in SKIPPED_STATUSES
        failed = status in FAILED_STATUSES

        # Collect error content for failed jobs
        err_content: str | None = None
        if failed and err_finder is not None:
            err_content = err_finder(job_name)
        if err_content is None and job_name in job_errors:
            err_content = job_errors[job_name]

        # SLURM metadata
        slurm_info = slurm_metadata.get(job_name, SlurmMetadata())

        # Duration
        duration: float | None = None
        if duration_finder is not None:
            duration = duration_finder(job_name)

        display_name = extract_job_type(expid, job_name)
        if name_prefix:
            display_name = f"{name_prefix}{display_name}"

        error_summary: str | None = None
        if err_content:
            error_summary = extract_error_summary(err_content)

        cases.append(
            TestCase(
                name=display_name,
                full_job_name=job_name,
                classname=expid,
                passed=passed,
                skipped=skipped,
                timestamp=datetime.now().isoformat(),
                error=err_content if failed else None,
                error_summary=error_summary,
                status=status,
                slurm=slurm_info,
                duration=duration,
            )
        )

    return cases


def read_accounted_durations(path: Path | None) -> dict[str, float]:
    """Elapsed seconds per job name from a ``destine resources report`` JSON.

    That phase runs before the report is parsed and takes its times from
    ``sacct``, so it has them for jobs whose ``_STAT_`` file Autosubmit has not
    recovered from the HPC yet.  A missing or unreadable file is not an error:
    the durations are a nicety, the report is not.
    """
    if path is None or not path.is_file():
        return {}
    try:
        usage = ResourceUsage.model_validate_json(path.read_text())
    except (OSError, ValidationError) as exc:
        logger.warning("Ignoring unreadable durations file {}: {}", path, exc)
        return {}
    return {
        job.job_name: job.elapsed_s
        for job in usage.jobs
        if job.job_name and job.elapsed_s > 0
    }


def parse_experiment(
    expid: str,
    status_file: Path,
    run_log_file: Path | None = None,
    data_root: Path = AS_DATA_ROOT,
    name_prefix: str = "",
    durations_file: Path | None = None,
) -> list[TestCase]:
    """Orchestrate parsing of an Autosubmit experiment into ``TestCase`` objects.

    Reads the status file, optional run log, and SLURM metadata from the
    filesystem, then delegates to :func:`parse_status_tree`.

    Parameters
    ----------
    expid:
        Experiment identifier (e.g. ``a006``).
    status_file:
        Path to the ``autosubmit monitor -txt --hide`` output file.
    run_log_file:
        Optional path to the Autosubmit run log.
    data_root:
        Root of the Autosubmit data directory tree.  Defaults to
        ``/appl/AS/AUTOSUBMIT_DATA``.
    durations_file:
        Optional resource-accounting JSON, used for the jobs whose ``_STAT_``
        file has not been recovered yet.

    Returns
    -------
    list[TestCase]
        One ``TestCase`` per job in the status tree.
    """
    status_text = strip_ansi(status_file.read_text())

    job_errors: dict[str, str] = {}
    if run_log_file is not None and run_log_file.exists():
        job_errors = extract_job_errors(expid, strip_ansi(run_log_file.read_text()))

    log_dir = data_root / expid / "tmp" / f"LOG_{expid}"
    aslogs_dir = data_root / expid / "tmp" / "ASLOGS"

    slurm_metadata = parse_jobs_status_log(aslogs_dir, expid)
    accounted = read_accounted_durations(durations_file)

    def _err_finder(job_name: str) -> str | None:
        return find_job_err(log_dir, job_name)

    def _duration_finder(job_name: str) -> float | None:
        # Autosubmit's own record first; accounting fills what it has not
        # retrieved from the HPC yet.
        return get_job_duration(log_dir, job_name) or accounted.get(job_name)

    return parse_status_tree(
        expid,
        status_text,
        slurm_metadata=slurm_metadata,
        job_errors=job_errors,
        err_finder=_err_finder,
        duration_finder=_duration_finder,
        name_prefix=name_prefix,
    )
