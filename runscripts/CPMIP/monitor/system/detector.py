"""System information detector - hardware topology detection."""

from typing import List, Optional, Tuple

from ..utils.subprocess_helpers import execute_srun


def detect_threads_per_core(
    node_list: List[str], jobid: Optional[str] = None, account: Optional[str] = None
) -> Tuple[int, List[str]]:
    """
    Detect Threads Per Core from the first available node using lscpu.

    Executes lscpu via srun on the first node and parses the output to determine
    the number of hardware threads per physical core (SMT/Hyperthreading factor).

    Args:
        node_list: List of node names to query.
        jobid: Optional SLURM job id for srun --overlap execution.
        account: Optional SLURM account (required in some clusters when using --overlap).

    Returns:
        tuple: (threads_per_core, notes)
            - threads_per_core: TPC value (1 if detection fails)
            - notes: List of warning messages if fallback is used

    Examples:
        >>> tpc, notes = detect_threads_per_core(['node01'], jobid='12345')
        >>> tpc
        2
        >>> notes
        []
    """
    notes: List[str] = []

    if not node_list:
        notes.append(
            "TPC detection failed: no nodes available. Using fallback TPC=1. "
            "CPU counts may represent logical cores."
        )
        return 1, notes

    # Try first node
    first_node = node_list[0]
    try:
        success, output, error = execute_srun(
            command=["lscpu"],
            jobid=jobid if jobid else "",
            node=first_node,
            account=account,
            timeout=10,
        )

        if success:
            for line in output.splitlines():
                if "Thread(s) per core:" in line:
                    tpc_str = line.split(":")[1].strip()
                    tpc = int(tpc_str)
                    if tpc > 0:
                        return tpc, notes

        notes.append(
            f"TPC detection failed: lscpu returned no valid data from node {first_node}. "
            f"Using fallback TPC=1. CPU counts may represent logical cores."
        )
        return 1, notes

    except Exception as e:
        notes.append(
            f"TPC detection failed: {e}. Using fallback TPC=1. "
            f"CPU counts may represent logical cores."
        )
        return 1, notes
