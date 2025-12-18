"""Builder for pidstat statistics structures.

This module contains builder functions to construct typed pidstat structures
from raw data, following the builder pattern used in other monitor modules.
"""

from typing import Any, Dict, List

from ..types.pidstat import (
    NodeGeneralInfo,
    NodeStats,
    NodeSummary,
    ProcessCpu,
    ProcessCtxSwitch,
    ProcessEntry,
    ProcessMemory,
    ProcessPaging,
    SummaryCounts,
    SummaryCpu,
    SummaryCtx,
    SummaryMem,
)


def build_process_entry(
    raw_data: Dict[str, Any],
    threads_per_core: int,
    job_mem_limit_bytes: int = 0,
) -> ProcessEntry:
    """
    Build ProcessEntry TypedDict from raw parsed data dictionary.

    Takes the raw dictionary from parser (with percentages and KB values)
    and performs all calculations and normalizations:
    - Converts CPU percentages to physical cores
    - Converts memory KB to bytes
    - Calculates memory percentages vs node and job limit

    Args:
        raw_data: Raw dictionary with lowercase snake_case keys from parser.
        threads_per_core: TPC value for converting logical to physical cores.
        total_node_mem_kb: Total node memory in KB (for calculating %MEM of node).
        job_mem_limit_bytes: Job memory limit in bytes (0 if unknown/unlimited).

    Returns:
        ProcessEntry: Typed dictionary with all process metrics normalized.

    Examples:
        >>> raw = {
        ...     'pid': '1234', 'uid': '1000', 'command': 'test',
        ...     'cpu_total_pct': 250.0,  # 250% on logical cores
        ...     'cpu_user_pct': 150.0, 'cpu_system_pct': 100.0,
        ...     'cpu_guest_pct': 0.0, 'cpu_wait_pct': 0.0,
        ...     'cpu_processor_id': '0',
        ...     'rss_kb': 1024, 'vss_kb': 2048, 'mem_pct': 0.5,
        ...     'minflt_per_sec': 10.0, 'majflt_per_sec': 0.0,
        ...     'cswch_per_sec': 5.0, 'nvcswch_per_sec': 0.5
        ... }
        >>> entry = build_process_entry(raw, threads_per_core=2)
        >>> entry['Pid']
        '1234'
        >>> entry['Cpu_Related']['Cpu_Physical_Cores']  # 250% / 100 / 2 TPC = 1.25
        1.25
    """
    # Convert CPU percentages to physical cores
    # Formula: physical_cores = (logical_percent / 100) / TPC
    # Example: 400% on TPC=2 → (400/100)/2 = 2.0 physical cores
    tpc = max(threads_per_core, 1)

    cpu_physical = round((raw_data["cpu_total_pct"] / 100.0) / tpc, 3)
    cpu_user_physical = round((raw_data["cpu_user_pct"] / 100.0) / tpc, 3)
    cpu_system_physical = round((raw_data["cpu_system_pct"] / 100.0) / tpc, 3)
    cpu_guest_physical = round((raw_data["cpu_guest_pct"] / 100.0) / tpc, 3)
    cpu_wait_physical = round((raw_data["cpu_wait_pct"] / 100.0) / tpc, 3)

    # Convert memory KB to bytes
    rss_bytes = raw_data["rss_kb"] * 1024
    vss_bytes = raw_data["vss_kb"] * 1024

    # Calculate memory percentage of job limit
    if job_mem_limit_bytes > 0:
        mem_pct_of_job = round((rss_bytes / job_mem_limit_bytes) * 100.0, 2)
    else:
        # If job limit is unknown or unlimited, set to 0.0
        mem_pct_of_job = 0.0

    return ProcessEntry(
        Pid=raw_data["pid"],
        Uid=raw_data["uid"],
        Command=raw_data["command"],
        Cpu_Related=ProcessCpu(
            Cpu_Physical_Cores=cpu_physical,
            Cpu_User_Physical_Cores=cpu_user_physical,
            Cpu_System_Physical_Cores=cpu_system_physical,
            Cpu_Guest_Physical_Cores=cpu_guest_physical,
            Cpu_Wait_Physical_Cores=cpu_wait_physical,
            CPU_Processor_ID=raw_data["cpu_processor_id"],
        ),
        Memory_Related=ProcessMemory(
            Rss_Bytes=rss_bytes,
            Vss_Bytes=vss_bytes,
            Memory_Percent_Of_Node=raw_data["mem_pct"],
            Memory_Percent_Of_Job_Limit=mem_pct_of_job,
        ),
        Paging_Related=ProcessPaging(
            Page_Faults_Minor_Per_Second=raw_data["minflt_per_sec"],
            Page_Faults_Major_Per_Second=raw_data["majflt_per_sec"],
        ),
        Context_Switches=ProcessCtxSwitch(
            Voluntary_Per_Second=max(raw_data["cswch_per_sec"], 0.0),
            Involuntary_Per_Second=max(raw_data["nvcswch_per_sec"], 0.0),
        ),
    )


