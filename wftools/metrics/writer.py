from __future__ import annotations

from pathlib import Path
from typing import Mapping

from wftools.domain.models import TestSuite


def write_metrics(metrics: Mapping[str, object], output: Path) -> None:
    """Write a GitLab custom-metrics file: one ``key value`` per line.

    Values are rendered as-is, so a caller that wants fixed precision passes a
    pre-formatted string.
    """
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("".join(f"{key} {value}\n" for key, value in metrics.items()))


def to_metrics(suite: TestSuite, output: Path) -> None:
    """Write the job-count metrics for a test suite.

    Only Autosubmit jobs count: ``full_job_name`` is set by `report parse` and
    by nothing else, so the phase-level cases the templates add (``*_monitor``,
    ``*_resources``) do not drift these away from ``hpc_jobs``/``login_jobs``.
    *completed* means passed, *failed* means not-passed-and-not-skipped, and
    *skipped* means explicitly skipped.
    """
    jobs = [c for c in suite.cases if getattr(c, "full_job_name", None)]
    write_metrics(
        {
            "completed_jobs": sum(1 for c in jobs if c.passed),
            "failed_jobs": sum(1 for c in jobs if not c.passed and not c.skipped),
            "skipped_jobs": sum(1 for c in jobs if c.skipped),
            "total_jobs": len(jobs),
        },
        output,
    )
