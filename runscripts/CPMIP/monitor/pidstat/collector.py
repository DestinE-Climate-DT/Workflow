"""Collector for pidstat node statistics.

This module handles execution of pidstat on SLURM nodes and collection of
per-process statistics.
"""

from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Optional

from ..types.pidstat import NodeStats
from ..utils.subprocess_helpers import execute_srun
from .builder import (
    build_error_node_stats,
    build_node_general_info,
    build_node_summary,
    build_process_entries,
    update_summary_utilization_percentages,
)
from .parser import filter_kernel_process, parse_pidstat_output


def collect_single_node(
    node_name: str,
    pidstat_path: str,
    jobid: str,
    account: Optional[str] = None,
    job_mem_limit_bytes: int = 0,
    threads_per_core: int = 1,
    container_sif: Optional[str] = None,
) -> NodeStats:
    """
    Collect per-process stats on a single node with one srun call (normalized schema).
    Args:
        node_name: Node to query.
        pidstat_path: Full path to pidstat binary.
        jobid: SLURM job id (base).
        account: Optional SLURM account (required in some clusters when using --overlap).
        job_mem_limit_bytes: Job's memory limit in bytes (from SLURM metadata). Used to calculate
                             Memory_Percent_Of_Job_Limit. Set to 0 if unknown/unlimited.
        threads_per_core: Threads per core (TPC) for CPU normalization. Used to convert logical
                          core percentages from pidstat to physical cores. Default: 1 (no SMT/HT).
        container_sif: Optional path to Singularity SIF file. If provided, pidstat will be
                       executed inside the container.
    Returns:
        node_stats: Summary, Processes, Node_General_Info.
    """
    if not pidstat_path:
        raise ValueError("pidstat_path is required")

    # Prepare commands for sysinfo
    sysinfo_cmd = [
        "bash",
        "-c",
        (
            '{ uptime || echo LOAD_ERROR; } && echo "__SPLIT__" && '
            '{ lscpu || echo CPU_ERROR; } && echo "__SPLIT__" && '
            "{ free -k || echo MEM_ERROR; }"
        ),
    ]

    # Prepare commands for pidstat - with or without container
    if container_sif:
        # Use Singularity for pidstat
        pidstat_cmd = [
            "singularity",
            "exec",
            "--no-home",
            "--cleanenv",
            container_sif,
            "bash",
            "-c",
            f"{{ {pidstat_path} -urwh 1 1 || echo PIDSTAT_ERROR; }}",
        ]
    else:
        # Execute pidstat directly on host
        pidstat_cmd = [
            "bash",
            "-c",
            f"{{ {pidstat_path} -urwh 1 1 || echo PIDSTAT_ERROR; }}",
        ]

    # Execute both commands in parallel using threads
    sysinfo_output = ""
    pidstat_output = ""
    errors = []

    def run_sysinfo():
        success, output, error = execute_srun(
            command=sysinfo_cmd,
            jobid=jobid,
            node=node_name,
            account=account,
            timeout=30,
        )
        if not success:
            # Check for job termination signals
            if error and ("143" in error or "terminated" in error.lower()):
                return (
                    "sysinfo",
                    None,
                    f"Job terminated while collecting sysinfo on {node_name}",
                )
            return (
                "sysinfo",
                None,
                f"srun failed on node {node_name} (sysinfo): {error}",
            )
        return ("sysinfo", output, None)

    def run_pidstat():
        success, output, error = execute_srun(
            command=pidstat_cmd,
            jobid=jobid,
            node=node_name,
            account=account,
            timeout=30,
        )
        if not success:
            # Check for permission denied
            if error and "Permission denied" in error:
                return (
                    "pidstat",
                    None,
                    f"Permission denied executing pidstat on {node_name}. "
                    f"Check pidstat binary path and container permissions. "
                    f"Error: {error[:200]}",
                )
            # Check for job termination signals
            if error and ("143" in error or "terminated" in error.lower()):
                return (
                    "pidstat",
                    None,
                    f"Job terminated while collecting pidstat on {node_name}",
                )
            return (
                "pidstat",
                None,
                f"srun failed on node {node_name} (pidstat): {error}",
            )
        return ("pidstat", output, None)

    # Run both commands in parallel
    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = [executor.submit(run_sysinfo), executor.submit(run_pidstat)]

        for future in as_completed(futures):
            cmd_type, output, error = future.result()
            if error:
                errors.append(error)
            else:
                if cmd_type == "sysinfo":
                    sysinfo_output = output
                elif cmd_type == "pidstat":
                    pidstat_output = output

    # Check for errors - if job was terminated, log warning but don't crash
    if errors:
        # Check if all errors are job termination errors (exit 143 or signal-related)
        all_termination = all("Job terminated" in err for err in errors)
        if all_termination:
            # Job was terminated gracefully, just log warning
            print(f"WARNING: Job terminated while collecting data on {node_name}")
            # Raise to skip this node but don't crash the whole monitoring
            raise RuntimeError(
                f"Job terminated while collecting data on {node_name} (likely job finished)"
            )
        else:
            # Other errors - raise them
            raise RuntimeError("; ".join(errors))

    # Validate we got output from both commands
    if not sysinfo_output:
        raise RuntimeError(f"No sysinfo output received from {node_name}")
    if not pidstat_output:
        raise RuntimeError(f"No pidstat output received from {node_name}")

    # Parse sysinfo output (3 sections)
    sysinfo_sections = sysinfo_output.split("__SPLIT__")
    if len(sysinfo_sections) < 3:
        raise RuntimeError(f"Unexpected sysinfo output format from {node_name}")

    load_section, cpu_section, mem_section = sysinfo_sections[:3]

    # Parse pidstat output using dedicated parser function (returns raw dicts)
    raw_processes = parse_pidstat_output(pidstat_output=pidstat_output)

    # Build ProcessEntry TypedDicts from raw data (applies all normalizations)
    processes = build_process_entries(
        raw_processes, threads_per_core, job_mem_limit_bytes
    )
    # Filter out processes with zero CPU usage
    processes = [p for p in processes if p["Cpu_Related"]["Cpu_Physical_Cores"] > 0.0]

    # Count filtered kernel processes
    filtered_kernel = sum(1 for p in processes if filter_kernel_process(p["Command"]))

    # Build node summary using builder
    summary = build_node_summary(processes, filtered_kernel)

    # Build node general info using builder
    node_info = build_node_general_info(cpu_section, mem_section, load_section)

    # Update summary with utilization percentages
    update_summary_utilization_percentages(summary, node_info, job_mem_limit_bytes)

    return NodeStats(Summary=summary, Processes=processes, Node_General_Info=node_info)


