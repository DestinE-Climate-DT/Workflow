"""Subprocess execution helpers for running SLURM and system commands."""

import subprocess
from typing import Dict, List, Optional, Tuple


def execute_command(
    command: List[str], timeout: int = 30
) -> Tuple[bool, str, Optional[str]]:
    """
    Execute a command and return success status and output.

    Args:
        command: Command and arguments as list.
        timeout: Timeout in seconds.

    Returns:
        Tuple of (success, stdout, stderr_or_error_msg)
            - success: True if command succeeded (returncode 0)
            - stdout: Standard output as string
            - stderr_or_error_msg: Standard error or exception message (None if success)

    Examples:
        >>> success, out, err = execute_command(['echo', 'hello'])
        >>> success
        True
        >>> out.strip()
        'hello'
    """
    try:
        result = subprocess.run(
            command, capture_output=True, text=True, timeout=timeout, check=False
        )
        if result.returncode == 0:
            return True, result.stdout, None
        else:
            return False, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", f"Command timed out after {timeout} seconds"
    except Exception as e:
        return False, "", str(e)


def execute_srun(
    command: List[str],
    jobid: str,
    node: str,
    account: Optional[str] = None,
    timeout: int = 30,
    step_name: Optional[str] = None,
) -> Tuple[bool, str, Optional[str]]:
    """
    Execute a command via srun with --overlap on a specific node.

    Args:
        command: Command and arguments to execute.
        jobid: SLURM job ID for --overlap.
        node: Node name for --nodelist.
        account: Optional SLURM account (required in some clusters).
        timeout: Timeout in seconds.
        step_name: Short tag for the underlying command (e.g. "lscpu",
            "pidstat"). When provided, the step is labelled
            ``resource_monitor_<step_name>`` via ``--job-name`` so downstream
            sacct consumers can filter the monitor's own housekeeping steps
            out of chunk attribution.

    Returns:
        Tuple of (success, stdout, stderr_or_error_msg)

    Examples:
        >>> success, out, err = execute_srun(['hostname'], '12345', 'node01')
    """
    srun_cmd = build_srun_command(
        command=command,
        jobid=jobid,
        node=node,
        account=account,
        step_name=step_name,
    )
    return execute_command(srun_cmd, timeout)


def build_srun_command(
    command: List[str],
    jobid: str,
    node: str,
    account: Optional[str] = None,
    step_name: Optional[str] = None,
) -> List[str]:
    """
    Build the ``srun --overlap`` argv for a single-node overlap step.

    Factored out of execute_srun so callers that manage the process lifetime
    themselves (e.g. the persistent per-node sampler launched with
    subprocess.Popen) can reuse the exact same flags.

    Args:
        command: Command and arguments to execute on the node.
        jobid: SLURM job ID for --overlap.
        node: Node name for --nodelist.
        account: Optional SLURM account (required in some clusters).
        step_name: Short tag; when set the step is named
            ``resource_monitor_<step_name>`` via --job-name.

    Returns:
        The full srun argv as a list of strings.
    """
    # --exact + -c1 prevent the overlap step from inheriting --cpus-per-task
    # from the parent allocation (which would otherwise charge the step the full
    # task width — e.g. 14 logical cores on MN5 with -c 7 + SMT — in sacct).
    # Just -c1 here: it pins the monitor step to a single CPU.
    #
    # --mpi=none: these steps run non-MPI helpers (lscpu / pidstat / rocm-smi),
    # so they must NOT engage SLURM's PMI/MPI plugin. An overlap step that
    # initialises PMI on a node while the model's MPI ranks are launching can
    # corrupt the job's per-node PMI state — seen as 'PMI_Init returned 1' /
    # '_pmi_smp_barrier failed' aborting the model (notably Cray MPICH / ICON).
    srun_cmd = [
        "srun",
        "--overlap",
        "--exact",
        "--mpi=none",
        "--jobid",
        str(jobid),
        "--nodelist",
        node,
        "-n1",
        "-N1",
        "-c1",
    ]
    if step_name:
        srun_cmd.append(f"--job-name=resource_monitor_{step_name}")
    if account:
        srun_cmd.extend(["--account", str(account)])
    srun_cmd.extend(command)
    return srun_cmd


def get_step_job_names(job_id: str) -> Dict[str, str]:
    """
    Map each step id of a job to its JobName via sacct.

    sstat does not expose JobName, so this is how the sstat collector identifies
    (and drops) the monitor's own overlap steps (resource_monitor_*) and the
    lscpu topology probe from the raw snapshots. Best-effort: returns {} on
    failure so collection still proceeds (just unfiltered).

    Args:
        job_id: SLURM job id (base).

    Returns:
        Dict mapping step id (e.g. "12345.0") to JobName (e.g. "orted").
    """
    success, output, _ = execute_command(
        ["sacct", "-j", str(job_id), "-P", "-n", "--format=JobID,JobName"],
        timeout=15,
    )
    if not success or not output:
        return {}
    names: Dict[str, str] = {}
    for line in output.splitlines():
        line = line.strip()
        if "|" not in line:
            continue
        step_id, _, name = line.partition("|")
        names[step_id.strip()] = name.strip()
    return names
