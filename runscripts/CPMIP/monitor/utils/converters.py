"""Utility converters for parsing and transforming data."""

import re
from typing import Any

# Regex pattern for size parsing
_BYTES_RE = re.compile(r"^\s*(\d+(?:\.\d+)?)\s*([KMGT]?)\s*$", re.I)


def convert_to_int(value: Any, default: int = 0) -> int:
    """
    Safely convert to int with base-1024 suffixes (K/M/G/T).

    IMPORTANT: SLURM uses binary (base-1024) units for memory and storage:
      K = 1024 bytes (KiB), M = 1024² bytes (MiB), G = 1024³ bytes (GiB)

    Args:
        value: String/number to parse.
        default: Fallback integer.

    Returns:
        result: Parsed integer (K/M/G/T -> 1024^n).

    Examples:
        >>> convert_to_int("512M")
        536870912
        >>> convert_to_int("4G")
        4294967296
        >>> convert_to_int("Unknown")
        0
    """
    try:
        if value is None:
            return default
        s = str(value).strip()
        if s == "" or s in ("Unknown", "N/A"):
            return default
        suffix = s[-1].upper()
        if suffix in ("K", "M", "G", "T"):
            num = float(s[:-1])
            mult = 1024 ** {"K": 1, "M": 2, "G": 3, "T": 4}[suffix]
            return int(num * mult)
        return int(float(s))
    except (ValueError, TypeError):
        return default


def convert_to_float(value: Any, default: float = 0.0) -> float:
    """
    Safely convert to float with base-1024 suffixes (K/M/G/T).

    IMPORTANT: SLURM uses binary (base-1024) units for memory and storage.

    Args:
        value: String/number to parse.
        default: Fallback float.

    Returns:
        result: Parsed float (K/M/G/T -> 1024^n).

    Examples:
        >>> convert_to_float("1.5G")
        1610612736.0
        >>> convert_to_float("Unknown")
        0.0
    """
    try:
        if value is None:
            return default
        s = str(value).strip()
        if s == "" or s in ("Unknown", "N/A"):
            return default
        suffix = s[-1].upper()
        if suffix in ("K", "M", "G", "T"):
            num = float(s[:-1])
            mult = 1024 ** {"K": 1, "M": 2, "G": 3, "T": 4}[suffix]
            return float(num * mult)
        return float(s)
    except (ValueError, TypeError):
        return default


def convert_size_to_bytes(size_str: str) -> int:
    """
    Convert a size string into bytes (base 1024).

    IMPORTANT: Uses binary (base-1024) units as per SLURM convention.

    Args:
        size_str: e.g. '512M', '2G', '4096K' or plain integer string.

    Returns:
        bytes_value: Size in bytes as int.

    Examples:
        >>> convert_size_to_bytes("512M")
        536870912
        >>> convert_size_to_bytes("2G")
        2147483648
        >>> convert_size_to_bytes("1024")
        1024
    """
    if not size_str:
        return 0
    s = str(size_str).strip()
    m = _BYTES_RE.match(s)
    if not m:
        return convert_to_int(s, 0)
    val = float(m.group(1))
    unit = (m.group(2) or "").upper()
    mult = 1 if unit == "" else 1024 ** {"K": 1, "M": 2, "G": 3, "T": 4}[unit]
    return int(val * mult)


def convert_to_physical_cores(logical_count: int, threads_per_core: int) -> int:
    """
    Convert logical core count to PHYSICAL core count using threads-per-core.

    When SMT/Hyperthreading is enabled, SLURM reports logical cores.
    This function converts them to physical cores for accurate accounting.

    Args:
        logical_count: Number of logical cores (from SLURM).
        threads_per_core: Threads per core (TPC). Typically 1, 2, or 4.

    Returns:
        physical_count: Number of PHYSICAL cores (floor division, minimum 1).

    Examples:
        >>> convert_to_physical_cores(128, 2)
        64
        >>> convert_to_physical_cores(256, 4)
        64
        >>> convert_to_physical_cores(64, 1)
        64
    """
    try:
        tpc = int(threads_per_core) if threads_per_core else 1
    except Exception:
        tpc = 1
    if tpc and tpc > 1:
        return max(int(logical_count // tpc), 1)
    return max(int(logical_count), 1)
