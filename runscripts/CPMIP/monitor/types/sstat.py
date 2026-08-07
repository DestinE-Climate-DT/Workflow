"""Type definitions for sstat step statistics."""

from typing import List, TypedDict

from .tres import TresUsageSection


class _MemoryBlockRequired(TypedDict):
    """Required fields for MemoryBlock."""

    Max_Bytes: int
    Average_Bytes: int
    Max_Node: str
    Max_Task: int
    Peak_To_Average_Ratio: float


class MemoryBlock(_MemoryBlockRequired, total=False):
    """
    Memory metrics normalized to bytes.
    Args:
        None
    Returns:
        Max_Bytes: Peak memory in bytes.
        Average_Bytes: Average memory in bytes.
        Max_Node: Node name where the peak occurred.
        Max_Task: Task id where the peak occurred.
        Peak_To_Average_Ratio: Max_Bytes / Average_Bytes.
        Total_Across_Steps_Bytes: Optional sum of averages across steps.
    """

    Total_Across_Steps_Bytes: int


class MemoryEfficiency(TypedDict):
    """
    Ratios derived from RSS vs VM.
    Args:
        None
    Returns:
        Physical_To_Virtual_Ratio: MaxRSS / MaxVM.
        Average_Memory_Utilization: AveRSS / AveVM.
        Memory_Waste_Percentage: (1 - MaxRSS/MaxVM) * 100.
        Memory_Consistency: AveRSS / MaxRSS.
    """

    Physical_To_Virtual_Ratio: float
    Average_Memory_Utilization: float
    Memory_Waste_Percentage: float
    Memory_Consistency: float


class CpuTimeStats(TypedDict):
    """
    CPU time statistics (seconds).
    Args:
        None
    Returns:
        Total_Tasks_Count: Total tasks.
        Min_Cpu_Time_Seconds: Minimum CPU time in seconds.
        Min_Cpu_Node: Node for min CPU time.
        Min_Cpu_Task: Task id for min CPU time.
        Average_Cpu_Time_Seconds: Average CPU time in seconds.
        Cpu_Time_Variation: (Average - Min)/Average (if >0 else 0).
        Total_Cpu_Time_Seconds: Average * Total_Tasks_Count.
    """

    Total_Tasks_Count: int
    Min_Cpu_Time_Seconds: float
    Min_Cpu_Node: str
    Min_Cpu_Task: int
    Average_Cpu_Time_Seconds: float
    Cpu_Time_Variation: float
    Total_Cpu_Time_Seconds: float


class CpuFrequency(TypedDict):
    """
    CPU frequency info (all values in kHz as reported by SLURM).
    Args:
        None
    Returns:
        Average_Frequency_KHz: Average CPU frequency in kHz.
        Requested_Min_Frequency_KHz: Requested min frequency (raw string or 'Unknown').
        Requested_Max_Frequency_KHz: Requested max frequency (raw string or 'Unknown').
        Frequency_Governor: Requested governor (raw string or 'Unknown').
    """

    Average_Frequency_KHz: float
    Requested_Min_Frequency_KHz: str
    Requested_Max_Frequency_KHz: str
    Frequency_Governor: str


class _StorageIOStatsRequired(TypedDict):
    """Required fields for StorageIOStats."""

    Max_Bytes: int
    Max_Node: str
    Max_Task: int
    Average_Bytes: int


class StorageIOStats(_StorageIOStatsRequired, total=False):
    """
    Storage I/O stats (bytes).
    Args:
        None
    Returns:
        Max_Bytes: Max bytes.
        Max_Node: Node for max.
        Max_Task: Task for max.
        Average_Bytes: Average bytes.
        Total_Across_Steps_Bytes: Optional sum of averages across steps.
    """

    Total_Across_Steps_Bytes: int


class IoEfficiency(TypedDict):
    """
    Storage I/O efficiency indicators.
    Args:
        None
    Returns:
        Read_Write_Ratio: MaxDiskRead / MaxDiskWrite (inf if write==0).
        Io_Consistency_Read: AveDiskRead / MaxDiskRead.
        Io_Consistency_Write: AveDiskWrite / MaxDiskWrite.
        Total_Io_Bytes: MaxDiskRead + MaxDiskWrite.
    """

    Read_Write_Ratio: float
    Io_Consistency_Read: float
    Io_Consistency_Write: float
    Total_Io_Bytes: int


class PageFaultsBlock(TypedDict):
    """
    Page faults statistics (total counts, NOT per second).
    According to SLURM documentation:
    - MaxPages: Maximum number of page faults of all tasks in job
    - AvePages: Average number of page faults of all tasks in job

    Args:
        None
    Returns:
        Max_Count: Max page faults across all tasks.
        Max_Pages_Node: Node at max.
        Max_Pages_Task: Task at max.
        Average_Count: Average page faults across all tasks.
        Total_Across_Steps_Count: Sum of averages across steps.
    """

    Max_Count: int
    Max_Pages_Node: str
    Max_Pages_Task: int
    Average_Count: int
    Total_Across_Steps_Count: int


class EnergyBlock(TypedDict):
    """
    Energy consumption in joules.
    Args:
        None
    Returns:
        Total_Energy_Joules: Total energy in joules.
    """

    Total_Energy_Joules: float


class StepMemoryRelated(TypedDict):
    """
    Memory-related metrics for a single job step.
    Args:
        None
    Returns:
        Virtual_Memory: VM memory block with max/average bytes and metadata.
        Physical_Memory: RSS memory block with max/average bytes and metadata.
        Memory_Efficiency: Efficiency ratios (physical/virtual, waste, consistency).
    """

    Virtual_Memory: MemoryBlock
    Physical_Memory: MemoryBlock
    Memory_Efficiency: MemoryEfficiency


