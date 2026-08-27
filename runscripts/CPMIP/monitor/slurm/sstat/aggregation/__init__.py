"""SLURM sstat aggregation package - exports functions for aggregating multiple steps."""

from .aggregator import aggregate_sstat_steps

__all__ = [
    "aggregate_sstat_steps",
]
