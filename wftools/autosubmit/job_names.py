"""The Autosubmit job-name grammar, shared by everything that reads one.

A job name is the experiment id, then whichever run coordinates apply, then the
section; a name that is nothing but coordinates has no section::

    a006_LOCAL_SETUP                -> LOCAL_SETUP
    a006_19900101_fc0_1_SIM         -> SIM       [fc0_1]
    a006_19900101_fc0_1_9_TRANSFER  -> TRANSFER  [fc0_1_9]
    a006_19900101_fc0_1             -> (none)
"""

from __future__ import annotations

import re
from typing import NamedTuple, Optional

_JOB_NAME = re.compile(
    r"(?:(?P<date>\d{8})_)?"  # start date
    r"(?:(?P<member>fc\d+(?:_\d+)?)_)?"  # member, chunk glued on
    r"(?:(?P<split>\d+)_)?"  # split
    r"(?P<section>.+)"
)


class JobNameParts(NamedTuple):
    section: Optional[str]
    date: Optional[str]
    member: Optional[str]
    split: Optional[str]

    @property
    def context(self) -> Optional[str]:
        """The coordinates that identify this run of the section, if any."""
        return "_".join(p for p in (self.member, self.split) if p) or None


_EMPTY = JobNameParts(None, None, None, None)


def split_job_name(expid: str, job_name: Optional[str]) -> JobNameParts:
    """Split an Autosubmit job name into its section and run coordinates."""
    name = (job_name or "").strip()
    suffix = (
        name[len(expid) :].lstrip("_") if expid and name.startswith(expid) else name
    )
    match = _JOB_NAME.fullmatch(suffix) if suffix else None
    if match is None:
        return _EMPTY

    section = match.group("section")
    # Bare digits are a trailing coordinate, never a section name.
    if section.isdigit():
        section = None
    return JobNameParts(
        section, match.group("date"), match.group("member"), match.group("split")
    )
