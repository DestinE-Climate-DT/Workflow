"""Builder for sstat statistics structures."""

from typing import Dict

from ....types.common import IoDirection, MemType
from ....types.sstat import (
    CpuFrequency,
    CpuTimeStats,
    EnergyBlock,
    IoEfficiency,
    MemoryBlock,
    MemoryEfficiency,
    PageFaultsBlock,
    ProcessedStepStats,
    StepCpuRelated,
    StepDiskIO,
    StepMemoryRelated,
    StepTresUsage,
    StorageIOStats,
)
from ...tres import build_tres_usage_section
from ....utils.converters import convert_to_float, convert_to_int
from ....utils.timestamps import convert_duration_to_seconds


def build_memory_block(raw_stats: Dict[str, str], mem_type: MemType) -> MemoryBlock:
    """
    Build MemoryBlock structure from raw sstat data.

    Parses MaxVMSize/MaxRSS and AveVMSize/AveRSS fields into bytes.

    Args:
        raw_stats: Raw sstat dictionary for a step or aggregate.
        mem_type: 'VM' (virtual memory) or 'RSS' (resident set size).

    Returns:
        MemoryBlock: Memory metrics normalized to bytes with metadata.

    Examples:
        >>> raw = {'MaxRSS': '4096M', 'AveRSS': '2048M', 'MaxRSSNode': 'node01', 'MaxRSSTask': '0'}
        >>> block = build_memory_block(raw, 'RSS')
        >>> block['Max_Bytes']
        4294967296
    """
    max_key = f"Max{mem_type}Size" if mem_type == "VM" else f"Max{mem_type}"
    ave_key = f"Ave{mem_type}Size" if mem_type == "VM" else f"Ave{mem_type}"

    max_bytes = convert_to_int(raw_stats.get(max_key, "0"))
    ave_bytes = convert_to_int(raw_stats.get(ave_key, "0"))

    return MemoryBlock(
        Max_Bytes=max_bytes,
        Average_Bytes=ave_bytes,
        Max_Node=raw_stats.get(f"{max_key}Node", ""),
        Max_Task=convert_to_int(raw_stats.get(f"{max_key}Task", "0")),
        Peak_To_Average_Ratio=(max_bytes / ave_bytes) if ave_bytes > 0 else 0.0,
    )


def build_memory_efficiency(raw_stats: Dict[str, str]) -> MemoryEfficiency:
    """
    Compute memory efficiency ratios based on RSS vs VM.

    Args:
        raw_stats: Raw sstat dictionary for a step or aggregate.

    Returns:
        MemoryEfficiency: Efficiency ratios (physical/virtual, waste, consistency).

    Examples:
        >>> raw = {'MaxVMSize': '8192M', 'MaxRSS': '4096M', 'AveVMSize': '6144M', 'AveRSS': '3072M'}
        >>> eff = build_memory_efficiency(raw)
        >>> eff['Physical_To_Virtual_Ratio']
        0.5
    """
    max_vm = convert_to_int(raw_stats.get("MaxVMSize", "0"))
    max_rss = convert_to_int(raw_stats.get("MaxRSS", "0"))
    ave_vm = convert_to_int(raw_stats.get("AveVMSize", "0"))
    ave_rss = convert_to_int(raw_stats.get("AveRSS", "0"))

    return MemoryEfficiency(
        Physical_To_Virtual_Ratio=(max_rss / max_vm) if max_vm > 0 else 0.0,
        Average_Memory_Utilization=(ave_rss / ave_vm) if ave_vm > 0 else 0.0,
        Memory_Waste_Percentage=(((max_vm - max_rss) / max_vm) * 100.0)
        if max_vm > 0
        else 0.0,
        Memory_Consistency=(ave_rss / max_rss) if max_rss > 0 else 0.0,
    )


