"""Builder for scontrol job metadata structures.

This module contains builder functions to construct typed SLURM job metadata
structures from raw parsed scontrol data.
"""

from typing import Dict, List

from ...types.slurm import (
    AllocNodeInfo,
    JobFilesInfo,
    JobMetadata,
    JobResourceInfo,
    JobTimingInfo,
    NodeListInfo,
)
from ...types.tres import TresAllocated
from ...utils.converters import convert_to_int, convert_to_physical_cores
from ...utils.timestamps import convert_duration_to_seconds, convert_slurm_timestamp


def build_timing_info(flat: Dict[str, str], notes: List[str]) -> JobTimingInfo:
    """
    Build JobTimingInfo from parsed scontrol output.

    Constructs timing information with proper timestamp conversions and
    handles different job states (RUNNING, COMPLETED, FAILED).

    Args:
        flat: Flat dictionary from scontrol parser.
        notes: List to append warning/info notes to.

    Returns:
        JobTimingInfo: Typed dictionary with timing information.

    Examples:
        >>> flat = {'SubmitTime': '2024-01-01T10:00:00', 'StartTime': '2024-01-01T10:05:00',
        ...         'EndTime': '2024-01-01T11:00:00', 'RunTime': '00:55:00', 'JobState': 'COMPLETED'}
        >>> notes = []
        >>> timing = build_timing_info(flat, notes)
        >>> timing['Run_Time_Seconds']
        3300
    """
    runtime_str = flat.get("RunTime", "0")
    runtime_seconds = int(convert_duration_to_seconds(runtime_str))

    job_state = flat.get("JobState", "UNKNOWN")

    # Normalize timestamps to ISO-8601 format (local time)
    submit_time_local = convert_slurm_timestamp(flat.get("SubmitTime", "N/A"))
    start_time_local = convert_slurm_timestamp(flat.get("StartTime", "N/A"))
    end_time_raw = convert_slurm_timestamp(flat.get("EndTime", "N/A"))

    # Separate Estimated vs Actual End_Time based on job state
    if job_state == "RUNNING":
        estimated_end = end_time_raw
        actual_end = "N/A"
        notes.append(
            f"Job state is {job_state}: End_Time represents walltime limit, not actual completion."
        )
    elif job_state in ("COMPLETED", "FAILED"):
        estimated_end = "N/A"
        actual_end = end_time_raw
        notes.append(
            f"Job state is {job_state}: Actual_End_Time_ISO contains real completion time."
        )
    else:
        estimated_end = end_time_raw
        actual_end = end_time_raw
        notes.append(f"Job state is {job_state}: End_Time classification uncertain.")

    return JobTimingInfo(
        Submit_Time_ISO=submit_time_local,
        Start_Time_ISO=start_time_local,
        Estimated_End_Time_ISO=estimated_end,
        Actual_End_Time_ISO=actual_end,
        Run_Time_Seconds=runtime_seconds,
        Elapsed_Time_Seconds=runtime_seconds,
    )


def build_resource_info(flat: Dict[str, str], threads_per_core: int) -> JobResourceInfo:
    """
    Build JobResourceInfo with PHYSICAL core counts.

    Converts logical CPU counts to physical cores using threads_per_core.

    Args:
        flat: Flat dictionary from scontrol parser.
        threads_per_core: TPC value for logical->physical conversion.

    Returns:
        JobResourceInfo: Typed dictionary with resource information.

    Examples:
        >>> flat = {'NumCPUs': '128', 'NumTasks': '64', 'CPUs/Task': '2', 'NumNodes': '4'}
        >>> info = build_resource_info(flat, threads_per_core=2)
        >>> info['Num_CPUs_Count']  # 128 logical / 2 TPC = 64 physical
        64
    """
    num_cpus_logical = convert_to_int(flat.get("NumCPUs", "0"))
    cpus_per_task_logical = convert_to_int(flat.get("CPUs/Task", "0"))

    return JobResourceInfo(
        Num_CPUs_Count=convert_to_physical_cores(num_cpus_logical, threads_per_core),
        Num_Tasks_Count=convert_to_int(flat.get("NumTasks", "0")),
        CPUs_Per_Task_Count=convert_to_physical_cores(
            cpus_per_task_logical, threads_per_core
        ),
        Num_Nodes_Count=convert_to_int(flat.get("NumNodes", "0")),
    )


def build_files_info(flat: Dict[str, str]) -> JobFilesInfo:
    """
    Build JobFilesInfo from parsed scontrol output.

    Extracts file paths and command information.

    Args:
        flat: Flat dictionary from scontrol parser.

    Returns:
        JobFilesInfo: Typed dictionary with file information.

    Examples:
        >>> flat = {'Command': '/path/to/script.sh', 'WorkDir': '/home/user',
        ...         'StdErr': '/path/to/err.log', 'StdOut': '/path/to/out.log',
        ...         'BatchHost': 'node01'}
        >>> info = build_files_info(flat)
        >>> info['Command']
        '/path/to/script.sh'
    """
    return JobFilesInfo(
        Command=flat.get("Command", "N/A"),
        Working_Directory=flat.get("WorkDir", "N/A"),
        Std_Error_Path=flat.get("StdErr", "N/A"),
        Std_Output_Path=flat.get("StdOut", "N/A"),
        Batch_Host=flat.get("BatchHost", "N/A"),
    )


def build_empty_metadata(job_id: str, error_msg: str) -> JobMetadata:
    """
    Build empty JobMetadata for error cases.

    Creates a minimal metadata structure with error information when
    scontrol command fails or data is unavailable.

    Args:
        job_id: Job identifier.
        error_msg: Error message to include in Notes.

    Returns:
        JobMetadata: Empty metadata structure with error note.

    Examples:
        >>> metadata = build_empty_metadata('12345', 'scontrol command failed')
        >>> metadata['Job_Id']
        '12345'
        >>> metadata['Notes']
        ['scontrol command failed']
    """
    return JobMetadata(
        Job_Id=job_id,
        Job_Name="N/A",
        Partition="N/A",
        Account="N/A",
        User_Id="N/A",
        Quality_Of_Service="N/A",
        State="N/A",
        Exit_Code="N/A",
        Allocated_Node_List=NodeListInfo(Nodes=[], Count=0),
        Alloc_Node=AllocNodeInfo(Node="", Session_Id=""),
        Timing_Info=JobTimingInfo(
            Submit_Time_ISO="N/A",
            Start_Time_ISO="N/A",
            Estimated_End_Time_ISO="N/A",
            Actual_End_Time_ISO="N/A",
            Run_Time_Seconds=0,
            Elapsed_Time_Seconds=0,
        ),
        Resource_Info=JobResourceInfo(
            Num_CPUs_Count=0,
            Num_Tasks_Count=0,
            CPUs_Per_Task_Count=0,
            Num_Nodes_Count=0,
        ),
        Tres_Allocated=TresAllocated(),
        Files_Info=JobFilesInfo(
            Command="N/A",
            Working_Directory="N/A",
            Std_Error_Path="N/A",
            Std_Output_Path="N/A",
            Batch_Host="N/A",
        ),
        Threads_Per_Core_Count=1,
        Notes=[error_msg],
    )
