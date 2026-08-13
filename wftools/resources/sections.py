"""Group jobs by Autosubmit section and by where they ran, for the breakdowns."""

from __future__ import annotations

from typing import Callable, Iterable, List, Optional

from wftools.resources.models import ExecutionUsage, JobUsage, SectionUsage, totals


def _grouped(
    jobs: Iterable[JobUsage], key: Callable[[JobUsage], Optional[str]]
) -> list:
    """Bucket jobs by `key`, sorted; jobs with no key are skipped."""
    buckets: dict[str, List[JobUsage]] = {}
    for job in jobs:
        value = key(job)
        if value:
            buckets.setdefault(value, []).append(job)
    return sorted(buckets.items())


def summarize(jobs: Iterable[JobUsage]) -> List[SectionUsage]:
    """Aggregate by Autosubmit section, alphabetically."""
    return [
        SectionUsage(section=section, **totals(rows))
        for section, rows in _grouped(jobs, lambda job: job.section)
    ]


def by_execution(jobs: Iterable[JobUsage]) -> List[ExecutionUsage]:
    """Aggregate by execution class (slurm / login / local)."""
    return [
        ExecutionUsage(execution=execution, **totals(rows))
        for execution, rows in _grouped(jobs, lambda job: job.execution)
    ]
