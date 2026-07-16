"""Aggregator for processed SLURM sstat step statistics.

This module aggregates ProcessedStepStats (typed, normalized data)
into a single AggregatedStats summary.
"""

from typing import Any, Dict

from ....types.sstat import (
    AggregatedCpuRelated,
    AggregatedMemoryRelated,
    AggregatedStats,
    AggregatedStorageIO,
    AggregatedTresUsage,
    ProcessedStepStats,
)
from .builder import (
    build_aggregated_cpu_frequency,
    build_aggregated_cpu_stats,
    build_aggregated_energy,
    build_aggregated_io_efficiency,
    build_aggregated_memory_block,
    build_aggregated_memory_efficiency,
    build_aggregated_pagefaults,
    build_aggregated_storage_stats,
    build_aggregated_tres_section,
)


def aggregate_sstat_steps(
    processed_steps: Dict[str, ProcessedStepStats], jobid: str
) -> AggregatedStats:
    """
    Aggregate multiple processed job steps into a single summary.

    Takes ProcessedStepStats (with typed fields and canonical units) and
    produces AggregatedStats with proper aggregation logic for each metric type.

    Args:
        processed_steps: Map from step_id to ProcessedStepStats (typed structures).
        jobid: Base job ID (no '.step').

    Returns:
        Aggregated statistics across all steps with normalized units.

    Examples:
        >>> steps = collect_sstat_steps('12345')  # Dict[str, ProcessedStepStats]
        >>> aggregated = aggregate_sstat_steps(steps, '12345')
        >>> aggregated['Memory_Related']['Physical_Memory']['Max_Bytes']
        4294967296
    """
    if not processed_steps:
        return _build_empty_aggregated_stats(jobid)

    num_steps = len(processed_steps)

    # Initialize accumulators
    max_rss_bytes = 0
    max_rss_node = ""
    max_rss_task = 0
    total_rss_bytes = 0.0

    max_vm_bytes = 0
    max_vm_node = ""
    max_vm_task = 0
    total_vm_bytes = 0.0

    total_energy_joules = 0.0

    max_disk_read_bytes = 0
    max_disk_read_node = ""
    max_disk_read_task = 0
    total_disk_read_bytes = 0.0

    max_disk_write_bytes = 0
    max_disk_write_node = ""
    max_disk_write_task = 0
    total_disk_write_bytes = 0.0

    max_pages = 0
    max_pages_node = ""
    max_pages_task = 0
    total_pages = 0.0

    min_cpu_seconds = float("inf")
    min_cpu_node = ""
    min_cpu_task = 0
    total_cpu_seconds = 0.0
    total_tasks = 0

    total_cpu_freq_khz = 0.0
    freq_count = 0

    # TRES accumulators
    tres_in_ave_sum: Dict[str, float] = {}
    tres_in_max: Dict[str, float] = {}
    tres_in_min: Dict[str, float] = {}
    tres_in_total: Dict[str, float] = {}

    tres_out_ave_sum: Dict[str, float] = {}
    tres_out_max: Dict[str, float] = {}
    tres_out_min: Dict[str, float] = {}
    tres_out_total: Dict[str, float] = {}

    # First pass: collect data from all steps
    for step_id, step in processed_steps.items():
        # === MEMORY ===
        rss_mem = step["Memory_Related"]["Physical_Memory"]
        vm_mem = step["Memory_Related"]["Virtual_Memory"]

        # Track max RSS
        if rss_mem["Max_Bytes"] > max_rss_bytes:
            max_rss_bytes = rss_mem["Max_Bytes"]
            max_rss_node = rss_mem["Max_Node"]
            max_rss_task = rss_mem["Max_Task"]

        # Track max VM
        if vm_mem["Max_Bytes"] > max_vm_bytes:
            max_vm_bytes = vm_mem["Max_Bytes"]
            max_vm_node = vm_mem["Max_Node"]
            max_vm_task = vm_mem["Max_Task"]

        # Sum averages for total calculation
        total_rss_bytes += rss_mem["Average_Bytes"]
        total_vm_bytes += vm_mem["Average_Bytes"]

        # === ENERGY ===
        total_energy_joules += step["Energy_Consumption"]["Total_Energy_Joules"]

        # === DISK I/O ===
        disk_io = step["Disk_IO"]
        read_stats = disk_io["Read_Stats"]
        write_stats = disk_io["Write_Stats"]

        if read_stats["Max_Bytes"] > max_disk_read_bytes:
            max_disk_read_bytes = read_stats["Max_Bytes"]
            max_disk_read_node = read_stats["Max_Node"]
            max_disk_read_task = read_stats["Max_Task"]

        if write_stats["Max_Bytes"] > max_disk_write_bytes:
            max_disk_write_bytes = write_stats["Max_Bytes"]
            max_disk_write_node = write_stats["Max_Node"]
            max_disk_write_task = write_stats["Max_Task"]

        total_disk_read_bytes += read_stats["Average_Bytes"]
        total_disk_write_bytes += write_stats["Average_Bytes"]

        # === PAGE FAULTS ===
        page_faults = step["Page_Faults"]
        if page_faults["Max_Count"] > max_pages:
            max_pages = page_faults["Max_Count"]
            max_pages_node = page_faults["Max_Pages_Node"]
            max_pages_task = page_faults["Max_Pages_Task"]

        total_pages += page_faults["Average_Count"]

        # === CPU ===
        cpu_stats = step["CPU_Related"]["CPU_Time_Stats"]
        tasks_in_step = cpu_stats["Total_Tasks_Count"]
        total_tasks += tasks_in_step

        if cpu_stats["Min_Cpu_Time_Seconds"] < min_cpu_seconds:
            min_cpu_seconds = cpu_stats["Min_Cpu_Time_Seconds"]
            min_cpu_node = cpu_stats["Min_Cpu_Node"]
            min_cpu_task = cpu_stats["Min_Cpu_Task"]

        total_cpu_seconds += cpu_stats["Total_Cpu_Time_Seconds"]

        # CPU Frequency
        freq_info = step["CPU_Related"]["CPU_Frequency"]
        avg_freq = freq_info["Average_Frequency_KHz"]
        if avg_freq > 0:
            total_cpu_freq_khz += avg_freq
            freq_count += 1

        # === TRES USAGE ===
        tres_usage = step["TRES_Usage"]

        # Input resources
        _update_tres_dict(
            tres_in_ave_sum, tres_usage["Input_Resources"]["Average"], add=True
        )
        _update_tres_dict(
            tres_in_max, tres_usage["Input_Resources"]["Maximum"], take_max=True
        )
        _update_tres_dict(
            tres_in_min, tres_usage["Input_Resources"]["Minimum"], take_min=True
        )
        _update_tres_dict(
            tres_in_total, tres_usage["Input_Resources"]["Total"], add=True
        )

        # Output resources
        _update_tres_dict(
            tres_out_ave_sum, tres_usage["Output_Resources"]["Average"], add=True
        )
        _update_tres_dict(
            tres_out_max, tres_usage["Output_Resources"]["Maximum"], take_max=True
        )
        _update_tres_dict(
            tres_out_min, tres_usage["Output_Resources"]["Minimum"], take_min=True
        )
        _update_tres_dict(
            tres_out_total, tres_usage["Output_Resources"]["Total"], add=True
        )

    # === BUILD AGGREGATED STRUCTURES USING BUILDER FUNCTIONS ===

    # Get frequency settings from first step (they should be the same across steps)
    first_step = next(iter(processed_steps.values()))
    freq_info = first_step["CPU_Related"]["CPU_Frequency"]

    # Build all aggregated structures
    vm_block = build_aggregated_memory_block(
        max_vm_bytes, total_vm_bytes, num_steps, max_vm_node, max_vm_task
    )

    rss_block = build_aggregated_memory_block(
        max_rss_bytes, total_rss_bytes, num_steps, max_rss_node, max_rss_task
    )

    memory_efficiency = build_aggregated_memory_efficiency(
        max_vm_bytes, max_rss_bytes, total_vm_bytes, total_rss_bytes, num_steps
    )

    read_block = build_aggregated_storage_stats(
        max_disk_read_bytes,
        total_disk_read_bytes,
        num_steps,
        max_disk_read_node,
        max_disk_read_task,
    )

    write_block = build_aggregated_storage_stats(
        max_disk_write_bytes,
        total_disk_write_bytes,
        num_steps,
        max_disk_write_node,
        max_disk_write_task,
    )

    io_efficiency = build_aggregated_io_efficiency(
        max_disk_read_bytes,
        max_disk_write_bytes,
        total_disk_read_bytes,
        total_disk_write_bytes,
        num_steps,
    )

    cpu_stats = build_aggregated_cpu_stats(
        total_tasks, min_cpu_seconds, min_cpu_node, min_cpu_task, total_cpu_seconds
    )

    cpu_frequency = build_aggregated_cpu_frequency(
        total_cpu_freq_khz,
        freq_count,
        freq_info["Requested_Min_Frequency_KHz"],
        freq_info["Requested_Max_Frequency_KHz"],
        freq_info["Frequency_Governor"],
    )

    page_faults_block = build_aggregated_pagefaults(
        max_pages, max_pages_node, max_pages_task, total_pages, num_steps
    )

    energy_block = build_aggregated_energy(total_energy_joules)

    tres_in_section = build_aggregated_tres_section(
        tres_in_ave_sum, tres_in_max, tres_in_min, tres_in_total, num_steps
    )

    tres_out_section = build_aggregated_tres_section(
        tres_out_ave_sum, tres_out_max, tres_out_min, tres_out_total, num_steps
    )

    # Build final aggregated stats
    return AggregatedStats(
        Job_Id=jobid,
        Job_Name=f"Job_{jobid}",  # We don't have job name in ProcessedStepStats
        Memory_Related=AggregatedMemoryRelated(
            Virtual_Memory=vm_block,
            Physical_Memory=rss_block,
            Memory_Efficiency=memory_efficiency,
        ),
        Cpu_Related=AggregatedCpuRelated(
            Cpu_Time_Stats=cpu_stats,
            Cpu_Frequency=cpu_frequency,
            Estimated_Total_Core_Seconds=total_cpu_seconds,
        ),
        Page_Faults=page_faults_block,
        Energy_Consumption=energy_block,
        Storage_IO=AggregatedStorageIO(
            Read_Stats=read_block,
            Write_Stats=write_block,
            Io_Efficiency=io_efficiency,
        ),
        Tres_Usage=AggregatedTresUsage(
            Input_Resources=tres_in_section,
            Output_Resources=tres_out_section,
        ),
    )


