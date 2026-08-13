from __future__ import annotations

import os
from pathlib import Path

# Root of Autosubmit experiment data; override via WFTOOLS_AS_DATA_ROOT.
AS_DATA_ROOT = Path(os.environ.get("WFTOOLS_AS_DATA_ROOT", "/appl/AS/AUTOSUBMIT_DATA"))

FAILED_STATUSES = frozenset({"FAILED", "ABORTED", "UNKNOWN"})
SKIPPED_STATUSES = frozenset({"WAITING", "SUSPENDED", "HELD"})

ERROR_FILE_CAP = 512 * 1024  # 512 KB max for .err file content
ERROR_SUMMARY_CAP = 200  # max chars for error summary
ADD_ERROR_CAP = 1024 * 1024  # 1 MB max for add-result error content
