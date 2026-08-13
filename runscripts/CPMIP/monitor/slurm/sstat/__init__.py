"""SLURM sstat package - exports step statistics and aggregation functions.

This package is organized into two main submodules:
- steps: Functions for collecting, parsing, and building individual job steps
- aggregation: Functions for aggregating multiple steps into summaries
"""

# Import from steps submodule
from .steps import (
    build_step_stats,
    collect_sstat_steps,
    parse_sstat_output,
)

# Import from aggregation submodule
from .aggregation import aggregate_sstat_steps

__all__ = [
    # Step collection and processing
    "collect_sstat_steps",
    "parse_sstat_output",
    "build_step_stats",
    # Aggregation
    "aggregate_sstat_steps",
]
