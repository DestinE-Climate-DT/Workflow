"""Collector for sstat step statistics."""

from typing import Dict

from ....constants import SSTAT_FIELDS
from ....types.sstat import ProcessedStepStats
from ....utils.subprocess_helpers import execute_command
from .builder import build_step_stats
from .parser import parse_sstat_output


def collect_sstat_steps(job_id: str) -> Dict[str, ProcessedStepStats]:
    """
    Collect and process sstat data for all job steps.

    Executes 'sstat -j <jobid>', parses raw output, and processes each step
    into normalized ProcessedStepStats structures with typed fields and
    canonical units (bytes, seconds, etc.).

    This is the main entry point for sstat collection - it orchestrates:
    1. Command execution (sstat)
    2. Output parsing (parse_sstat_output)
    3. Data building (build_step_stats)

    Args:
        job_id: SLURM job ID (without .step suffix).

    Returns:
        dict: Dictionary mapping step_id to ProcessedStepStats (typed structures).
             Returns empty dict if sstat command fails or returns no data.

    Examples:
        >>> processed_steps = collect_sstat_steps('12345')
        >>> processed_steps['12345.0']['Memory_Related']['Physical_Memory']['Max_Bytes']
        4294967296
        >>> processed_steps['12345.batch']['CPU_Related']['CPU_Time_Stats']['Average_Cpu_Time_Seconds']
        3600.0
    """
    # Execute sstat command
    fmt = ",".join(SSTAT_FIELDS)
    success, output, error = execute_command(
        ["sstat", "-j", str(job_id), f"--format=JobID,{fmt}", "-P", "--noheader"],
        timeout=30,
    )
    if not success or not output:
        return {}

    # Parse raw sstat output
    raw_steps = parse_sstat_output(output)
    if not raw_steps:
        return {}

    # Build ProcessedStepStats for each step
    processed_steps: Dict[str, ProcessedStepStats] = {}
    for step_id, raw_data in raw_steps.items():
        try:
            processed_steps[step_id] = build_step_stats(job_id, step_id, raw_data)
        except Exception as e:
            print(f"WARNING: Failed to process step {step_id}: {e}")
            continue

    return processed_steps
