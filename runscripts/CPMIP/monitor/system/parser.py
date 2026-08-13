"""System information parsers for lscpu, free, and uptime output.

This module provides parsing functions for system command outputs used
in node statistics collection.
"""

from typing import Any, Dict, Optional

from ..constants import FREE_MEM_COLUMNS, FREE_MEM_MIN_COLUMNS
from ..utils.converters import convert_to_float, convert_to_int


def parse_lscpu_output(cpu_section: str) -> Dict[str, Any]:
    """
    Parse lscpu output to extract CPU topology information.

    Args:
        cpu_section: Raw lscpu output text.

    Returns:
        Dictionary with CPU topology info (threads_per_core, cores_per_socket, etc.).
    """
    cpu_info: Dict[str, Any] = {}

    if not cpu_section or "CPU_ERROR" in cpu_section:
        return cpu_info

    for line in cpu_section.splitlines():
        if "Thread(s) per core:" in line:
            cpu_info["Threads_Per_Core_Count"] = convert_to_int(
                line.split(":")[1].strip(), 0
            )
        elif "Core(s) per socket:" in line:
            cpu_info["Cores_Per_Socket_Count"] = convert_to_int(
                line.split(":")[1].strip(), 0
            )
        elif "Socket(s):" in line:
            cpu_info["Sockets_Count"] = convert_to_int(line.split(":")[1].strip(), 0)
        elif "Model name:" in line:
            cpu_info["Model"] = line.split(":")[1].strip()

    # Calculate total physical cores
    tpc = cpu_info.get("Threads_Per_Core_Count", 0)
    cps = cpu_info.get("Cores_Per_Socket_Count", 0)
    sockets = cpu_info.get("Sockets_Count", 0)

    total_physical = cps * sockets if (cps and sockets) else 0

    # Fallback: calculate from logical CPUs if physical calculation failed
    if total_physical == 0:
        logical = 0
        for line in cpu_section.splitlines():
            if "CPU(s):" in line and "On-line" not in line:
                logical = convert_to_int(line.split(":")[1].strip(), 0)
                break
        if logical and tpc:
            try:
                total_physical = int(logical / max(tpc, 1))
            except Exception:
                total_physical = 0

    cpu_info["Total_Physical_Cores_Count"] = total_physical

    return cpu_info


def parse_free_output(mem_section: str) -> Optional[Dict[str, Any]]:
    """
    Parse 'free -k' output to extract memory information.

    Args:
        mem_section: Raw 'free -k' output text.

    Returns:
        Dictionary with memory info (Total_Bytes, Used_Bytes, etc.) or None if parsing fails.
    """
    if not mem_section or "MEM_ERROR" in mem_section:
        return None

    lines = [ln for ln in mem_section.splitlines() if ln]
    mem_line = None

    # Find the "Mem:" line
    for ln in lines:
        if ln.lower().startswith("mem:"):
            mem_line = ln
            break

    if not mem_line:
        return None

    parts = mem_line.split()
    if len(parts) < FREE_MEM_MIN_COLUMNS:
        return None

    total_kb = convert_to_int(parts[FREE_MEM_COLUMNS["total"]], 0)
    used_kb = convert_to_int(parts[FREE_MEM_COLUMNS["used"]], 0)
    free_kb = convert_to_int(parts[FREE_MEM_COLUMNS["free"]], 0)
    available_kb = convert_to_int(parts[FREE_MEM_COLUMNS["available"]], 0)

    return {
        "Total_Bytes": total_kb * 1024,
        "Used_Bytes": used_kb * 1024,
        "Free_Bytes": free_kb * 1024,
        "Available_Bytes": available_kb * 1024,
        "Used_Percent": round((used_kb / total_kb * 100), 2) if total_kb > 0 else 0.0,
    }


def parse_uptime_output(load_section: str) -> Optional[Dict[str, Any]]:
    """
    Parse uptime output to extract load average information.

    Args:
        load_section: Raw uptime output text.

    Returns:
        Dictionary with load average (Min_1, Min_5, Min_15) or None if parsing fails.
    """
    if not load_section or "LOAD_ERROR" in load_section:
        return None

    if "load average:" not in load_section:
        return None

    load_part = load_section.split("load average:")[1].strip()
    loads = [convert_to_float(x.strip(), 0.0) for x in load_part.split(",")]

    if len(loads) >= 3:
        return {
            "Min_1": loads[0],
            "Min_5": loads[1],
            "Min_15": loads[2],
        }

    return None


def get_total_node_memory_kb(mem_section: str) -> int:
    """
    Extract total node memory in KB from 'free -k' output.

    Quick utility to get just the total memory value without full parsing.

    Args:
        mem_section: Raw 'free -k' output text.

    Returns:
        Total node memory in KB, or 0 if parsing fails.
    """
    if not mem_section or "MEM_ERROR" in mem_section:
        return 0

    lines = [ln for ln in mem_section.splitlines() if ln]
    mem_line = None

    for ln in lines:
        if ln.lower().startswith("mem:"):
            mem_line = ln
            break

    if not mem_line:
        return 0

    parts = mem_line.split()
    if len(parts) >= FREE_MEM_MIN_COLUMNS:
        return convert_to_int(parts[FREE_MEM_COLUMNS["total"]], 0)

    return 0
