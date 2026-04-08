"""Subprocess execution helpers for running SLURM and system commands."""

import subprocess
from typing import List, Optional, Tuple


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
) -> Tuple[bool, str, Optional[str]]:
    """
    Execute a command via srun with --overlap on a specific node.

    Args:
        command: Command and arguments to execute.
        jobid: SLURM job ID for --overlap.
        node: Node name for --nodelist.
        account: Optional SLURM account (required in some clusters).
        timeout: Timeout in seconds.

    Returns:
        Tuple of (success, stdout, stderr_or_error_msg)

    Examples:
        >>> success, out, err = execute_srun(['hostname'], '12345', 'node01')
    """
    srun_cmd = [
        "srun",
        "--overlap",
        "--jobid",
        str(jobid),
        "--nodelist",
        node,
        "-n1",
        "-N1",
    ]
    if account:
        srun_cmd.extend(["--account", str(account)])
    srun_cmd.extend(command)

    return execute_command(srun_cmd, timeout)


def job_is_active(job_id: str) -> bool:
    """
    Check if a SLURM job is still active.

    Args:
        job_id: SLURM job ID.

    Returns:
        True if the job still appears in squeue; False otherwise.

    Examples:
        >>> job_is_active("12345")
        True  # if job 12345 is running
        >>> job_is_active("99999")
        False  # if job 99999 doesn't exist or completed
    """
    success, output, _ = execute_command(
        ["squeue", "-h", "-j", str(job_id)], timeout=15
    )
    return success and bool(output.strip())