class StepCpuRelated(TypedDict):
    """
    CPU-related metrics for a single job step.
    Args:
        None
    Returns:
        CPU_Time_Stats: CPU time statistics (min/avg/total in seconds).
        CPU_Frequency: CPU frequency info (average kHz, requested bounds, governor).
    """

    CPU_Time_Stats: CpuTimeStats
    CPU_Frequency: CpuFrequency


class StepDiskIO(TypedDict):
    """
    Disk I/O metrics for a single job step.
    Args:
        None
    Returns:
        Read_Stats: Read I/O statistics (max/average bytes, node, task).
        Write_Stats: Write I/O statistics (max/average bytes, node, task).
        IO_Efficiency: I/O efficiency indicators (read/write ratio, consistency).
    """

    Read_Stats: StorageIOStats
    Write_Stats: StorageIOStats
    IO_Efficiency: IoEfficiency


class StepTresUsage(TypedDict):
    """
    TRES usage metrics for a single job step.
    Args:
        None
    Returns:
        Input_Resources: TRES usage section for input resources (avg/max/min/total).
        Output_Resources: TRES usage section for output resources (avg/max/min/total).
    """

    Input_Resources: TresUsageSection
    Output_Resources: TresUsageSection


class ProcessedStepStats(TypedDict):
    """
    Processed sstat data for a single job step with normalized metrics.
    All metrics are in canonical units with typed structured sections.

    Args:
        None
    Returns:
        Job_Id: Base job id.
        Step_Id: Step identifier (e.g., '12345.0', '12345.batch').
        Memory_Related: Memory blocks (VM/RSS) and efficiency metrics.
        CPU_Related: CPU time stats and frequency info.
        Page_Faults: Page fault metrics.
        Energy_Consumption: Energy metrics in joules.
        Disk_IO: Storage I/O stats (read/write) and efficiency.
        TRES_Usage: TRES usage (input/output resources).
    """

    Job_Id: str
    Step_Id: str
    Memory_Related: StepMemoryRelated
    CPU_Related: StepCpuRelated
    Page_Faults: PageFaultsBlock
    Energy_Consumption: EnergyBlock
    Disk_IO: StepDiskIO
    TRES_Usage: StepTresUsage


class AggregatedMemoryRelated(TypedDict):
    """
    Aggregated memory metrics across all job steps.
    Args:
        None
    Returns:
        Virtual_Memory: VM memory block with Total_Across_Steps_Bytes included.
        Physical_Memory: RSS memory block with Total_Across_Steps_Bytes included.
        Memory_Efficiency: Efficiency ratios computed from aggregated data.
    """

    Virtual_Memory: MemoryBlock
    Physical_Memory: MemoryBlock
    Memory_Efficiency: MemoryEfficiency


class AggregatedCpuRelated(TypedDict):
    """
    Aggregated CPU metrics across all job steps.
    Args:
        None
    Returns:
        Cpu_Time_Stats: CPU time statistics aggregated across steps.
        Cpu_Frequency: Average CPU frequency info.
        Estimated_Total_Core_Seconds: Total core-seconds consumed by the job.
    """

    Cpu_Time_Stats: CpuTimeStats
    Cpu_Frequency: CpuFrequency
    Estimated_Total_Core_Seconds: float


class AggregatedStorageIO(TypedDict):
    """
    Aggregated storage I/O metrics across all job steps.
    Args:
        None
    Returns:
        Read_Stats: Read I/O statistics with Total_Across_Steps_Bytes.
        Write_Stats: Write I/O statistics with Total_Across_Steps_Bytes.
        Io_Efficiency: I/O efficiency indicators.
    """

    Read_Stats: StorageIOStats
    Write_Stats: StorageIOStats
    Io_Efficiency: IoEfficiency


class AggregatedTresUsage(TypedDict):
    """
    Aggregated TRES usage metrics across all job steps.
    Args:
        None
    Returns:
        Input_Resources: TRES usage section for input resources (avg/max/min/total).
        Output_Resources: TRES usage section for output resources (avg/max/min/total).
    """

    Input_Resources: TresUsageSection
    Output_Resources: TresUsageSection


class _AggregatedStatsRequired(TypedDict):
    """Required fields for AggregatedStats."""

    Job_Id: str
    Job_Name: str
    Memory_Related: AggregatedMemoryRelated
    Cpu_Related: AggregatedCpuRelated
    Page_Faults: PageFaultsBlock
    Energy_Consumption: EnergyBlock
    Storage_IO: AggregatedStorageIO
    Tres_Usage: AggregatedTresUsage


class AggregatedStats(_AggregatedStatsRequired, total=False):
    """
    Aggregated job statistics across all steps in canonical units.
    All metrics represent aggregated data from multiple job steps with typed structured sections.

    Args:
        None
    Returns:
        Job_Id: Base job id.
        Job_Name: Job name.
        Memory_Related: Aggregated memory blocks (VM/RSS) and efficiency metrics.
        Cpu_Related: Aggregated CPU time stats, frequency info, and total core-seconds.
        Page_Faults: Aggregated page fault metrics.
        Energy_Consumption: Total energy consumption in joules.
        Storage_IO: Aggregated storage I/O stats (read/write) and efficiency.
        Tres_Usage: Aggregated TRES usage (input/output resources).
        Validation_Warnings: Optional list of data consistency warnings.
    """

    Validation_Warnings: List[str]
