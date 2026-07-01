"""Type definitions for pidstat process monitoring."""

from typing import List, Literal, TypedDict


class ProcessCpu(TypedDict):
    """
    CPU-related metrics for a process (from pidstat -u).

    IMPORTANT: All CPU metrics are normalized to PHYSICAL cores (NOT percentages):
    - Cpu_Physical_Cores represents number of physical cores used
    - 1.0 = 1 physical core fully utilized
    - 2.5 = 2.5 physical cores fully utilized

    Conversion from pidstat's logical core percentages:
    - pidstat reports: 400% (4 logical cores on TPC=2 system)
    - We normalize: (400 / 100) / 2 = 2.0 physical cores

    Multi-threading and CPU_Processor_ID:
    - A process with multiple threads can use many processors simultaneously
    - CPU_Processor_ID shows ONE processor (snapshot), but Cpu_Physical_Cores
      aggregates usage across ALL threads on ALL processors
    - Example: Process with 4 threads on different processors → CPU_Processor_ID=3
      (one thread location), but Cpu_Physical_Cores=2.5 (total across all threads)

    Args:
        None
    Returns:
        Cpu_Physical_Cores: Total PHYSICAL cores used (usr+system+guest+wait).
        Cpu_User_Physical_Cores: User-space PHYSICAL cores used (excludes guest time).
        Cpu_System_Physical_Cores: Kernel-space PHYSICAL cores used.
        Cpu_Guest_Physical_Cores: Virtual CPU PHYSICAL cores for guest OS (included in user).
        Cpu_Wait_Physical_Cores: PHYSICAL cores waiting for I/O completion.
        CPU_Processor_ID: Processor number where the task was last seen (snapshot).
    """

    Cpu_Physical_Cores: float
    Cpu_User_Physical_Cores: float
    Cpu_System_Physical_Cores: float
    Cpu_Guest_Physical_Cores: float
    Cpu_Wait_Physical_Cores: float
    CPU_Processor_ID: str


class ProcessMemory(TypedDict):
    """
    Memory-related metrics for a process (from pidstat -r).
    Args:
        None
    Returns:
        Rss_Bytes: Resident Set Size - physical memory in bytes (non-swapped).
        Vss_Bytes: Virtual Memory Size - total virtual memory in bytes (VSZ).
        Memory_Percent_Of_Node: Percentage of NODE's total physical memory used by process.
        Memory_Percent_Of_Job_Limit: Percentage of JOB's memory allocation used by process.
    """

    Rss_Bytes: int
    Vss_Bytes: int
    Memory_Percent_Of_Node: float
    Memory_Percent_Of_Job_Limit: float


class ProcessPaging(TypedDict):
    """
    Paging metrics for a process (from pidstat -r).
    Args:
        None
    Returns:
        Page_Faults_Minor_Per_Second: Minor page faults/s (no disk I/O, reclaiming page).
        Page_Faults_Major_Per_Second: Major page faults/s (loading from disk).
    """

    Page_Faults_Minor_Per_Second: float
    Page_Faults_Major_Per_Second: float


class ProcessCtxSwitch(TypedDict):
    """
    Context switches for a process (from pidstat -w).
    Args:
        None
    Returns:
        Voluntary_Per_Second: Voluntary context switches/s (task blocks waiting for resource).
        Involuntary_Per_Second: Involuntary context switches/s (preempted by scheduler).
    """

    Voluntary_Per_Second: float
    Involuntary_Per_Second: float


class ProcessEntry(TypedDict):
    """
    Process entry with subsections.
    Args:
        None
    Returns:
        Pid: Process id.
        Uid: User id.
        Command: Command line.
        Cpu_Related: CPU metrics.
        Memory_Related: Memory metrics.
        Paging_Related: Paging metrics.
        Context_Switches: Context switches metrics.
    """

    Pid: str
    Uid: str
    Command: str
    Cpu_Related: ProcessCpu
    Memory_Related: ProcessMemory
    Paging_Related: ProcessPaging
    Context_Switches: ProcessCtxSwitch


