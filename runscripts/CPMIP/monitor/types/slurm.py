"""Type definitions for SLURM job metadata (scontrol)."""

from typing import List, TypedDict

from .tres import TresAllocated


class AllocNodeInfo(TypedDict):
    """
    Parse 'AllocNode' field into a structured map.
    Args:
        None
    Returns:
        Node: Submission node name.
        Session_Id: Session id if present, empty string otherwise.
    """

    Node: str
    Session_Id: str


class NodeListInfo(TypedDict):
    """
    Expand a SLURM nodelist string into concrete node names.
    Args:
        None
    Returns:
        Nodes: List of expanded node names.
        Count: Number of nodes in the list.
    """

    Nodes: List[str]
    Count: int


class JobTimingInfo(TypedDict):
    """
    Job timing information with ISO-8601 local time timestamps and duration in seconds.
    All time values are ISO strings (in local time) or seconds (numeric).

    Note on End_Time fields:
    - For RUNNING jobs: Estimated_End_Time_ISO contains walltime limit, Actual_End_Time_ISO is "N/A"
    - For COMPLETED/FAILED jobs: Actual_End_Time_ISO contains real end time, Estimated_End_Time_ISO is "N/A"
    """

    Submit_Time_ISO: str
    Start_Time_ISO: str
    Estimated_End_Time_ISO: str
    Actual_End_Time_ISO: str
    Run_Time_Seconds: int
    Elapsed_Time_Seconds: int


class JobFilesInfo(TypedDict):
    """Job execution files and paths."""

    Command: str
    Working_Directory: str
    Std_Error_Path: str
    Std_Output_Path: str
    Batch_Host: str


class JobResourceInfo(TypedDict):
    """
    Job CPU and task allocation (all CPU counts are PHYSICAL cores when TPC>1).
    Args:
        None
    Returns:
        Num_CPUs_Count: Total PHYSICAL CPU cores allocated (NumCPUs / TPC).
        Num_Tasks_Count: Number of tasks.
        CPUs_Per_Task_Count: PHYSICAL cores per task (CPUs/Task / TPC).
        Num_Nodes_Count: Number of nodes.
    """

    Num_CPUs_Count: int
    Num_Tasks_Count: int
    CPUs_Per_Task_Count: int
    Num_Nodes_Count: int


class _JobMetadataRequired(TypedDict):
    """Required fields for JobMetadata."""

    Job_Id: str
    Job_Name: str
    Partition: str
    Account: str
    User_Id: str
    Quality_Of_Service: str
    State: str
    Exit_Code: str
    Allocated_Node_List: NodeListInfo
    Alloc_Node: AllocNodeInfo
    Timing_Info: JobTimingInfo
    Resource_Info: JobResourceInfo
    Tres_Allocated: TresAllocated
    Files_Info: JobFilesInfo
    Threads_Per_Core_Count: int


class JobMetadata(_JobMetadataRequired, total=False):
    """
    Comprehensive normalized job metadata from scontrol.
    Args:
        None
    Returns:
        Job_Id: Base job id.
        Job_Name: Job name.
        Partition: Partition name.
        Account: Account string.
        User_Id: User id.
        Quality_Of_Service: QOS string.
        State: SLURM job state.
        Exit_Code: Exit code if completed.
        Allocated_Node_List: Expanded node list {Nodes, Count}.
        Alloc_Node: Alloc node info {Node, Session_Id}.
        Timing_Info: Timing details (submit, start, end, runtime).
        Resource_Info: CPU/task allocation details.
        Tres_Allocated: Typed TRES allocated (PHYSICAL Cpu_Count/Billing_Count).
        Files_Info: Job execution files and paths.
        Threads_Per_Core_Count: Detected threads per core.
        Notes: Optional list of warnings/info messages.
    """

    Notes: List[str]
