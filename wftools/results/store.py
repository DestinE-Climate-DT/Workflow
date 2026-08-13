from __future__ import annotations

import json
from pathlib import Path
from typing import Union

from loguru import logger
from pydantic import ValidationError

from wftools.domain.models import TestCase, TestResult


class ResultStore:
    """Manages intermediate test result JSON files on disk."""

    def __init__(self, base_dir: Path = Path("reports/tsuite_results")):
        self.base_dir = base_dir

    def save(self, result: Union[TestResult, TestCase], key: str | None = None) -> Path:
        """Write a result as JSON. Key defaults to result.name.

        Case names carry a ``{type}/`` prefix; the store is flat, so the
        separator is folded into the filename rather than a subdirectory.
        """
        self.base_dir.mkdir(parents=True, exist_ok=True)
        filename = (key or result.name).replace("/", "_")
        path = self.base_dir / f"{filename}.json"
        path.write_text(result.model_dump_json(indent=2))
        logger.debug("Saved result to {}", path)
        return path

    def load_all(self) -> list[Union[TestResult, TestCase]]:
        """Read all .json files, return as model instances.

        Tries TestCase first (richer model), falls back to TestResult.
        Skips corrupt files with a warning.
        """
        if not self.base_dir.is_dir():
            return []

        results = []
        for path in sorted(self.base_dir.glob("*.json")):
            try:
                raw = path.read_text()
                # Try TestCase first (has more fields), fall back to TestResult
                try:
                    results.append(TestCase.model_validate_json(raw))
                except ValidationError:
                    results.append(TestResult.model_validate_json(raw))
            except (json.JSONDecodeError, ValidationError, OSError) as exc:
                logger.warning("Skipping corrupt result file {}: {}", path, exc)
        return results

    def clean(self) -> int:
        """Remove all .json files and the directory. Return count deleted."""
        if not self.base_dir.is_dir():
            return 0

        count = 0
        for path in self.base_dir.glob("*.json"):
            path.unlink()
            count += 1

        # Remove the directory if empty
        try:
            self.base_dir.rmdir()
        except OSError:
            pass  # Not empty (non-json files exist), that's fine

        logger.debug("Cleaned {} result files from {}", count, self.base_dir)
        return count