class SummaryCpu(TypedDict):
    """
    Node summary CPU metrics (all in PHYSICAL cores).
    Args:
        None
    Returns:
        Total_Cpu_Physical_Cores: Sum of all process PHYSICAL core usage.
        Job_Cpu_Utilization_Percent: Job utilization vs node's PHYSICAL cores capacity.
    """

    Total_Cpu_Physical_Cores: float
    Job_Cpu_Utilization_Percent: float


class SummaryMem(TypedDict):
    """
    Node summary memory metrics.
    Args:
        None
    Returns:
        Total_Memory_Bytes: Sum of process RSS bytes.
        Job_Memory_Of_Node_Percent: Job memory usage vs node total capacity.
        Job_Memory_Of_Job_Limit_Percent: Job memory usage vs job's allocated memory limit.
    """

    Total_Memory_Bytes: int
    Job_Memory_Of_Node_Percent: float
    Job_Memory_Of_Job_Limit_Percent: float


class SummaryCtx(TypedDict):
    """
    Node summary context switches.
    Args:
        None
    Returns:
        Total_Voluntary_Per_Second: Sum of voluntary ctx switches per second.
        Total_Involuntary_Per_Second: Sum of involuntary ctx switches per second.
    """

    Total_Voluntary_Per_Second: float
    Total_Involuntary_Per_Second: float


class SummaryCounts(TypedDict):
    """
    Node summary counts.
    Args:
        None
    Returns:
        Process_Count: Number of user processes.
        Filtered_Kernel_Processes_Count: Kernel/infra processes skipped.
    """

    Process_Count: int
    Filtered_Kernel_Processes_Count: int


class NodeSummary(TypedDict):
    """
    Node summary broken into subsections.
    Args:
        None
    Returns:
        Cpu_Related: CPU summary metrics.
        Memory_Related: Memory summary metrics.
        Context_Switches: Context switch summary metrics.
        Counts: Count metrics.
    """

    Cpu_Related: SummaryCpu
    Memory_Related: SummaryMem
    Context_Switches: SummaryCtx
    Counts: SummaryCounts


class CpuInfoBlock(TypedDict, total=False):
    """
    CPU topology info for a node.
    Args:
        None
    Returns:
        Threads_Per_Core_Count: Threads per core (SMT/HT factor).
        Cores_Per_Socket_Count: Physical cores per socket.
        Sockets_Count: CPU sockets.
        Total_Physical_Cores_Count: Total PHYSICAL cores.
        Model: CPU model string.
    """

    Threads_Per_Core_Count: int
    Cores_Per_Socket_Count: int
    Sockets_Count: int
    Total_Physical_Cores_Count: int
    Model: str


class MemoryInfoBlock(TypedDict):
    """
    Node memory info.
    Args:
        None
    Returns:
        Total_Bytes: Node total memory.
        Used_Bytes: Node used memory.
        Free_Bytes: Free memory.
        Available_Bytes: Available memory.
        Used_Percent: Used percentage.
    """

    Total_Bytes: int
    Used_Bytes: int
    Free_Bytes: int
    Available_Bytes: int
    Used_Percent: float


class LoadAverageBlock(TypedDict):
    """
    Load average metrics from uptime command.
    Args:
        None
    Returns:
        Min_1: Load average for last 1 minute.
        Min_5: Load average for last 5 minutes.
        Min_15: Load average for last 15 minutes.
    """

    Min_1: float
    Min_5: float
    Min_15: float


class NodeGeneralInfo(TypedDict, total=False):
    """
    General node info and health.
    Args:
        None
    Returns:
        Status: 'success' or 'error'.
        Cpu_Info: CPU topology block.
        Memory_Info: Memory info block.
        Uptime_Raw: Raw uptime string.
        Load_Average: 1/5/15-min load averages.
        Error: Error message if any.
    """

    Status: Literal["success", "error"]
    Cpu_Info: CpuInfoBlock
    Memory_Info: MemoryInfoBlock
    Uptime_Raw: str
    Load_Average: LoadAverageBlock
    Error: str


class NodeStats(TypedDict):
    """
    Node statistics wrapper.
    Args:
        None
    Returns:
        Summary: Node summary block.
        Processes: List of process entries.
        Node_General_Info: Node general info.
    """

    Summary: NodeSummary
    Processes: List[ProcessEntry]
    Node_General_Info: NodeGeneralInfo
