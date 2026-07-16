"""TRES builder - construct typed TRES structures."""

from typing import Dict, Optional

from ...types.tres import TresAllocated, TresUsageSection
from .normalizer import normalize_tres_keys_and_units
from .parser import parse_tres_string


def build_tres_allocated(
    tres_str: str, threads_per_core: Optional[int] = None
) -> TresAllocated:
    """
    Build TresAllocated structure from raw TRES string.

    Parses and normalizes AllocTRES field from scontrol output.
    All CPU and Billing counts are converted to PHYSICAL cores when TPC>1.

    Args:
        tres_str: Raw AllocTRES string (e.g., 'cpu=64,mem=187G,node=2,billing=128').
        threads_per_core: Threads per core for converting to PHYSICAL cores.

    Returns:
        TresAllocated: Typed dictionary with normalized fields.

    Examples:
        >>> build_tres_allocated('cpu=128,mem=256G,node=4', threads_per_core=2)
        {'Cpu_Count': 64, 'Mem_Bytes': 274877906944, 'Node_Count': 4}
    """
    tres_dict = parse_tres_string(tres_str)
    normalized = normalize_tres_keys_and_units(tres_dict, threads_per_core)
    return normalized  # type: ignore


def build_tres_usage_section(
    raw_stats: Dict[str, str], direction: str
) -> TresUsageSection:
    """
    Build TresUsageSection from raw sstat data for a given direction (In/Out).

    Parses TRESUsage{In|Out}{Ave|Max|Min|Tot} fields and normalizes units.

    Args:
        raw_stats: Raw sstat dictionary for a step or aggregate.
        direction: 'In' or 'Out' to select input/output TRES fields.

    Returns:
        TresUsageSection: Dictionary with Average/Maximum/Minimum/Total subsections.

    Examples:
        >>> raw = {
        ...     'TRESUsageInAve': 'cpu=01:00:00,mem=10G',
        ...     'TRESUsageInMax': 'cpu=02:00:00,mem=20G',
        ...     'TRESUsageInMin': 'cpu=00:30:00,mem=5G',
        ...     'TRESUsageInTot': 'cpu=10:00:00,mem=100G'
        ... }
        >>> section = build_tres_usage_section(raw, 'In')
        >>> section['Average']['Cpu_Time_Seconds']
        3600.0
    """
    ave_key = f"TRESUsage{direction}Ave"
    max_key = f"TRESUsage{direction}Max"
    min_key = f"TRESUsage{direction}Min"
    tot_key = f"TRESUsage{direction}Tot"

    def _normalize_tres_map(tres_str: str) -> Dict:
        tres_dict = parse_tres_string(tres_str)
        return normalize_tres_keys_and_units(tres_dict)

    return TresUsageSection(
        Average=_normalize_tres_map(raw_stats.get(ave_key, "")),  # type: ignore
        Maximum=_normalize_tres_map(raw_stats.get(max_key, "")),  # type: ignore
        Minimum=_normalize_tres_map(raw_stats.get(min_key, "")),  # type: ignore
        Total=_normalize_tres_map(raw_stats.get(tot_key, "")),  # type: ignore
    )
