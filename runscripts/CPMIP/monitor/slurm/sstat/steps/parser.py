"""Parser for sstat step data - raw output extraction only."""

from typing import Dict

from ....constants import SSTAT_FIELDS


def parse_sstat_output(output: str) -> Dict[str, Dict[str, str]]:
    """
    Parse raw sstat pipe-delimited output into structured dictionary format.

    Takes the string output from 'sstat -P' command and parses each line
    into a dictionary. Each step gets its own dictionary with field names
    mapped to raw string values (no normalization, no unit conversions).

    This function ONLY parses strings - no command execution, no calculations.

    Args:
        output: Raw output string from sstat command (pipe-delimited format).

    Returns:
        dict: Dictionary mapping step_id (e.g., '12345.0', '12345.batch')
             to raw field values (all strings as returned by sstat).
             Returns empty dict if output is empty or malformed.

    Examples:
        >>> output = "12345.0|4096M|2048M|node01|0|..."
        >>> raw_steps = parse_sstat_output(output)
        >>> raw_steps['12345.0']['MaxRSS']
        '4096M'
    """
    if not output:
        return {}

    steps: Dict[str, Dict[str, str]] = {}
    for line in output.splitlines():
        line = line.strip()
        if not line:
            continue

        # Skip header line (JobID|MaxVMSize|...)
        if line.startswith("JobID|"):
            continue

        cols = line.split("|")
        if len(cols) < 1 + len(SSTAT_FIELDS):
            continue

        step_id = cols[0].strip()

        # Additional check: skip if step_id looks like a header
        if step_id == "JobID":
            continue

        raw: Dict[str, str] = {}
        for i, key in enumerate(SSTAT_FIELDS, start=1):
            raw[key] = cols[i].strip()
        steps[step_id] = raw

    return steps