def collect_node_stats(
    node_list: List[str],
    pidstat_path: str,
    jobid: str,
    account: Optional[str] = None,
    job_mem_limit_bytes: int = 0,
    threads_per_core: int = 1,
    container_sif: Optional[str] = None,
) -> Dict[str, NodeStats]:
    """
    Collect statistics from multiple nodes in parallel using a single srun per node.
    Args:
        node_list: Node names to collect.
        pidstat_path: Full path to pidstat executable.
        jobid: SLURM job id (base).
        account: Optional SLURM account (required in some clusters when using --overlap).
        job_mem_limit_bytes: Job's memory limit in bytes (from SLURM metadata). Used to calculate
                             Memory_Percent_Of_Job_Limit. Set to 0 if unknown/unlimited.
        threads_per_core: Threads per core (TPC) for CPU normalization. Used to convert logical
                          core percentages from pidstat to physical cores. Default: 1 (no SMT/HT).
        container_sif: Optional path to Singularity SIF file. If provided, pidstat and system
                       commands will be executed inside the container via 'singularity exec'.
    Returns:
        all_stats: Dict mapping node name -> node statistics dictionary.
    """
    if not node_list:
        print("Warning: No nodes to monitor")
        return {}

    max_workers = min(4, len(node_list))
    node_statistics: Dict[str, NodeStats] = {}

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_node = {
            executor.submit(
                collect_single_node,
                node,
                pidstat_path,
                jobid,
                account,
                job_mem_limit_bytes,
                threads_per_core,
                container_sif,
            ): node
            for node in node_list
        }
        for future in as_completed(future_to_node):
            node_name = future_to_node[future]
            try:
                node_stats = future.result(timeout=45)
                node_statistics[str(node_name)] = node_stats
            except Exception as e:
                error_msg = str(e)
                # Check if it's a job termination error
                if "Job terminated" in error_msg or "likely job finished" in error_msg:
                    print(
                        f"Warning: Node {node_name} data collection skipped (job finished)"
                    )
                else:
                    print(f"ERROR: Failed to collect stats for node {node_name}: {e}")
                # Store error state for failed node using builder
                node_statistics[str(node_name)] = build_error_node_stats(
                    str(node_name), str(e)
                )

    return node_statistics
