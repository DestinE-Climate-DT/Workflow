"""Parser for scontrol show job output."""

import re
from typing import Dict, List

from ...types.slurm import AllocNodeInfo, NodeListInfo


def parse_scontrol_output(output: str) -> Dict[str, str]:
    """
    Parse 'scontrol show job <jobid>' output into a flat dictionary.

    The scontrol output is a space-separated key=value format on one or more lines.
    This function handles multi-line output and quoted values.

    Args:
        output: Raw output text from scontrol command.

    Returns:
        dict: Flat dictionary mapping field names to string values.
              Removes surrounding quotes from values.

    Examples:
        >>> output = 'JobId=12345 JobName=test Partition=main'
        >>> parse_scontrol_output(output)
        {'JobId': '12345', 'JobName': 'test', 'Partition': 'main'}
    """
    job_info: Dict[str, str] = {}
    clean_output = " ".join((output or "").split())

    # Use regex to parse key=value pairs, respecting quoted values
    # Pattern: key="quoted value" or key='quoted value' or key=unquoted_value
    # Allow : in key names for fields like AllocNode:Sid
    pattern = r'([\w:]+)=(?:"([^"]*)"|\'([^\']*)\'|(\S+))'

    for match in re.finditer(pattern, clean_output):
        key = match.group(1)
        # Value can be in group 2 (double quotes), 3 (single quotes), or 4 (unquoted)
        value = match.group(2) or match.group(3) or match.group(4) or ""
        job_info[key] = value

    return job_info


def parse_alloc_node(alloc_node_str: str) -> AllocNodeInfo:
    """
    Parse AllocNode field which may contain session ID information.

    AllocNode format can be:
    - 'Sid=node:123' (with Sid= prefix)
    - 'node:123' (without prefix)
    - 'node' (just node name)

    Args:
        alloc_node_str: AllocNode string from scontrol output.

    Returns:
        AllocNodeInfo: Dictionary with 'Node' and 'Session_Id' fields.
                      Session_Id is empty string if not present.

    Examples:
        >>> parse_alloc_node('Sid=node01:12345')
        {'Node': 'node01', 'Session_Id': '12345'}
        >>> parse_alloc_node('node01:12345')
        {'Node': 'node01', 'Session_Id': '12345'}
        >>> parse_alloc_node('node01')
        {'Node': 'node01', 'Session_Id': ''}
    """
    if not alloc_node_str:
        return {"Node": "", "Session_Id": ""}

    # Remove "Sid=" prefix if present
    if alloc_node_str.startswith("Sid="):
        alloc_node_str = alloc_node_str[4:]

    # Split on FIRST colon only to handle cases like node:extra:12345
    if ":" in alloc_node_str:
        parts = alloc_node_str.split(":", 1)
        return {"Node": parts[0], "Session_Id": parts[1]}

    # No colon: just node name
    return {"Node": alloc_node_str, "Session_Id": ""}


def parse_nodelist(node_list_str: str) -> NodeListInfo:
    """
    Parse SLURM nodelist string and expand into concrete node names.

    SLURM uses compact notation for node ranges:
    - 'nid[01-04,19]' expands to ['nid01', 'nid02', 'nid03', 'nid04', 'nid19']
    - 'node01,node02' expands to ['node01', 'node02']
    - Single node 'node01' expands to ['node01']

    Args:
        node_list_str: Raw nodelist string from SLURM (NodeList field).

    Returns:
        NodeListInfo: Dictionary with 'Nodes' (list of expanded names)
                     and 'Count' (number of nodes).

    Examples:
        >>> parse_nodelist('nid[001-003]')
        {'Nodes': ['nid001', 'nid002', 'nid003'], 'Count': 3}
        >>> parse_nodelist('node01,node02')
        {'Nodes': ['node01', 'node02'], 'Count': 2}
        >>> parse_nodelist('')
        {'Nodes': [], 'Count': 0}
    """
    if not node_list_str:
        return NodeListInfo(Nodes=[], Count=0)

    nodes: List[str] = []

    # Process each comma-separated part, being careful with brackets
    # Use regex to find all bracket groups and individual nodes
    parts_to_process = []

    # Split by comma, but we need to be smart about brackets
    current_part = ""
    bracket_depth = 0

    for char in node_list_str:
        if char == "[":
            bracket_depth += 1
            current_part += char
        elif char == "]":
            bracket_depth -= 1
            current_part += char
        elif char == "," and bracket_depth == 0:
            # Comma outside brackets - this is a separator
            if current_part.strip():
                parts_to_process.append(current_part.strip())
            current_part = ""
        else:
            current_part += char

    # Don't forget the last part
    if current_part.strip():
        parts_to_process.append(current_part.strip())

    # Now process each part
    for part in parts_to_process:
        # Check for bracket notation: prefix[ranges]
        if "[" in part and "]" in part:
            m = re.match(r"([^[]+)\[([^\]]+)\]", part)
            if m:
                prefix = m.group(1)
                inner = m.group(2)
                range_parts = [p.strip() for p in inner.split(",")]

                for range_part in range_parts:
                    # Handle numeric ranges: 01-04
                    if "-" in range_part and all(
                        p.isdigit() for p in range_part.split("-")
                    ):
                        try:
                            start_s, end_s = range_part.split("-", 1)
                            start, end = int(start_s), int(end_s)
                            if start > end:
                                print(
                                    f"WARNING: Invalid node range {range_part} (start > end)"
                                )
                                continue
                            # Preserve zero-padding width
                            width = len(start_s)
                            for i in range(start, end + 1):
                                nodes.append(f"{prefix}{str(i).zfill(width)}")
                        except (ValueError, IndexError) as e:
                            print(
                                f"ERROR: Error parsing node range '{range_part}' - {e}"
                            )
                    # Handle single numbers: 19
                    elif range_part.isdigit():
                        nodes.append(f"{prefix}{range_part}")
                    else:
                        print(f"WARNING: Unrecognized node part format '{range_part}'")
        else:
            # Individual node without brackets (e.g., "nid005" in "nid[001-002],nid005")
            nodes.append(part)

    return NodeListInfo(Nodes=nodes, Count=len(nodes))
