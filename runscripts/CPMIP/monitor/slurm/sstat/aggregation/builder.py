"""Builder functions for aggregated sstat statistics structures.

This module contains helper functions to build aggregated structures
from accumulated data across multiple job steps.
"""

from typing import Dict

from ....types.sstat import (
    CpuFrequency,
    CpuTimeStats,
    EnergyBlock,
    IoEfficiency,
    MemoryBlock,
    MemoryEfficiency,
    PageFaultsBlock,
    StorageIOStats,
    TresUsageSection,
)


def build_aggregated_memory_block(
    max_bytes: int,
    total_bytes: float,
    num_steps: int,
    max_node: str,
    max_task: int,
) -> MemoryBlock:
    """
    Build an aggregated MemoryBlock from accumulated step data.

    Args:
        max_bytes: Maximum memory usage across all steps.
        total_bytes: Sum of average memory usage from all steps.
        num_steps: Number of steps aggregated.
        max_node: Node where maximum occurred.
        max_task: Task where maximum occurred.

    Returns:
        MemoryBlock: Aggregated memory metrics with Total_Across_Steps_Bytes.
    """
    avg_bytes = int(total_bytes / num_steps) if num_steps > 0 else 0
    return MemoryBlock(
        Max_Bytes=max_bytes,
        Average_Bytes=avg_bytes,
        Max_Node=max_node,
        Max_Task=max_task,
        Peak_To_Average_Ratio=(max_bytes / avg_bytes) if avg_bytes > 0 else 0.0,
        Total_Across_Steps_Bytes=int(total_bytes),
    )


def build_aggregated_memory_efficiency(
    max_vm_bytes: int,
    max_rss_bytes: int,
    total_vm_bytes: float,
    total_rss_bytes: float,
    num_steps: int,
) -> MemoryEfficiency:
    """
    Compute memory efficiency ratios from aggregated data.

    Args:
        max_vm_bytes: Maximum VM size across all steps.
        max_rss_bytes: Maximum RSS across all steps.
        total_vm_bytes: Sum of average VM from all steps.
        total_rss_bytes: Sum of average RSS from all steps.
        num_steps: Number of steps aggregated.

    Returns:
        MemoryEfficiency: Efficiency ratios.
    """
    ave_vm = total_vm_bytes / num_steps if num_steps > 0 else 0
    ave_rss = total_rss_bytes / num_steps if num_steps > 0 else 0

    return MemoryEfficiency(
        Physical_To_Virtual_Ratio=(max_rss_bytes / max_vm_bytes)
        if max_vm_bytes > 0
        else 0.0,
        Average_Memory_Utilization=(ave_rss / ave_vm) if ave_vm > 0 else 0.0,
        Memory_Waste_Percentage=(
            ((max_vm_bytes - max_rss_bytes) / max_vm_bytes) * 100.0
        )
        if max_vm_bytes > 0
        else 0.0,
        Memory_Consistency=(ave_rss / max_rss_bytes) if max_rss_bytes > 0 else 0.0,
    )


def build_aggregated_storage_stats(
    max_bytes: int,
    total_bytes: float,
    num_steps: int,
    max_node: str,
    max_task: int,
) -> StorageIOStats:
    """
    Build an aggregated StorageIOStats from accumulated step data.

    Args:
        max_bytes: Maximum I/O across all steps.
        total_bytes: Sum of average I/O from all steps.
        num_steps: Number of steps aggregated.
        max_node: Node where maximum occurred.
        max_task: Task where maximum occurred.

    Returns:
        StorageIOStats: Aggregated I/O statistics.
    """
    return StorageIOStats(
        Max_Bytes=max_bytes,
        Max_Node=max_node,
        Max_Task=max_task,
        Average_Bytes=int(total_bytes / num_steps) if num_steps > 0 else 0,
        Total_Across_Steps_Bytes=int(total_bytes),
    )


def build_aggregated_io_efficiency(
    max_read_bytes: int,
    max_write_bytes: int,
    total_read_bytes: float,
    total_write_bytes: float,
    num_steps: int,
) -> IoEfficiency:
    """
    Compute storage I/O efficiency from aggregated data.

    Args:
        max_read_bytes: Maximum read across all steps.
        max_write_bytes: Maximum write across all steps.
        total_read_bytes: Sum of average reads from all steps.
        total_write_bytes: Sum of average writes from all steps.
        num_steps: Number of steps aggregated.

    Returns:
        IoEfficiency: I/O efficiency metrics.
    """
    ave_read = total_read_bytes / num_steps if num_steps > 0 else 0
    ave_write = total_write_bytes / num_steps if num_steps > 0 else 0

    return IoEfficiency(
        Read_Write_Ratio=(max_read_bytes / max_write_bytes)
        if max_write_bytes > 0
        else float("inf"),
        Io_Consistency_Read=(ave_read / max_read_bytes) if max_read_bytes > 0 else 0.0,
        Io_Consistency_Write=(ave_write / max_write_bytes)
        if max_write_bytes > 0
        else 0.0,
        Total_Io_Bytes=max_read_bytes + max_write_bytes,
    )


