"""Collector for sstat step statistics."""

from typing import Dict

from ....constants import SSTAT_FIELDS
from ....types.sstat import ProcessedStepStats
from ....utils.subprocess_helpers import execute_command, get_step_job_names
from .builder import build_step_stats
from .parser import parse_sstat_output


def collect_sstat_steps(job_id: str) -> Dict[str, ProcessedStepStats]:
    """
    Collect and process sstat data for all steps belonging to a job.

    Args:
        job_id: SLURM job ID (without .step suffix).

    Returns:
        dict: Dictionary mapping step_id to ProcessedStepStats (typed structures).
             Returns empty dict if sstat command fails or returns no data.

    Examples:
        >>> processed_steps = collect_sstat_steps('12345')
        >>> processed_steps['12345.0']['Memory_Related']['Physical_Memory']['Max_Bytes']
        4294967296
    """
    # Execute sstat command. -a/--allsteps is required to enumerate every
    # running step of the job; without it sstat reports only a single step,
    # so orted (and other chunk steps) are routinely missed.
    fmt = ",".join(SSTAT_FIELDS)
    success, output, error = execute_command(
        ["sstat", "-a", "-j", str(job_id), f"--format=JobID,{fmt}", "-P", "--noheader"],
        timeout=30,
    )
    if not success or not output:
        return {}

    # Parse raw sstat output
    raw_steps = parse_sstat_output(output)
    if not raw_steps:
        return {}

    # sstat carries no JobName, so resolve names via sacct to drop the monitor's
    # own overlap steps (resource_monitor_*) and the lscpu topology probe — they
    # are not part of the model run and must not appear in the raw snapshots.
    job_names = get_step_job_names(job_id)

    # Build ProcessedStepStats for each step
    processed_steps: Dict[str, ProcessedStepStats] = {}
    for step_id, raw_data in raw_steps.items():
        name = job_names.get(step_id, "")
        if name == "lscpu" or name.startswith("resource_monitor_"):
            continue
        try:
            processed_steps[step_id] = build_step_stats(job_id, step_id, raw_data)
        except Exception as e:
            print(f"WARNING: Failed to process step {step_id}: {e}")
            continue

    return processed_steps
