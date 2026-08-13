"""Build a :class:`ResourceUsage` and write it as JSON + GitLab metrics."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable, Optional

from wftools.autosubmit.job_names import split_job_name
from wftools.metrics.writer import write_metrics
from wftools.resources import machine, sections
from wftools.resources.models import JobHistory, JobUsage, ResourceUsage, totals
from wftools.resources.sacct import parse_sacct


def _from_history(record: JobHistory) -> JobUsage:
    """Account a job the scheduler never saw: real cores held, nothing billed."""
    return JobUsage(
        job_id=record.job_id,
        job_name=record.job_name,
        state=record.status,
        execution="local" if (record.platform or "").lower() == "local" else "login",
        platform=record.platform,
        nodes=record.nnodes,
        cpus=record.ncpus,
        cores=record.ncpus,
        elapsed_s=record.elapsed_s,
    )


def _is_ours(job: JobUsage, expid: str) -> bool:
    """Whether an allocation belongs to `expid`, by the job name sacct reported."""
    return not job.job_name or job.job_name.startswith(expid)


def _merge(
    sacct_jobs: Iterable[JobUsage], history: Iterable[JobHistory], expid: str
) -> list:
    """Pair Autosubmit's records with sacct's, one JobUsage per recorded job.

    A record is SLURM-backed when sacct answered its id with the same job name;
    a mismatch means the id is a colliding PID.
    """
    unclaimed = {job.job_id: job for job in sacct_jobs}
    jobs: list[JobUsage] = []

    for record in history:
        job = unclaimed.get(record.job_id)
        if job is None or (
            job.job_name and record.job_name and job.job_name != record.job_name
        ):
            jobs.append(_from_history(record))
            continue
        del unclaimed[record.job_id]
        job.run_id = record.run_id
        job.counter = record.counter
        job.platform = record.platform
        # sacct can omit the name; the history DB always has it.
        job.job_name = job.job_name or record.job_name
        jobs.append(job)

    # Allocations with no history row were still charged, so keep them -- but
    # not a stranger's job, which is what an aliased PID resolves to.
    jobs.extend(job for job in unclaimed.values() if _is_ours(job, expid))
    return jobs


def _apply_billing(jobs: Iterable[JobUsage], expid: str, hpc: Optional[str]) -> None:
    """Resolve each job's used/billed cores and its Autosubmit section."""
    spec = machine.spec_for(hpc)
    for job in jobs:
        job.section = split_job_name(expid, job.job_name).section
        if job.execution != "slurm":
            continue  # cores came from Autosubmit; nothing is billed
        job.cores = machine.cores_used(job.cpus, spec)
        job.nodes_billed, job.cores_billed = machine.billed(job.cores, job.nodes, spec)


def build_usage(
    expid: str,
    sacct_text: str,
    *,
    history: Optional[Iterable[JobHistory]] = None,
    pipeline_id: Optional[int] = None,
    commit_sha: Optional[str] = None,
    mr_iid: Optional[int] = None,
    type_name: Optional[str] = None,
    hpc: Optional[str] = None,
) -> ResourceUsage:
    """Combine sacct and Autosubmit's records into one ResourceUsage.

    The keyword-only arguments record which CI run produced these numbers.
    """
    jobs = _merge(parse_sacct(sacct_text), history or [], expid)
    _apply_billing(jobs, expid, hpc)

    peak_rss = [j.max_rss_bytes for j in jobs if j.max_rss_bytes is not None]
    return ResourceUsage(
        expid=expid,
        pipeline_id=pipeline_id,
        commit_sha=commit_sha,
        mr_iid=mr_iid,
        type_name=type_name,
        hpc=hpc,
        **totals(jobs),
        peak_rss_bytes=max(peak_rss) if peak_rss else None,
        jobs=jobs,
        run_ids=sorted({j.run_id for j in jobs if j.run_id is not None}),
        sections=sections.summarize(jobs),
        executions=sections.by_execution(jobs),
    )


def to_json(usage: ResourceUsage, output: Path) -> None:
    """Write the full ResourceUsage as pretty JSON."""
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(usage.model_dump_json(indent=2) + "\n")


def to_metrics(usage: ResourceUsage, output: Path) -> None:
    """Write GitLab custom metrics (``key value`` per line).

    The parent ``tsuite-collect`` job sums these across experiments, so every
    key must be additive; per-section figures stay in the JSON and the store.
    ``*_elapsed_hours`` is therefore summed over jobs -- concurrency makes it
    unrelated to how long the experiment took, hence the ``job_`` prefix.
    """
    unscheduled = usage.unscheduled
    metrics: dict[str, object] = {
        "hpc_jobs": usage.slurm_job_count,
        "login_jobs": unscheduled.job_count,
        "login_core_hours": f"{unscheduled.core_hours_used:.4f}",
        "login_job_elapsed_hours": f"{unscheduled.elapsed_s / 3600.0:.4f}",
        "node_hours": f"{usage.node_hours:.4f}",
        "node_hours_billed": f"{usage.node_hours_billed:.4f}",
        "core_hours_used": f"{usage.core_hours_used:.4f}",
        "core_hours_billed": f"{usage.core_hours_billed:.4f}",
        "gpu_hours": f"{usage.gpu_hours:.4f}",
        "job_elapsed_hours": f"{usage.elapsed_s / 3600.0:.4f}",
        "energy_kwh": f"{usage.energy_kwh:.4f}",
        "autosubmit_runs": len(usage.run_ids),
    }
    write_metrics(metrics, output)
