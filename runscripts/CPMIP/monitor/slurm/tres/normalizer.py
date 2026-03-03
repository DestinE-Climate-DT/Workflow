"""TRES normalization - convert TRES keys and units to canonical form."""

import re
from typing import Any, Dict, Optional

from ...utils.converters import (
    convert_size_to_bytes,
    convert_to_float,
    convert_to_int,
    convert_to_physical_cores,
)
from ...utils.timestamps import convert_duration_to_seconds

# Regex for detecting byte-formatted values
_BYTES_RE = re.compile(r"^\s*(\d+(?:\.\d+)?)\s*([KMGT]?)\s*$", re.I)


def normalize_tres_keys_and_units(
    tres_dict: Dict[str, str], threads_per_core: Optional[int] = None
) -> Dict[str, Any]:
    """
    Normalize TRES keys to Pascal_Snake names and convert units to canonical form.

    Handles special cases:
    - 'cpu': Can be duration (HH:MM:SS) or count → Cpu_Time_Seconds or Cpu_Count
    - 'mem': Size with suffix → Mem_Bytes
    - 'billing': Logical count → Billing_Count (converted to PHYSICAL cores)
    - 'energy': Numeric value → Energy_Joules
    - Other keys: Inferred as _Seconds, _Bytes, _Count, or _Value based on format

    Args:
        tres_dict: Raw TRES dictionary from parse_tres_string.
        threads_per_core: Threads per core to convert logical CPU/billing counts
                         to PHYSICAL cores. If None or <1, no conversion applied.

    Returns:
        dict: Normalized dictionary with Pascal_Snake keys and canonical units.
              - Cpu_Count and Billing_Count are PHYSICAL cores when TPC>1
              - Memory values in bytes
              - Time values in seconds
              - Energy in joules

    Examples:
        >>> normalize_tres_keys_and_units({'cpu': '64', 'mem': '187G', 'node': '2'}, threads_per_core=2)
        {'Cpu_Count': 32, 'Mem_Bytes': 200802238464, 'Node_Count': 2}
        >>> normalize_tres_keys_and_units({'cpu': '01:30:00'})
        {'Cpu_Time_Seconds': 5400.0}
    """
    if not tres_dict:
        return {}

    out: Dict[str, Any] = {}

    # Handle 'cpu' - can be duration (usage) or count (allocation)
    if "cpu" in tres_dict:
        cpu_raw = tres_dict["cpu"]
        if ":" in cpu_raw or "-" in cpu_raw:
            # Duration format (HH:MM:SS or DD-HH:MM:SS)
            out["Cpu_Time_Seconds"] = convert_duration_to_seconds(cpu_raw)
        else:
            # Count format - convert to PHYSICAL cores
            logical_cpu = convert_to_int(cpu_raw, 0)
            out["Cpu_Count"] = convert_to_physical_cores(
                logical_cpu, threads_per_core or 1
            )

    # Handle 'mem' - always a size
    if "mem" in tres_dict:
        out["Mem_Bytes"] = convert_size_to_bytes(tres_dict["mem"])

    # Handle 'node' - simple count
    if "node" in tres_dict:
        out["Node_Count"] = convert_to_int(tres_dict["node"], 0)

    # Handle 'billing' - convert to PHYSICAL cores
    if "billing" in tres_dict:
        logical_billing = convert_to_int(tres_dict["billing"], 0)
        out["Billing_Count"] = convert_to_physical_cores(
            logical_billing, threads_per_core or 1
        )

    # Handle other keys - infer units
    for k, v in tres_dict.items():
        if k in ("cpu", "mem", "node", "billing"):
            continue

        kl = k.strip().lower()

        # Special case: energy
        if kl == "energy":
            out["Energy_Joules"] = convert_to_float(v, 0.0)
        else:
            # Infer type from value format
            if ":" in v or "-" in v:
                # Looks like duration
                out[f"{k.title().replace('_', '_')}_Seconds"] = (
                    convert_duration_to_seconds(v)
                )
            elif _BYTES_RE.match(v):
                # Looks like size
                out[f"{k.title().replace('_', '_')}_Bytes"] = convert_size_to_bytes(v)
            else:
                # Try as number
                numf = convert_to_float(v, 0.0)
                if float(numf).is_integer():
                    out[f"{k.title().replace('_', '_')}_Count"] = int(numf)
                else:
                    out[f"{k.title().replace('_', '_')}_Value"] = numf

    return out
