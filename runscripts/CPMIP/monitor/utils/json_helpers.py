"""JSON serialization and file handling utilities."""

import gzip
import json
import os
from typing import Any, Dict


def round_floats_2dp(obj: Any) -> Any:
    """
    Recursively round floats to 2 decimals in any JSON-serializable structure.

    Args:
        obj: Any JSON-serializable object (dict, list, float, etc.).

    Returns:
        The same structure with all floats rounded to 2 decimal places.

    Examples:
        >>> round_floats_2dp({"cpu": 45.6789, "mem": 1024})
        {'cpu': 45.68, 'mem': 1024}
        >>> round_floats_2dp([1.234, 5.678, 9])
        [1.23, 5.68, 9]
    """
    if isinstance(obj, dict):
        return {k: round_floats_2dp(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [round_floats_2dp(v) for v in obj]
    if isinstance(obj, float):
        return round(obj, 2)
    return obj


def save_json_gz(path: str, data: Dict[str, Any]) -> None:
    """
    Save a dict to a GZIP-compressed JSON file, overwriting existing content.
    Floats are rounded to 2 decimals; booleans are kept as-is.

    Args:
        path: Output file path for the compressed JSON.
        data: Dictionary to save.

    Returns:
        None

    Examples:
        >>> save_json_gz("/tmp/test.json.gz", {"cpu": 45.6789, "active": True})
        # Creates /tmp/test.json.gz with rounded floats
    """
    os.makedirs(os.path.dirname(path), exist_ok=True)
    safe = round_floats_2dp(data)
    with gzip.open(path, "wt", encoding="utf-8") as f:
        json.dump(safe, f, ensure_ascii=False, indent=2)
