from __future__ import annotations

from datetime import datetime
from typing import Iterable, List, Literal, Optional

from pydantic import BaseModel, Field

#: Where a job ran.  Only ``slurm`` holds an allocation and is charged.
Execution = Literal["slurm", "login", "local"]


class JobHistory(BaseModel):
    """One ``job_data`` row: one recorded attempt at running a job.

    Written whatever the platform, so it is the only record of login/VM jobs.
    """

    job_id: str
    job_name: Optional[str] = None
    run_id: Optional[int] = None
    counter: Optional[int] = None
    last: bool = True

    platform: Optional[str] = None
    status: Optional[str] = None
    ncpus: int = 0
    nnodes: int = 0
    start: int = 0
    finish: int = 0

    @property
    def elapsed_s(self) -> float:
        """Recorded wall time; 0 while a job is unfinished (``finish`` is 0)."""
        if self.start <= 0 or self.finish <= self.start:
            return 0.0
        return float(self.finish - self.start)


class JobUsage(BaseModel):
    """One job's footprint: a SLURM allocation, or a login-node/VM process."""

    job_id: str
    job_name: Optional[str] = None
    state: Optional[str] = None
    execution: Execution = "slurm"
    platform: Optional[str] = None
    nodes: int = 0
    cpus: int = 0
    gpus: int = 0
    elapsed_s: float = 0.0
    energy_joules: Optional[float] = None
    max_rss_bytes: Optional[int] = None

    # Resolved against the machine constants in machine.py; login/VM jobs, which
    # are never charged, keep `*_billed` at 0.
    cores: int = 0
    nodes_billed: int = 0
    cores_billed: int = 0

    # From Autosubmit's history DB.
    run_id: Optional[int] = None
    counter: Optional[int] = None
    section: Optional[str] = None

    @property
    def _hours(self) -> float:
        return self.elapsed_s / 3600.0

    @property
    def node_hours(self) -> float:
        return self.nodes * self._hours

    @property
    def node_hours_billed(self) -> float:
        return self.nodes_billed * self._hours

    @property
    def core_hours_used(self) -> float:
        return self.cores * self._hours

    @property
    def core_hours_billed(self) -> float:
        return self.cores_billed * self._hours

    @property
    def gpu_hours(self) -> float:
        return self.gpus * self._hours


def totals(jobs: Iterable[JobUsage]) -> dict:
    """Additive footprint quantities, keyed by :class:`UsageTotals`' field names."""
    jobs = list(jobs)
    return {
        "job_count": len(jobs),
        "node_hours": sum(j.node_hours for j in jobs),
        "node_hours_billed": sum(j.node_hours_billed for j in jobs),
        "core_hours_used": sum(j.core_hours_used for j in jobs),
        "core_hours_billed": sum(j.core_hours_billed for j in jobs),
        "gpu_hours": sum(j.gpu_hours for j in jobs),
        "elapsed_s": sum(j.elapsed_s for j in jobs),
        "energy_joules": sum(j.energy_joules or 0.0 for j in jobs),
    }


class UsageTotals(BaseModel):
    """The additive quantities :func:`totals` produces, for one grouping."""

    job_count: int = 0
    node_hours: float = 0.0
    node_hours_billed: float = 0.0
    core_hours_used: float = 0.0
    core_hours_billed: float = 0.0
    gpu_hours: float = 0.0
    energy_joules: float = 0.0
    elapsed_s: float = 0.0


class SectionUsage(UsageTotals):
    """One Autosubmit section's share of the experiment's footprint."""

    section: str

    @property
    def core_hours_billed_avg(self) -> float:
        return self.core_hours_billed / self.job_count if self.job_count else 0.0


class ExecutionUsage(UsageTotals):
    """One execution class's share: what SLURM ran, versus login and VM jobs."""

    execution: Execution


class ResourceUsage(BaseModel):
    """Combined HPC resource footprint of one CI experiment."""

    expid: str
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())

    # CI provenance: what to compare two footprints across.
    pipeline_id: Optional[int] = None
    commit_sha: Optional[str] = None
    mr_iid: Optional[int] = None
    type_name: Optional[str] = None
    hpc: Optional[str] = None

    # Over every job, superseded attempts and login/VM ones included; only
    # `*_billed` is what an allocation is actually charged.
    job_count: int = 0
    node_hours: float = 0.0
    node_hours_billed: float = 0.0
    core_hours_used: float = 0.0
    core_hours_billed: float = 0.0
    gpu_hours: float = 0.0
    elapsed_s: float = 0.0
    energy_joules: float = 0.0
    peak_rss_bytes: Optional[int] = None
    jobs: List[JobUsage] = Field(default_factory=list)

    #: More than one means the experiment was re-run; totals span all of them.
    run_ids: List[int] = Field(default_factory=list)

    #: Same totals broken down by Autosubmit section (SIM, DQC, TRANSFER, ...).
    sections: List[SectionUsage] = Field(default_factory=list)

    #: Same totals split by where the job ran (slurm / login / local).
    executions: List[ExecutionUsage] = Field(default_factory=list)

    @property
    def energy_kwh(self) -> float:
        return self.energy_joules / 3.6e6

    def usage_for(self, execution: Execution) -> Optional[ExecutionUsage]:
        """Totals for one execution class, or None if nothing ran there."""
        return next((e for e in self.executions if e.execution == execution), None)

    @property
    def slurm_job_count(self) -> int:
        """Allocations only -- what ``sacct`` could account for."""
        usage = self.usage_for("slurm")
        return usage.job_count if usage else 0

    @property
    def unscheduled(self) -> UsageTotals:
        """Login-node and VM jobs: real consumption, never billed."""
        return UsageTotals(
            **{
                field: sum(
                    getattr(e, field) for e in self.executions if e.execution != "slurm"
                )
                for field in UsageTotals.model_fields
            }
        )

    @property
    def peak_rss_gb(self) -> Optional[float]:
        if self.peak_rss_bytes is None:
            return None
        return self.peak_rss_bytes / 1024.0**3