def _update_tres_dict(
    target: Dict[str, float],
    source: Dict[str, Any],
    add: bool = False,
    take_max: bool = False,
    take_min: bool = False,
) -> None:
    """
    Update target TRES dict with values from source.

    Args:
        target: Dict to update (modified in-place).
        source: Dict with new values.
        add: If True, add values (for averaging/totaling).
        take_max: If True, take maximum value.
        take_min: If True, take minimum value.
    """
    for key, value in source.items():
        try:
            val = float(value) if not isinstance(value, (int, float)) else value
        except (ValueError, TypeError):
            continue

        if add:
            target[key] = target.get(key, 0.0) + val
        elif take_max:
            target[key] = max(target.get(key, float("-inf")), val)
        elif take_min:
            target[key] = min(target.get(key, float("inf")), val)


def _build_empty_aggregated_stats(jobid: str) -> AggregatedStats:
    """Build empty AggregatedStats for error cases."""
    from ....types.sstat import (
        MemoryBlock,
        StorageIOStats,
        TresUsageSection,
    )

    empty_memory_block = MemoryBlock(
        Max_Bytes=0,
        Average_Bytes=0,
        Max_Node="",
        Max_Task=0,
        Peak_To_Average_Ratio=0.0,
    )

    empty_storage_stats = StorageIOStats(
        Max_Bytes=0,
        Max_Node="",
        Max_Task=0,
        Average_Bytes=0,
    )

    empty_tres_section = TresUsageSection(
        Average={},  # type: ignore
        Maximum={},  # type: ignore
        Minimum={},  # type: ignore
        Total={},  # type: ignore
    )

    return AggregatedStats(
        Job_Id=jobid,
        Job_Name="N/A",
        Memory_Related=AggregatedMemoryRelated(
            Virtual_Memory=empty_memory_block,
            Physical_Memory=empty_memory_block,
            Memory_Efficiency={
                "Physical_To_Virtual_Ratio": 0.0,
                "Average_Memory_Utilization": 0.0,
                "Memory_Waste_Percentage": 0.0,
                "Memory_Consistency": 0.0,
            },
        ),
        Cpu_Related=AggregatedCpuRelated(
            Cpu_Time_Stats={
                "Total_Tasks_Count": 0,
                "Min_Cpu_Time_Seconds": 0.0,
                "Min_Cpu_Node": "",
                "Min_Cpu_Task": 0,
                "Average_Cpu_Time_Seconds": 0.0,
                "Cpu_Time_Variation": 0.0,
                "Total_Cpu_Time_Seconds": 0.0,
            },
            Cpu_Frequency={
                "Average_Frequency_KHz": 0.0,
                "Requested_Min_Frequency_KHz": "Unknown",
                "Requested_Max_Frequency_KHz": "Unknown",
                "Frequency_Governor": "Unknown",
            },
            Estimated_Total_Core_Seconds=0.0,
        ),
        Page_Faults={
            "Max_Count": 0,
            "Max_Pages_Node": "",
            "Max_Pages_Task": 0,
            "Average_Count": 0,
            "Total_Across_Steps_Count": 0,
        },
        Energy_Consumption={"Total_Energy_Joules": 0.0},
        Storage_IO=AggregatedStorageIO(
            Read_Stats=empty_storage_stats,
            Write_Stats=empty_storage_stats,
            Io_Efficiency={
                "Read_Write_Ratio": 0.0,
                "Io_Consistency_Read": 0.0,
                "Io_Consistency_Write": 0.0,
                "Total_Io_Bytes": 0,
            },
        ),
        Tres_Usage=AggregatedTresUsage(
            Input_Resources=empty_tres_section,
            Output_Resources=empty_tres_section,
        ),
    )
