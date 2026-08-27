"""Parser for pidstat output and process filtering.

This module handles raw parsing of pidstat command output and filtering of
kernel/infrastructure processes. Does not build typed structures - that's
the builder's responsibility.
"""

from typing import Any, Dict, List

from ..constants import KERNEL_PROCESS_PATTERNS


def filter_kernel_process(command: str) -> bool:
    """
    Determine if a process should be filtered out (is kernel/infra process).

    Uses heuristic patterns to identify kernel and infrastructure processes
    that should not be counted as user job processes.

    Args:
        command: Full command line string.

    Returns:
        bool: True if process should be filtered out (is kernel process).

    Examples:
        >>> filter_kernel_process('[kworker/0:1]')
        True
        >>> filter_kernel_process('python my_script.py')
        False
        >>> filter_kernel_process('migration/0')
        True
    """
    cmd = (command or "").lower()

    # Pattern 1: Bracketed kernel threads
    if cmd.startswith("[") and cmd.endswith("]"):
        return True

    # Pattern 2: Known kernel process patterns
    if any(pattern in cmd for pattern in KERNEL_PROCESS_PATTERNS):
        return True

    return False


def parse_pidstat_line(line: str) -> Dict[str, Any]:
    """
    Parse a single pidstat output line into raw metrics dictionary.

    Pure parsing - extracts fields as-is from pidstat output with minimal
    type conversion. No calculations, no normalizations. Just extraction.

    pidstat line format (with -h flag):
    Time  UID  PID  %usr  %system  %guest  %wait  %CPU  CPU  minflt/s  majflt/s  VSZ  RSS  %MEM  cswch/s  nvcswch/s  Command

    Args:
        line: Single line from pidstat output.

    Returns:
        Dictionary with raw parsed metrics (strings and floats as extracted).
        Returns empty dict if line is invalid.

    Examples:
        >>> line = "09:18:36  6132  3318117  10.66  5.74  0.00  0.00  16.39  70  132.79  0.00  39872  38284  0.01  213.11  0.00  pidstat"
        >>> data = parse_pidstat_line(line)
        >>> data['pid']
        '3318117'
        >>> data['cpu_pct']  # Raw percentage from pidstat
        16.39
    """
    from ..constants import PIDSTAT_MIN_COLUMNS
    from ..utils.converters import convert_to_float, convert_to_int

    # Skip header and summary lines
    if line.startswith("#") or line.startswith("Linux") or line.startswith("Average"):
        return {}

    parts = line.split()
    if len(parts) < PIDSTAT_MIN_COLUMNS:
        return {}

    # Parse time, UID, PID (columns 0-2)
    time_str, uid, pid = parts[0], parts[1], parts[2]
    if not pid.isdigit():
        return {}

    try:
        # CPU metrics (columns 3-8) - keep as raw percentages
        usr_pct = convert_to_float(parts[3], 0.0)
        sys_pct = convert_to_float(parts[4], 0.0)
        guest_pct = convert_to_float(parts[5], 0.0)
        wait_pct = convert_to_float(parts[6], 0.0)
        cpu_pct = convert_to_float(parts[7], 0.0)
        cpu_core = parts[8]  # Processor ID where task last executed

        # Paging metrics (columns 9-10)
        minflt_s = convert_to_float(parts[9], 0.0)
        majflt_s = convert_to_float(parts[10], 0.0)

        # Memory metrics (columns 11-13) - keep in KB as reported
        vss_kb = convert_to_int(parts[11], 0)
        rss_kb = convert_to_int(parts[12], 0)
        mem_pct = convert_to_float(parts[13], 0.0)  # %MEM from pidstat

        # Context switches (columns 14-15)
        cswch_s = convert_to_float(parts[14], 0.0)
        nvcswch_s = convert_to_float(parts[15], 0.0)

        # Command (column 16+)
        command = " ".join(parts[16:]) if len(parts) > 16 else "unknown"

        # Return raw dictionary with minimal processing
        return {
            "time": time_str,
            "pid": pid,
            "uid": uid,
            "command": command,
            # CPU - raw percentages (logical cores)
            "cpu_user_pct": usr_pct,
            "cpu_system_pct": sys_pct,
            "cpu_guest_pct": guest_pct,
            "cpu_wait_pct": wait_pct,
            "cpu_total_pct": cpu_pct,
            "cpu_processor_id": cpu_core,
            # Memory - raw KB and percentage
            "vss_kb": vss_kb,
            "rss_kb": rss_kb,
            "mem_pct": mem_pct,
            # Paging - raw values
            "minflt_per_sec": minflt_s,
            "majflt_per_sec": majflt_s,
            # Context switches - raw values
            "cswch_per_sec": cswch_s,
            "nvcswch_per_sec": nvcswch_s,
        }
    except Exception:
        # Skip malformed lines
        return {}


def parse_pidstat_output(pidstat_output: str) -> List[Dict[str, Any]]:
    """
    Parse pidstat command output into list of raw process data dictionaries.

    Pure parsing - extracts all lines from pidstat output without any calculations
    or normalizations. Returns raw metrics as extracted from pidstat.

    pidstat output format (with -h flag):
    Time  UID  PID  %usr  %system  %guest  %wait  %CPU  CPU  minflt/s  majflt/s  VSZ  RSS  %MEM  cswch/s  nvcswch/s  Command

    Args:
        pidstat_output: Raw pidstat command output (multi-line string).

    Returns:
        List of raw dictionaries with parsed metrics (one per process).

    Examples:
        >>> output = "09:18:36  6132  3318117  10.66  5.74  0.00  0.00  16.39  70  132.79  0.00  39872  38284  0.01  213.11  0.00  pidstat"
        >>> processes = parse_pidstat_output(output)
        >>> len(processes)
        1
        >>> processes[0]['pid']
        '3318117'
    """
    processes = []
    lines = [ln.strip() for ln in pidstat_output.splitlines() if ln.strip()]

    for ln in lines:
        process_data = parse_pidstat_line(ln)
        if process_data:  # Only add if parsing succeeded
            processes.append(process_data)

    return processes
