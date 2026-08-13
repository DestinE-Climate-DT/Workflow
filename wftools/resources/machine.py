"""Per-machine constants and the used-vs-billed core-hour model.

``sacct`` reports ``NCPUS`` in hardware threads, and a multi-node job is charged
for whole nodes however few cores it asked for, so both the cores held (used)
and the cores charged (billed) are reported.  ``cores_per_node`` mirrors
``PROCESSORS_PER_NODE`` in ``conf/platforms.yml``.
"""

from __future__ import annotations

from typing import NamedTuple, Optional

from loguru import logger


class MachineSpec(NamedTuple):
    cores_per_node: int
    threads_per_core: int


_MACHINES = {
    "lumi": MachineSpec(cores_per_node=128, threads_per_core=2),
    "marenostrum5": MachineSpec(cores_per_node=112, threads_per_core=2),
}

#: Unknown HPC: billed collapses to used rather than inventing a number.
UNKNOWN = MachineSpec(cores_per_node=0, threads_per_core=1)


def spec_for(hpc: Optional[str]) -> MachineSpec:
    """Resolve an Autosubmit HPC name to its machine constants."""
    name = (hpc or "").lower()
    for known, spec in _MACHINES.items():
        if name.startswith(known) or (
            known == "marenostrum5" and name.startswith("mn5")
        ):
            return spec
    if name:
        logger.warning("Unknown HPC {!r}; billed core-hours fall back to used.", hpc)
    return UNKNOWN


def cores_used(ncpus: int, spec: MachineSpec) -> int:
    """Physical cores behind a SLURM ``NCPUS`` count."""
    return ncpus // spec.threads_per_core


def billed(cores: int, sacct_nodes: int, spec: MachineSpec) -> tuple[int, int]:
    """``(nodes_billed, cores_billed)``: as used below a node, whole nodes above."""
    if spec.cores_per_node <= 0:
        return sacct_nodes, cores

    nodes_used = -(-cores // spec.cores_per_node)  # ceil
    if nodes_used <= 1:
        return max(sacct_nodes, nodes_used), cores

    nodes = max(sacct_nodes, nodes_used)
    return nodes, nodes * spec.cores_per_node