def build_process_entries(
    raw_data_list: List[Dict[str, Any]],
    threads_per_core: int,
    job_mem_limit_bytes: int = 0,
) -> List[ProcessEntry]:
    """
    Build list of ProcessEntry TypedDicts from list of raw parsed data.

    Convenience function to build multiple ProcessEntry structures at once,
    applying same normalization parameters to all processes.

    Args:
        raw_data_list: List of raw dictionaries from parser.
        threads_per_core: TPC value for converting logical to physical cores.
        job_mem_limit_bytes: Job memory limit in bytes (0 if unknown/unlimited).

    Returns:
        List of ProcessEntry TypedDicts.

    Examples:
        >>> raw_list = [{'pid': '1234', 'uid': '1000', ...}, {'pid': '5678', 'uid': '1001', ...}]
        >>> entries = build_process_entries(raw_list, threads_per_core=2, job_mem_limit_bytes=1048576)
        >>> len(entries)
        2
    """
    return [
        build_process_entry(raw, threads_per_core, job_mem_limit_bytes)
        for raw in raw_data_list
    ]


def build_node_summary(
    processes: List[ProcessEntry],
    filtered_kernel_count: int,
) -> NodeSummary:
    """
    Build NodeSummary structure from list of processes.

    Aggregates CPU, memory, and context switch metrics from all processes.
    CPU values are expected to already be in physical cores.

    Args:
        processes: List of ProcessEntry dictionaries with normalized metrics.
        filtered_kernel_count: Number of kernel processes filtered out.

    Returns:
        NodeSummary: Aggregated summary with CPU, memory, context switches, and counts.

    Examples:
        >>> processes = [
        ...     {'Cpu_Related': {'Cpu_Physical_Cores': 2.5}, 'Memory_Related': {'Rss_Bytes': 1024000},
        ...      'Context_Switches': {'Voluntary_Per_Second': 10.0, 'Involuntary_Per_Second': 1.0}},
        ...     {'Cpu_Related': {'Cpu_Physical_Cores': 1.5}, 'Memory_Related': {'Rss_Bytes': 512000},
        ...      'Context_Switches': {'Voluntary_Per_Second': 5.0, 'Involuntary_Per_Second': 0.5}},
        ... ]
        >>> summary = build_node_summary(processes, filtered_kernel_count=3)
        >>> summary['Cpu_Related']['Total_Cpu_Physical_Cores']
        4.0
        >>> summary['Memory_Related']['Total_Memory_Bytes']
        1536000
    """
    # Aggregate metrics: CPU values are already in physical cores
    total_cpu_physical = sum(p["Cpu_Related"]["Cpu_Physical_Cores"] for p in processes)
    total_mem_bytes = sum(p["Memory_Related"]["Rss_Bytes"] for p in processes)
    total_vol = sum(p["Context_Switches"]["Voluntary_Per_Second"] for p in processes)
    total_invol = sum(
        p["Context_Switches"]["Involuntary_Per_Second"] for p in processes
    )

    return NodeSummary(
        Cpu_Related=SummaryCpu(
            Total_Cpu_Physical_Cores=round(total_cpu_physical, 2),
            Job_Cpu_Utilization_Percent=0.0,  # Will be updated later
        ),
        Memory_Related=SummaryMem(
            Total_Memory_Bytes=int(total_mem_bytes),
            Job_Memory_Of_Node_Percent=0.0,  # Will be updated later
            Job_Memory_Of_Job_Limit_Percent=0.0,  # Will be updated later
        ),
        Context_Switches=SummaryCtx(
            Total_Voluntary_Per_Second=round(total_vol, 2),
            Total_Involuntary_Per_Second=round(total_invol, 2),
        ),
        Counts=SummaryCounts(
            Process_Count=len(processes),
            Filtered_Kernel_Processes_Count=filtered_kernel_count,
        ),
    )


def build_node_general_info(
    cpu_section: str,
    mem_section: str,
    load_section: str,
) -> NodeGeneralInfo:
    """
    Build NodeGeneralInfo structure from system command outputs.

    Parses lscpu, free, and uptime outputs to extract node information.

    Args:
        cpu_section: Raw lscpu command output.
        mem_section: Raw free -k command output.
        load_section: Raw uptime command output.

    Returns:
        NodeGeneralInfo: Node information with CPU, memory, and load data.

    Examples:
        >>> cpu_out = "Architecture: x86_64\\nCPU(s): 64\\n..."
        >>> mem_out = "Mem: 528000000 256000000 ..."
        >>> load_out = "12:34:56 up 5 days, load average: 2.1, 1.8, 1.5"
        >>> info = build_node_general_info(cpu_out, mem_out, load_out)
        >>> info['Status']
        'success'
    """
    from ..system.parser import (
        parse_free_output,
        parse_lscpu_output,
        parse_uptime_output,
    )

    node_info: NodeGeneralInfo = {"Status": "success"}

    # CPU topology → PHYSICAL cores
    if cpu_section and "CPU_ERROR" not in cpu_section:
        cpu_info = parse_lscpu_output(cpu_section)
        if cpu_info:
            node_info["Cpu_Info"] = cpu_info  # type: ignore

    # Memory info
    if mem_section and "MEM_ERROR" not in mem_section:
        mem_info = parse_free_output(mem_section)
        if mem_info:
            node_info["Memory_Info"] = mem_info  # type: ignore

    # Load average
    if load_section and "LOAD_ERROR" not in load_section:
        load_info = parse_uptime_output(load_section)
        if load_info:
            node_info["Uptime_Raw"] = load_info.get("Uptime_Raw", "")
            if "Load_Average" in load_info:
                node_info["Load_Average"] = load_info["Load_Average"]  # type: ignore

    return node_info