def build_aggregated_cpu_stats(
    total_tasks: int,
    min_cpu_seconds: float,
    min_cpu_node: str,
    min_cpu_task: int,
    total_cpu_seconds: float,
) -> CpuTimeStats:
    """
    Build aggregated CpuTimeStats from accumulated step data.

    Args:
        total_tasks: Total number of tasks across all steps.
        min_cpu_seconds: Minimum CPU time across all steps.
        min_cpu_node: Node where minimum occurred.
        min_cpu_task: Task where minimum occurred.
        total_cpu_seconds: Total CPU time across all steps.

    Returns:
        CpuTimeStats: Aggregated CPU time statistics.
    """
    avg_cpu_seconds = total_cpu_seconds / total_tasks if total_tasks > 0 else 0.0

    return CpuTimeStats(
        Total_Tasks_Count=total_tasks,
        Min_Cpu_Time_Seconds=min_cpu_seconds
        if min_cpu_seconds != float("inf")
        else 0.0,
        Min_Cpu_Node=min_cpu_node,
        Min_Cpu_Task=min_cpu_task,
        Average_Cpu_Time_Seconds=avg_cpu_seconds,
        Cpu_Time_Variation=(
            (avg_cpu_seconds - min_cpu_seconds) / avg_cpu_seconds
            if avg_cpu_seconds > 0
            else 0.0
        ),
        Total_Cpu_Time_Seconds=total_cpu_seconds,
    )


def build_aggregated_cpu_frequency(
    total_freq_khz: float,
    freq_count: int,
    req_min_freq: str,
    req_max_freq: str,
    freq_governor: str,
) -> CpuFrequency:
    """
    Build aggregated CpuFrequency from accumulated step data.

    Args:
        total_freq_khz: Sum of average frequencies from all steps.
        freq_count: Number of steps with valid frequency data.
        req_min_freq: Requested minimum frequency (from any step).
        req_max_freq: Requested maximum frequency (from any step).
        freq_governor: Frequency governor (from any step).

    Returns:
        CpuFrequency: Aggregated CPU frequency information.
    """
    avg_freq = total_freq_khz / freq_count if freq_count > 0 else 0.0

    return CpuFrequency(
        Average_Frequency_KHz=avg_freq,
        Requested_Min_Frequency_KHz=req_min_freq,
        Requested_Max_Frequency_KHz=req_max_freq,
        Frequency_Governor=freq_governor,
    )


def build_aggregated_pagefaults(
    max_count: int,
    max_node: str,
    max_task: int,
    total_count: float,
    num_steps: int,
) -> PageFaultsBlock:
    """
    Build aggregated PageFaultsBlock from accumulated step data.

    Args:
        max_count: Maximum page faults across all steps.
        max_node: Node where maximum occurred.
        max_task: Task where maximum occurred.
        total_count: Sum of average page faults from all steps.
        num_steps: Number of steps aggregated.

    Returns:
        PageFaultsBlock: Aggregated page fault metrics.
    """
    return PageFaultsBlock(
        Max_Count=max_count,
        Max_Pages_Node=max_node,
        Max_Pages_Task=max_task,
        Average_Count=int(total_count / num_steps) if num_steps > 0 else 0,
        Total_Across_Steps_Count=int(total_count),
    )


def build_aggregated_energy(total_energy_joules: float) -> EnergyBlock:
    """
    Build aggregated EnergyBlock from accumulated step data.

    Args:
        total_energy_joules: Total energy consumption across all steps.

    Returns:
        EnergyBlock: Aggregated energy consumption.
    """
    return EnergyBlock(Total_Energy_Joules=total_energy_joules)


def build_aggregated_tres_section(
    ave_sum: Dict[str, float],
    max_dict: Dict[str, float],
    min_dict: Dict[str, float],
    total_dict: Dict[str, float],
    num_steps: int,
) -> TresUsageSection:
    """
    Build aggregated TresUsageSection from accumulated TRES data.

    Args:
        ave_sum: Sum of average TRES values from all steps.
        max_dict: Maximum TRES values across all steps.
        min_dict: Minimum TRES values across all steps.
        total_dict: Total TRES values across all steps.
        num_steps: Number of steps aggregated.

    Returns:
        TresUsageSection: Aggregated TRES usage section.
    """
    average = {k: v / num_steps for k, v in ave_sum.items()} if num_steps > 0 else {}

    return TresUsageSection(
        Average=average,  # type: ignore
        Maximum=dict(max_dict),  # type: ignore
        Minimum=dict(min_dict),  # type: ignore
        Total=dict(total_dict),  # type: ignore
    )
