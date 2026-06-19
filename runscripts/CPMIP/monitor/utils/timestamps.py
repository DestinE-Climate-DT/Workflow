"""Timestamp conversion utilities for SLURM timestamps."""

import re
from datetime import datetime
from typing import Tuple

# Regex patterns for time parsing
_TIME_RE = re.compile(
    r"^\s*(?:(\d+)-)?(?:(\d{1,2}):)?(\d{1,2}):(\d{1,2}(?:\.\d+)?)\s*$"
)
_MMSS_RE = re.compile(r"^\s*(\d{1,2}):(\d{1,2}(?:\.\d+)?)\s*$")


def convert_duration_to_seconds(time_str: str) -> float:
    """
    Convert a SLURM duration string into seconds.

    Supports formats:
    - DD-HH:MM:SS (days-hours:minutes:seconds)
    - HH:MM:SS (hours:minutes:seconds)
    - MM:SS (minutes:seconds)
    - Plain number (seconds)

    Args:
        time_str: Duration string from SLURM (e.g., '2-04:30:15', '04:30:15', '30:15').

    Returns:
        float: Total seconds, or 0.0 if parsing fails.

    Examples:
        >>> convert_duration_to_seconds('2-04:30:15')
        190215.0
        >>> convert_duration_to_seconds('04:30:15')
        16215.0
        >>> convert_duration_to_seconds('30:15')
        1815.0
        >>> convert_duration_to_seconds('N/A')
        0.0
    """
    if not time_str or time_str == "N/A":
        return 0.0

    s = str(time_str).strip()

    # Try DD-HH:MM:SS or HH:MM:SS format
    m = _TIME_RE.match(s)
    if m:
        days = int(m.group(1) or 0)
        hh = int(m.group(2) or 0)
        mm = int(m.group(3))
        ss = float(m.group(4))
        return float(days * 86400 + hh * 3600 + mm * 60 + ss)

    # Try MM:SS format
    m2 = _MMSS_RE.match(s)
    if m2:
        mm = int(m2.group(1))
        ss = float(m2.group(2))
        return float(mm * 60 + ss)

    # Try plain number (seconds)
    try:
        return float(s)
    except Exception:
        return 0.0


def convert_slurm_timestamp(timestamp_str: str) -> str:
    """
    Normalize SLURM timestamp to ISO-8601 format in local time.

    SLURM reports timestamps in the LOCAL timezone of the system WITHOUT
    any timezone indicator (e.g., '2025-10-30T15:30:59'). This function
    standardizes the format to ISO-8601 while keeping the local time.

    Args:
        timestamp_str: Timestamp string from SLURM (e.g., '2025-10-30T15:30:59').

    Returns:
        str: ISO-8601 timestamp in local time (e.g., '2025-10-30T15:30:59')
             or 'N/A' if parsing fails.

    Examples:
        >>> convert_slurm_timestamp('2025-10-30T15:30:59')
        '2025-10-30T15:30:59'
        >>> convert_slurm_timestamp('2025-10-30 15:30:59')
        '2025-10-30T15:30:59'
        >>> convert_slurm_timestamp('Unknown')
        'N/A'
    """
    if not timestamp_str or timestamp_str in ("N/A", "Unknown", "None"):
        return "N/A"

    try:
        from datetime import datetime

        # Format 1: Already has timezone information - strip it to keep local
        if "+" in timestamp_str or timestamp_str.endswith("Z"):
            dt = datetime.fromisoformat(timestamp_str.replace("Z", "+00:00"))
            # Return as local time without timezone
            return dt.strftime("%Y-%m-%dT%H:%M:%S")

        # Format 2: ISO-like without timezone (MOST COMMON FROM SLURM)
        # Keep as-is, just ensure proper format
        if "T" in timestamp_str:
            dt_naive = datetime.fromisoformat(timestamp_str)
            return dt_naive.strftime("%Y-%m-%dT%H:%M:%S")

        # Format 3: Space-separated (2025-10-30 15:30:59)
        if " " in timestamp_str:
            dt_naive = datetime.strptime(timestamp_str, "%Y-%m-%d %H:%M:%S")
            return dt_naive.strftime("%Y-%m-%dT%H:%M:%S")

        # Fallback: return as-is if already in good format
        return timestamp_str

    except Exception:
        # If parsing fails, return original
        return timestamp_str if timestamp_str else "N/A"


def now_timestamp() -> Tuple[int, str]:
    """
    Return current time in local timezone.

    Args:
        None

    Returns:
        Tuple of (epoch_seconds, iso_local_string).

    Examples:
        >>> epoch, iso = now_timestamp()
        >>> isinstance(epoch, int)
        True
        >>> 'T' in iso
        True
    """
    dt = datetime.now()
    return int(dt.timestamp()), dt.isoformat()
