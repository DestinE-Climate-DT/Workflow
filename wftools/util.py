from __future__ import annotations

import re
from typing import Optional


def strip_ansi(text: str) -> str:
    """Remove ANSI escape codes from text."""
    return re.sub(r"\x1b\[[0-9;]*[mGKHF]", "", text)


def extract_error_summary(err_content: str) -> str:
    """Extract a concise one-line error summary from .err file content.

    The .err files are bash scripts run with ``set -xuve``, so most lines
    are trace output (prefixed with ``+``).  The real error is usually
    near the end.  We scan for known patterns and fall back to the last
    non-trace line.
    """
    if not err_content or not err_content.strip():
        return "Job failed \u2014 see full log for details"

    lines = err_content.splitlines()

    # --- 1. Scan for known error patterns (prefer later occurrences) ---
    error_patterns = [
        # Python tracebacks -- last exception line
        re.compile(r"^\s*\w*(Error|Exception):\s+.*"),
        re.compile(r"^\s*Traceback \(most recent call last\)"),
        # grib tool errors
        re.compile(r"^\s*grib_(set|get)\s*:.*"),
        # SLURM errors
        re.compile(r"^\s*slurmstepd:\s*error:.*"),
        re.compile(r"^\s*srun:\s*error:.*"),
        # Generic fatal indicators (but not in bash trace lines starting with +)
        re.compile(
            r"^[^+].*\b(FATAL|Segmentation fault|Killed|Out of memory)\b.*",
            re.IGNORECASE,
        ),
        # Non-zero exit code lines (not exit 0)
        re.compile(r"^\s*exit\s+[1-9]\d*"),
    ]

    last_match: Optional[str] = None
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        for pat in error_patterns:
            if pat.search(stripped):
                last_match = stripped
                break  # first pattern wins per line; keep scanning later lines

    if last_match:
        return last_match[:200]

    # --- 2. Last non-empty, non-trace line ---
    for line in reversed(lines):
        stripped = line.strip()
        if stripped and not stripped.startswith("+"):
            return stripped[:200]

    # --- 3. Nothing useful found ---
    return "Job failed \u2014 see full log for details"
