"""TRES (Trackable RESource) string parsing."""

from typing import Dict


def parse_tres_string(tres_str: str) -> Dict[str, str]:
    """
    Parse TRES string into raw dictionary of key-value pairs.

    TRES format is comma-separated list of key=value pairs.
    Example: 'cpu=64,mem=187G,node=2,billing=128'

    Args:
        tres_str: Raw TRES string from SLURM command output.

    Returns:
        dict: Mapping of resource keys to raw string values.
              Returns empty dict if input is None, empty, or invalid.

    Examples:
        >>> parse_tres_string('cpu=64,mem=187G,node=2')
        {'cpu': '64', 'mem': '187G', 'node': '2'}
        >>> parse_tres_string('N/A')
        {}
        >>> parse_tres_string('')
        {}
    """
    if not tres_str or tres_str in ("N/A", "Unknown", ""):
        return {}

    tres: Dict[str, str] = {}
    for item in tres_str.split(","):
        if "=" in item:
            k, v = item.split("=", 1)
            tres[k.strip()] = v.strip()
    return tres
