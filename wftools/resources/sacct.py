"""Parse ``sacct -p`` output (``|``-delimited, header-less) into resource usage."""

from __future__ import annotations

import re
from typing import List

from wftools.resources.models import JobUsage

# The CI template renders its `sacct -o` from this, so the two cannot drift.
SACCT_FORMAT = (
    "JobID,JobName,State,NNodes,NCPUS,Elapsed,ConsumedEnergyRaw,MaxRSS,AllocTRES"
)

_RSS_UNITS = {"K": 1024, "M": 1024**2, "G": 1024**3, "T": 1024**4, "P": 1024**5}


def parse_elapsed(value: str) -> float:
    """Convert a SLURM ``Elapsed`` string (``[DD-]HH:MM:SS``, ``MM:SS``) to seconds."""
    value = (value or "").strip()
    if not value:
        return 0.0
    days = 0
    if "-" in value:
        day_part, value = value.split("-", 1)
        days = int(day_part)
    parts = value.split(":")
    try:
        nums = [float(p) for p in parts]
    except ValueError:
        return 0.0
    if len(nums) == 3:
        h, m, s = nums
    elif len(nums) == 2:
        h, m, s = 0.0, nums[0], nums[1]
    elif len(nums) == 1:
        h, m, s = 0.0, 0.0, nums[0]
    else:
        return 0.0
    return days * 86400 + h * 3600 + m * 60 + s


def parse_mem(value: str) -> int | None:
    """Convert a SLURM memory string (e.g. ``1234K``, ``1.5G``) to bytes."""
    value = (value or "").strip()
    if not value:
        return None
    m = re.fullmatch(r"(\d+(?:\.\d+)?)([KMGTP]?)", value)
    if not m:
        return None
    num = float(m.group(1))
    unit = _RSS_UNITS.get(m.group(2), 1)
    return int(num * unit)


def extract_gpus(alloctres: str) -> int:
    """Pull the GPU count out of a SLURM ``AllocTRES`` string."""
    match = re.search(r"gres/gpu=(\d+)", alloctres or "")
    return int(match.group(1)) if match else 0


def _to_int(value: str) -> int:
    value = (value or "").strip()
    try:
        return int(value)
    except ValueError:
        return 0


def _to_float(value: str) -> float | None:
    value = (value or "").strip()
    if not value:
        return None
    try:
        return float(value)
    except ValueError:
        return None


def parse_sacct(text: str) -> List[JobUsage]:
    """Parse sacct output into allocation-level :class:`JobUsage` rows.

    Step rows (``<id>.batch``, ``<id>.extern``, ``<id>.<n>``) are folded into
    their parent's ``max_rss_bytes`` and ``energy_joules``, which the allocation
    row leaves empty; the rest of what they report would double-count it.
    Energy folds as a maximum, not a sum: the counter is per node over the
    step's own window, so overlapping steps each re-measure the same draw.
    """
    by_id: dict[str, JobUsage] = {}
    step_rss: dict[str, int] = {}
    step_energy: dict[str, float] = {}

    for line in text.splitlines():
        line = line.rstrip("\n")
        if not line.strip():
            continue
        fields = line.split("|")
        if len(fields) < 8:
            continue
        job_id, job_name, state, nnodes, ncpus, elapsed, energy, maxrss = fields[:8]
        alloctres = fields[8] if len(fields) > 8 else ""
        job_id = job_id.strip()
        if not job_id:
            continue

        rss = parse_mem(maxrss)
        joules = _to_float(energy)
        base_id = job_id.split(".", 1)[0]

        if "." in job_id:
            if rss is not None:
                step_rss[base_id] = max(step_rss.get(base_id, 0), rss)
            if joules is not None:
                step_energy[base_id] = max(step_energy.get(base_id, 0.0), joules)
            continue

        job = JobUsage(
            job_id=job_id,
            job_name=job_name.strip() or None,
            state=state.strip() or None,
            nodes=_to_int(nnodes),
            cpus=_to_int(ncpus),
            gpus=extract_gpus(alloctres),
            elapsed_s=parse_elapsed(elapsed),
            energy_joules=joules,
            max_rss_bytes=rss,
        )
        by_id[job_id] = job

    # Fold the step figures into their parent job.
    for base_id, job in by_id.items():
        rss = step_rss.get(base_id)
        if rss is not None and (job.max_rss_bytes is None or rss > job.max_rss_bytes):
            job.max_rss_bytes = rss
        # Where the allocation row does report energy it is already the widest
        # step's, so only fill it in when it is missing.
        if not job.energy_joules:
            job.energy_joules = step_energy.get(base_id, job.energy_joules)

    return list(by_id.values())
