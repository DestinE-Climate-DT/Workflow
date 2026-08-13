from __future__ import annotations

from datetime import datetime
from typing import ClassVar, List, Optional, Union

from pydantic import BaseModel, Field, field_validator


class SlurmMetadata(BaseModel):
    slurm_id: Optional[str] = None
    platform: Optional[str] = None
    queue: Optional[str] = None


class TestResult(BaseModel):
    """Coarse result from `add` command. No job-level detail."""

    # Tell pytest these aren't test classes (the Test* prefix triggers
    # auto-collection and emits a PytestCollectionWarning otherwise).
    __test__: ClassVar[bool] = False

    name: str
    passed: bool
    skipped: bool = False
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())
    error: Optional[str] = None


class TestCase(TestResult):
    """Per-job result from `parse` command. Extends TestResult with job metadata."""

    __test__: ClassVar[bool] = False

    full_job_name: Optional[str] = None
    classname: Optional[str] = None
    error_summary: Optional[str] = None
    status: Optional[str] = None
    slurm: SlurmMetadata = Field(default_factory=SlurmMetadata)
    duration: Optional[float] = None

    @field_validator("classname")
    @classmethod
    def validate_classname(cls, v):
        if v is not None and len(v) != 4:
            raise ValueError(
                f"classname (expid) must be exactly 4 characters, got {len(v)}: {v!r}"
            )
        return v


class TestSuite(BaseModel):
    """Aggregation of test results -- maps to a JUnit testsuite element."""

    __test__: ClassVar[bool] = False

    name: str = "tsuite"
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())
    cases: List[Union[TestCase, TestResult]] = Field(default_factory=list)

    @property
    def total(self) -> int:
        return len(self.cases)

    @property
    def failures(self) -> int:
        return sum(1 for c in self.cases if not c.passed and not c.skipped)

    @property
    def skipped_count(self) -> int:
        return sum(1 for c in self.cases if c.skipped)
