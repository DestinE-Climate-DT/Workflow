"""SLURM package - exports all SLURM-related functionality."""

from .scontrol import collect_job_metadata
from .tres import build_tres_allocated, parse_tres_string

__all__ = [
    "collect_job_metadata",
    "parse_tres_string",
    "build_tres_allocated",
]