def build_cpu_stats(raw_stats: Dict[str, str]) -> CpuTimeStats:
    """
    Build CpuTimeStats from raw sstat data.

    Parses NTasks, MinCPU, AveCPU and converts time strings to seconds.

    Args:
        raw_stats: Raw sstat dictionary for a step or aggregate.

    Returns:
        CpuTimeStats: CPU time statistics with all times in seconds.

    Examples:
        >>> raw = {'NTasks': '64', 'MinCPU': '00:30:00', 'AveCPU': '01:00:00', 'MinCPUNode': 'node01'}
        >>> stats = build_cpu_stats(raw)
        >>> stats['Average_Cpu_Time_Seconds']
        3600.0
    """
    n_tasks = convert_to_int(raw_stats.get("NTasks", "0"))
    min_cpu_sec = convert_duration_to_seconds(raw_stats.get("MinCPU", "0"))
    ave_cpu_sec = convert_duration_to_seconds(raw_stats.get("AveCPU", "0"))
    total_cpu_sec = ave_cpu_sec * n_tasks if n_tasks > 0 else 0.0

    return CpuTimeStats(
        Total_Tasks_Count=n_tasks,
        Min_Cpu_Time_Seconds=min_cpu_sec,
        Min_Cpu_Node=raw_stats.get("MinCPUNode", ""),
        Min_Cpu_Task=convert_to_int(raw_stats.get("MinCPUTask", "0")),
        Average_Cpu_Time_Seconds=ave_cpu_sec,
        Cpu_Time_Variation=((ave_cpu_sec - min_cpu_sec) / ave_cpu_sec)
        if ave_cpu_sec > 0
        else 0.0,
        Total_Cpu_Time_Seconds=total_cpu_sec,
    )


def build_cpu_frequency(raw_stats: Dict[str, str]) -> CpuFrequency:
    """
    Build CpuFrequency from raw sstat data.

    Args:
        raw_stats: Raw sstat dictionary for a step or aggregate.

    Returns:
        CpuFrequency: CPU frequency info (average kHz and requested bounds/governor).

    Examples:
        >>> raw = {'AveCPUFreq': '2400000', 'ReqCPUFreqMin': '1200000', 'ReqCPUFreqMax': '3000000'}
        >>> freq = build_cpu_frequency(raw)
        >>> freq['Average_Frequency_KHz']
        2400000.0
    """
    avg_khz = convert_to_float(raw_stats.get("AveCPUFreq", "0"))
    return CpuFrequency(
        Average_Frequency_KHz=avg_khz,
        Requested_Min_Frequency_KHz=raw_stats.get("ReqCPUFreqMin", "Unknown"),
        Requested_Max_Frequency_KHz=raw_stats.get("ReqCPUFreqMax", "Unknown"),
        Frequency_Governor=raw_stats.get("ReqCPUFreqGov", "Unknown"),
    )


def build_storage_stats(
    raw_stats: Dict[str, str], io_type: IoDirection
) -> StorageIOStats:
    """
    Build StorageIOStats for Read or Write operations.

    Args:
        raw_stats: Raw sstat dictionary for a step or aggregate.
        io_type: 'Read' or 'Write'.

    Returns:
        StorageIOStats: Storage I/O statistics in bytes.

    Examples:
        >>> raw = {'MaxDiskRead': '1024M', 'AveDiskRead': '512M', 'MaxDiskReadNode': 'node01'}
        >>> stats = build_storage_stats(raw, 'Read')
        >>> stats['Max_Bytes']
        1073741824
    """
    max_key = f"MaxDisk{io_type}"
    ave_key = f"AveDisk{io_type}"
    max_bytes = convert_to_int(raw_stats.get(max_key, "0"))
    ave_bytes = convert_to_int(raw_stats.get(ave_key, "0"))

    return StorageIOStats(
        Max_Bytes=max_bytes,
        Max_Node=raw_stats.get(f"{max_key}Node", ""),
        Max_Task=convert_to_int(raw_stats.get(f"{max_key}Task", "0")),
        Average_Bytes=ave_bytes,
    )


def build_io_efficiency(raw_stats: Dict[str, str]) -> IoEfficiency:
    """
    Compute storage I/O efficiency indicators.

    Args:
        raw_stats: Raw sstat dictionary for a step or aggregate.

    Returns:
        IoEfficiency: I/O efficiency metrics (ratios and consistency).

    Examples:
        >>> raw = {'MaxDiskRead': '2048M', 'MaxDiskWrite': '1024M', 'AveDiskRead': '1024M', 'AveDiskWrite': '512M'}
        >>> eff = build_io_efficiency(raw)
        >>> eff['Read_Write_Ratio']
        2.0
    """
    max_read = convert_to_int(raw_stats.get("MaxDiskRead", "0"))
    max_write = convert_to_int(raw_stats.get("MaxDiskWrite", "0"))
    ave_read = convert_to_int(raw_stats.get("AveDiskRead", "0"))
    ave_write = convert_to_int(raw_stats.get("AveDiskWrite", "0"))

    return IoEfficiency(
        Read_Write_Ratio=(max_read / max_write) if max_write > 0 else float("inf"),
        Io_Consistency_Read=(ave_read / max_read) if max_read > 0 else 0.0,
        Io_Consistency_Write=(ave_write / max_write) if max_write > 0 else 0.0,
        Total_Io_Bytes=max_read + max_write,
    )