def update_summary_utilization_percentages(
    summary: NodeSummary,
    node_info: NodeGeneralInfo,
    job_mem_limit_bytes: int = 0,
) -> None:
    """
    Update NodeSummary with utilization percentages based on node capacity.

    Modifies summary in-place to add CPU and memory utilization percentages.

    Args:
        summary: NodeSummary to update (modified in-place).
        node_info: NodeGeneralInfo with CPU and memory capacity info.
        job_mem_limit_bytes: Job's memory limit in bytes (0 if unlimited).

    Examples:
        >>> summary = NodeSummary(
        ...     Cpu_Related={'Total_Cpu_Physical_Cores': 32.0, 'Job_Cpu_Utilization_Percent': 0.0},
        ...     Memory_Related={'Total_Memory_Bytes': 10000000000,
        ...                     'Job_Memory_Of_Node_Percent': 0.0,
        ...                     'Job_Memory_Of_Job_Limit_Percent': 0.0},
        ...     Context_Switches={'Total_Voluntary_Per_Second': 100.0, 'Total_Involuntary_Per_Second': 10.0},
        ...     Counts={'Process_Count': 10, 'Filtered_Kernel_Processes_Count': 2},
        ... )
        >>> node_info = {'Cpu_Info': {'Total_Physical_Cores_Count': 64},
        ...              'Memory_Info': {'Total_Bytes': 100000000000}, 'Status': 'success'}
        >>> update_summary_utilization_percentages(summary, node_info, job_mem_limit_bytes=20000000000)
        >>> summary['Cpu_Related']['Job_Cpu_Utilization_Percent']
        50.0
    """
    cpu_info = node_info.get("Cpu_Info", {})
    mem_info = node_info.get("Memory_Info", {})

    total_physical_cores = cpu_info.get("Total_Physical_Cores_Count", 0)
    total_mem_bytes_node = mem_info.get("Total_Bytes", 0)

    # CPU utilization: Total_Cpu_Physical_Cores already represents physical cores used
    # Just need to compare to node's physical core capacity
    job_physical_cores = summary["Cpu_Related"]["Total_Cpu_Physical_Cores"]

    if total_physical_cores > 0:
        summary["Cpu_Related"]["Job_Cpu_Utilization_Percent"] = round(
            (job_physical_cores / total_physical_cores) * 100, 2
        )
    else:
        summary["Cpu_Related"]["Job_Cpu_Utilization_Percent"] = 0.0

    # Memory utilization vs node capacity
    if total_mem_bytes_node > 0:
        job_mem_bytes = summary["Memory_Related"]["Total_Memory_Bytes"]
        summary["Memory_Related"]["Job_Memory_Of_Node_Percent"] = round(
            (job_mem_bytes / total_mem_bytes_node) * 100, 2
        )

    # Memory utilization vs job limit (if available)
    if job_mem_limit_bytes > 0:
        job_mem_bytes = summary["Memory_Related"]["Total_Memory_Bytes"]
        summary["Memory_Related"]["Job_Memory_Of_Job_Limit_Percent"] = round(
            (job_mem_bytes / job_mem_limit_bytes) * 100, 2
        )


def build_error_node_stats(node_name: str, error_message: str) -> NodeStats:
    """
    Build a NodeStats structure for a failed node collection.

    Creates an error state NodeStats with zeroed metrics and error message.

    Args:
        node_name: Name of the node that failed.
        error_message: Error message describing the failure.

    Returns:
        NodeStats: NodeStats structure with error state.

    Examples:
        >>> stats = build_error_node_stats('node01', 'Connection timeout')
        >>> stats['Node_General_Info']['Status']
        'error'
        >>> stats['Summary']['Cpu_Related']['Total_Cpu_Physical_Cores']
        0.0
    """
    return NodeStats(
        Summary=NodeSummary(
            Cpu_Related=SummaryCpu(
                Total_Cpu_Physical_Cores=0.0,
                Job_Cpu_Utilization_Percent=0.0,
            ),
            Memory_Related=SummaryMem(
                Total_Memory_Bytes=0,
                Job_Memory_Of_Node_Percent=0.0,
                Job_Memory_Of_Job_Limit_Percent=0.0,
            ),
            Context_Switches=SummaryCtx(
                Total_Voluntary_Per_Second=0.0,
                Total_Involuntary_Per_Second=0.0,
            ),
            Counts=SummaryCounts(
                Process_Count=0,
                Filtered_Kernel_Processes_Count=0,
            ),
        ),
        Processes=[],
        Node_General_Info=NodeGeneralInfo(
            Status="error",
            Error=f"{node_name}: {error_message}",
        ),
    )
