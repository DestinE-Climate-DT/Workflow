"""
CPMIP Monitor - Modular SLURM Job Monitoring System

This package provides comprehensive monitoring capabilities for SLURM jobs including:
- Job metadata collection (scontrol)
- Step statistics collection (sstat)
- Node-level process monitoring (pidstat)
- System information gathering (lscpu, free, uptime)

Main entry points:
    - collect_job_metadata: Get job metadata from scontrol
    - collect_sstat_steps: Collect and process all job steps (ProcessedStepStats)
    - aggregate_sstat_steps: Aggregate multiple processed job steps
    - collect_node_stats: Collect per-node process statistics

Utility functions:
    - now_timestamp: Get current timestamp (epoch + ISO format)
    - save_json_gz: Save data to compressed JSON file
    - round_floats_2dp: Round floats to 2 decimal places
    - job_is_active: Check if SLURM job is still running
    - run_command: Execute shell command with timeout

Example:
    >>> from monitor import collect_job_metadata, collect_sstat_steps, aggregate_sstat_steps
    >>> metadata = collect_job_metadata("12345")
    >>> processed_steps = collect_sstat_steps("12345")  # Dict[str, ProcessedStepStats]
    >>> aggregated = aggregate_sstat_steps(processed_steps, "12345")
"""

# Main collectors - high-level API
from .slurm.scontrol.collector import collect_job_metadata
from .slurm.sstat import collect_sstat_steps, aggregate_sstat_steps
from .pidstat.collector import collect_node_stats, collect_single_node

# System info
from .system.detector import detect_threads_per_core

# Utility functions
from .utils.timestamps import now_timestamp
from .utils.json_helpers import save_json_gz, round_floats_2dp
from .utils.subprocess_helpers import job_is_active

__all__ = [
    # Collectors
    "collect_job_metadata",
    "collect_sstat_steps",
    "aggregate_sstat_steps",
    "collect_node_stats",
    "collect_single_node",
    "detect_threads_per_core",
    # Utilities
    "now_timestamp",
    "save_json_gz",
    "round_floats_2dp",
    "job_is_active",
]
