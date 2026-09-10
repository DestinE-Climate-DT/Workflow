"""Type definitions for TRES (Trackable RESource) structures."""

from typing import Any, Dict, TypedDict


class TresNormalized(TypedDict, total=False):
    """
    Normalized TRES map with explicit units in names.
    Args:
        None
    Returns:
        Cpu_Time_Seconds: CPU time in seconds (if it was HH:MM:SS).
        Cpu_Count: CPU count (PHYSICAL cores).
        Mem_Bytes: Memory in bytes.
        Node_Count: Node count.
        Billing_Count: Billing units (PHYSICAL cores).
        Energy_Joules: Energy in joules.
        *_Bytes/_Seconds/_Count/_Value: Other inferred resources.
    """

    Cpu_Time_Seconds: float
    Cpu_Count: int
    Mem_Bytes: int
    Node_Count: int
    Billing_Count: int
    Energy_Joules: float


class TresRequested(TypedDict, total=False):
    """
    Requested TRES resources (from TRES field in scontrol).
    All CPU/Billing counts are PHYSICAL cores when TPC>1.

    Standard fields (all optional):
        Cpu_Count: Requested CPU count (PHYSICAL cores).
        Mem_Bytes: Requested memory in bytes.
        Node_Count: Requested node count.
        Billing_Count: Requested billing units (PHYSICAL cores).

    Dynamic fields (cluster/job-specific):
        Gres_Gpu_*: GPU resources (e.g., Gres_Gpu_Count, Gres_Gpu_Mem_Bytes).
        *_Count/*_Bytes/*_Value: Other GRES or custom resources.

    Note: total=False allows empty dict or partial fields.
    """

    Cpu_Count: int
    Mem_Bytes: int
    Node_Count: int
    Billing_Count: int


class TresAllocated(TypedDict, total=False):
    """
    Allocated TRES resources (from AllocTRES field in scontrol).
    All CPU/Billing counts are PHYSICAL cores when TPC>1.

    Standard fields (all optional):
        Cpu_Count: Allocated CPU count (PHYSICAL cores).
        Mem_Bytes: Allocated memory in bytes.
        Node_Count: Allocated node count.
        Billing_Count: Allocated billing units (PHYSICAL cores).
        Energy_Joules: Energy allocation/consumption in joules.

    Dynamic fields (cluster/job-specific):
        Gres_Gpu_*: GPU resources (e.g., Gres_Gpu_Count, Gres_Gpu_Mem_Bytes).
        *_Count/*_Bytes/*_Value: Other GRES or custom resources.

    Note: total=False allows empty dict or partial fields.
    """

    Cpu_Count: int
    Mem_Bytes: int
    Node_Count: int
    Billing_Count: int
    Energy_Joules: float


class TresUsageSection(TypedDict):
    """
    TRES usage section (direction-specific) with normalized keys.
    Args:
        None
    Returns:
        Average: Average resource usage.
        Maximum: Maximum resource usage.
        Minimum: Minimum resource usage.
        Total: Total resource usage.
    """

    Average: Dict[str, Any]
    Maximum: Dict[str, Any]
    Minimum: Dict[str, Any]
    Total: Dict[str, Any]


class TresUsageBlock(TypedDict):
    """
    TRES usage for input and output resources.
    Args:
        None
    Returns:
        Input_Resources: TRES usage (incoming).
        Output_Resources: TRES usage (outgoing).
    """

    Input_Resources: TresUsageSection
    Output_Resources: TresUsageSection