def build_pagefaults_block(raw_stats: Dict[str, str]) -> PageFaultsBlock:
    """
    Build PageFaultsBlock from raw sstat data.

    NOTE: SLURM reports total page fault counts (not per second rates).

    Args:
        raw_stats: Raw sstat dictionary for a step or aggregate.

    Returns:
        PageFaultsBlock: Page fault metrics with max/average counts.

    Examples:
        >>> raw = {'MaxPages': '10000', 'AvePages': '5000', 'MaxPagesNode': 'node01', 'MaxPagesTask': '0'}
        >>> pf = build_pagefaults_block(raw)
        >>> pf['Max_Count']
        10000
    """
    max_pages_str = raw_stats.get("MaxPages", "0")
    max_pages = int(max_pages_str) if max_pages_str.isdigit() else 0

    ave_pages_str = raw_stats.get("AvePages", "0")
    ave_pages = int(ave_pages_str) if ave_pages_str.isdigit() else 0

    max_task_str = raw_stats.get("MaxPagesTask", "0")
    max_task = int(max_task_str) if max_task_str.isdigit() else 0

    return PageFaultsBlock(
        Max_Count=max_pages,
        Max_Pages_Node=raw_stats.get("MaxPagesNode", ""),
        Max_Pages_Task=max_task,
        Average_Count=ave_pages,
        Total_Across_Steps_Count=0,  # Will be calculated in aggregation
    )


def build_energy_block(raw_stats: Dict[str, str]) -> EnergyBlock:
    """
    Build EnergyBlock from raw sstat data.

    SLURM reports energy in joules, with optional 'K' suffix for thousands.
    NOTE: 'K' here means 1000 (SI prefix), not 1024 (binary).

    Args:
        raw_stats: Raw sstat dictionary for a step or aggregate.

    Returns:
        EnergyBlock: Energy consumption in joules.

    Examples:
        >>> raw = {'ConsumedEnergy': '500K'}
        >>> energy = build_energy_block(raw)
        >>> energy['Total_Energy_Joules']
        500000.0
    """
    energy_str = raw_stats.get("ConsumedEnergy", "0").strip().upper()

    # Handle 'K' suffix (thousands of joules, base 1000 for energy)
    if energy_str.endswith("K"):
        try:
            return EnergyBlock(Total_Energy_Joules=float(energy_str[:-1]) * 1000.0)
        except ValueError:
            return EnergyBlock(Total_Energy_Joules=0.0)

    # Plain number
    try:
        return EnergyBlock(Total_Energy_Joules=float(energy_str))
    except ValueError:
        return EnergyBlock(Total_Energy_Joules=0.0)


def build_step_stats(
    job_id: str, step_id: str, raw_data: Dict[str, str]
) -> ProcessedStepStats:
    """
    Build complete ProcessedStepStats structure from raw sstat data.

    Orchestrates all builder functions to construct a comprehensive
    typed dictionary with all metrics in canonical units (bytes, seconds, etc.).

    This is the high-level builder that combines all individual builders
    into the final step statistics structure.

    Args:
        job_id: Base job id (no .step suffix).
        step_id: Step identifier (e.g., '12345.0', '12345.batch').
        raw_data: Raw sstat output as dict with string values.

    Returns:
        ProcessedStepStats: Typed dictionary with all normalized metrics.

    Examples:
        >>> raw = {'MaxRSS': '4096M', 'AveCPU': '01:00:00', ...}
        >>> step = build_step_stats('12345', '12345.0', raw)
        >>> step['Memory_Related']['Physical_Memory']['Max_Bytes']
        4294967296
    """
    return ProcessedStepStats(
        Job_Id=job_id,
        Step_Id=step_id,
        Memory_Related=StepMemoryRelated(
            Virtual_Memory=build_memory_block(raw_data, "VM"),
            Physical_Memory=build_memory_block(raw_data, "RSS"),
            Memory_Efficiency=build_memory_efficiency(raw_data),
        ),
        CPU_Related=StepCpuRelated(
            CPU_Time_Stats=build_cpu_stats(raw_data),
            CPU_Frequency=build_cpu_frequency(raw_data),
        ),
        Page_Faults=build_pagefaults_block(raw_data),
        Energy_Consumption=build_energy_block(raw_data),
        Disk_IO=StepDiskIO(
            Read_Stats=build_storage_stats(raw_data, "Read"),
            Write_Stats=build_storage_stats(raw_data, "Write"),
            IO_Efficiency=build_io_efficiency(raw_data),
        ),
        TRES_Usage=StepTresUsage(
            Input_Resources=build_tres_usage_section(raw_data, "In"),
            Output_Resources=build_tres_usage_section(raw_data, "Out"),
        ),
    )
