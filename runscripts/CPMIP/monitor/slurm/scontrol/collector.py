"""Collector for SLURM job metadata via scontrol."""

from typing import List, Optional

from ...types.slurm import JobMetadata
from ...utils.subprocess_helpers import execute_command
from ..tres import build_tres_allocated
from .builder import (
    build_empty_metadata,
    build_files_info,
    build_resource_info,
    build_timing_info,
)
from .parser import parse_alloc_node, parse_nodelist, parse_scontrol_output


def collect_job_metadata(
    job_id: str, threads_per_core: Optional[int] = None
) -> JobMetadata:
    """
    Retrieve and normalize job metadata via scontrol (one-shot).

    Executes 'scontrol show job <jobid>' and parses the output into a comprehensive
    typed metadata structure. All CPU counts are converted to PHYSICAL cores when TPC>1.

    Args:
        job_id: Base job id (no .step suffix).
        threads_per_core: Optional TPC override. If None, auto-detect from first node.

    Returns:
        JobMetadata: Comprehensive metadata with Pascal_Snake keys, canonical units,
                    and PHYSICAL core counts.

    Examples:
        >>> metadata = collect_job_metadata("12345")
        >>> metadata['Job_Name']
        'my_simulation'
        >>> metadata['Resource_Info']['Num_CPUs_Count']  # PHYSICAL cores
        64
    """
    notes: List[str] = []

    # Execute scontrol command
    success, output, error = execute_command(
        ["scontrol", "show", "job", str(job_id)], timeout=15
    )
    if not success:
        error_msg = f"scontrol command failed: {error}"
        print(f"ERROR: {error_msg}")
        return build_empty_metadata(job_id, error_msg)

    # Parse scontrol output
    flat = parse_scontrol_output(output)
    nodelist_info = parse_nodelist(flat.get("NodeList", ""))
    account = flat.get("Account", "")

    # Auto-detect TPC if not provided
    if threads_per_core is None:
        from ...system.detector import detect_threads_per_core

        threads_per_core, tpc_notes = detect_threads_per_core(
            nodelist_info["Nodes"], jobid=job_id, account=account if account else None
        )
        notes.extend(tpc_notes)

    # Parse AllocNode - try both "AllocNode:Sid" and "AllocNode"
    alloc_node_raw = flat.get("AllocNode:Sid", "") or flat.get("AllocNode", "")
    if not alloc_node_raw:
        notes.append("WARNING: AllocNode field is empty in scontrol output")
    alloc_node = parse_alloc_node(alloc_node_raw)

    # Parse TRES Allocated
    tres_alloc_str = flat.get("AllocTRES", "")
    tres_alloc_norm = build_tres_allocated(tres_alloc_str, threads_per_core)

    # Build structures using builder functions
    timing_info = build_timing_info(flat, notes)
    resource_info = build_resource_info(flat, threads_per_core)
    files_info = build_files_info(flat)

    # Construct final metadata
    metadata = JobMetadata(
        Job_Id=str(job_id),
        Job_Name=flat.get("JobName", "N/A"),
        Partition=flat.get("Partition", "N/A"),
        Account=account if account else "N/A",
        User_Id=flat.get("UserId", "N/A"),
        Quality_Of_Service=flat.get("QOS", "N/A"),
        State=flat.get("JobState") or flat.get("State", "N/A"),
        Exit_Code=flat.get("ExitCode", "N/A"),
        Allocated_Node_List=nodelist_info,
        Alloc_Node=alloc_node,
        Timing_Info=timing_info,
        Resource_Info=resource_info,
        Tres_Allocated=tres_alloc_norm,
        Files_Info=files_info,
        Threads_Per_Core_Count=threads_per_core,
    )

    if notes:
        metadata["Notes"] = notes

    return metadata
