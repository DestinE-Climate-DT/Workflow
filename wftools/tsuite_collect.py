"""Aggregate the child pipeline's tsuite results into the parent's reports.

`tsuite-collect` fires exactly once, when the trigger bridge resolves; GitLab
has no way to re-fire it when a child chain is retried afterwards.  Collection
therefore stamps the source expid and producing child job into everything it
publishes, and leaves a receipt behind so a later re-run can tell that what the
MR displays is already superseded.
"""

from __future__ import annotations

import shutil
import xml.etree.ElementTree as ET
from collections import defaultdict
from collections.abc import Iterable
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path

PROVENANCE_FILE = "provenance.txt"
REPORT_GLOB = "tsuite-report-*.xml"
METRICS_GLOB = "metrics-*.txt"
RECEIPT_GLOB = "collected-*.txt"
# Per-expid resource records: plain files, so artifacts:paths carries them and
# artifacts:reports must not.
EXTRA_GLOBS = ("resources-*.json",)
# Receipts outlive the results dir by design, so collection prunes its own.
# Matched to the job's `expire_in`: past that a receipt can no longer point at
# artifacts anyone could still fetch.
RECEIPT_RETENTION = timedelta(days=14)


def receipt_path(shared_dir: Path) -> Path:
    """Path of the receipt collection leaves beside (not inside) *shared_dir*.

    Kept outside so the terminal ``rm -rf`` of the results dir stays intact: a
    later re-run repopulates an empty directory and a retried collect then sees
    the new attempt only, never a merge of both.
    """
    return shared_dir.parent / f"collected-{shared_dir.name}.txt"


@dataclass(frozen=True)
class Source:
    """One child job's contribution, as recorded in the provenance sidecar."""

    expid: str = ""
    type_name: str = ""
    phase: str = ""
    job: str = ""
    url: str = ""
    at: str = ""

    def as_line(self) -> str:
        return (
            f"expid={self.expid} type={self.type_name} phase={self.phase} "
            f"job={self.job} url={self.url} at={self.at}"
        )


def parse_provenance(text: str) -> list[Source]:
    """Parse the ``key=value`` provenance lines the child jobs append."""
    sources = []
    for line in text.splitlines():
        if not line.strip():
            continue
        fields: dict[str, str] = {}
        for token in line.split():
            key, sep, value = token.partition("=")
            if sep:
                fields[key] = value
        sources.append(
            Source(
                expid=fields.get("expid", ""),
                type_name=fields.get("type", ""),
                phase=fields.get("phase", ""),
                job=fields.get("job", ""),
                url=fields.get("url", ""),
                at=fields.get("at", ""),
            )
        )
    return sources


def merge_metrics(files: Iterable[Path]) -> dict[str, str]:
    """Sum ``key value`` metric files into one mapping of formatted totals.

    Counts and fractional hours/kWh mix, so values are summed as floats and
    rendered with a decimal point only where one is needed.
    """
    totals: dict[str, float] = defaultdict(float)
    for path in files:
        for line in path.read_text().splitlines():
            parts = line.split()
            if len(parts) != 2:
                continue
            try:
                value = float(parts[1])
            except ValueError:
                continue
            totals[parts[0]] += value
    return {
        key: (str(int(value)) if value.is_integer() else f"{value:.4f}")
        for key, value in sorted(totals.items())
    }


def provenance_metrics(
    sources: Iterable[Source], collected_at: datetime
) -> dict[str, str]:
    """Labelled gauges naming every expid/child job behind the published totals.

    These are what make a superseded report self-identifying in the MR's
    metrics widget -- the numbers alone look the same either way.
    """
    metrics = {
        "tsuite_collected_at": str(int(collected_at.timestamp())),
    }
    for source in sorted(set(sources), key=lambda s: (s.expid, s.phase)):
        if not source.expid:
            continue
        label = (
            f'tsuite_source{{expid="{source.expid}",type="{source.type_name}",'
            f'phase="{source.phase}",job="{source.job}"}}'
        )
        metrics[label] = "1"
    return metrics


def _expid_of(report: Path) -> str:
    """Extract the expid from a ``tsuite-report-<expid>[.<phase>].xml`` filename."""
    return report.stem.replace("tsuite-report-", "", 1).split(".", 1)[0]


def stamp_report(
    report: Path, sources: Iterable[Source], collected_at: datetime
) -> None:
    """Record the producing child job(s) as ``<testsuite>`` properties."""
    try:
        tree = ET.parse(report)
    except ET.ParseError:
        return
    root = tree.getroot()

    props = root.find("properties")
    if props is None:
        # JUnit puts <properties> first among the testsuite's children.
        props = ET.Element("properties")
        root.insert(0, props)

    def add(name: str, value: str) -> None:
        prop = ET.SubElement(props, "property")
        prop.set("name", name)
        prop.set("value", value)

    add("source_expid", _expid_of(report))
    add("collected_at", collected_at.isoformat())
    for source in sources:
        if source.job:
            add(f"child_job_{source.phase or 'unknown'}", source.job)
        if source.url:
            add(f"child_job_url_{source.phase or 'unknown'}", source.url)

    ET.indent(tree, space="  ")
    tree.write(report, encoding="unicode", xml_declaration=True)


@dataclass
class CollectResult:
    """Outcome of one collection pass.

    ``status`` is one of:

    * ``collected``  -- results were found and published;
    * ``empty``      -- no results and no prior receipt (nothing ever ran);
    * ``stale``      -- no results but a receipt exists, i.e. this job was
      retried without the child having produced anything new.
    """

    status: str
    sources: list[Source] = field(default_factory=list)
    reports: list[Path] = field(default_factory=list)
    extras: list[Path] = field(default_factory=list)
    metrics: dict[str, str] = field(default_factory=dict)
    prior_receipt: str = ""


def _write_receipt(
    shared_dir: Path, result: CollectResult, collected_at: datetime, job_url: str
) -> None:
    expids = sorted({s.expid for s in result.sources if s.expid}) or [
        _expid_of(r) for r in result.reports
    ]
    receipt = receipt_path(shared_dir)
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.write_text(
        f"collected_at={collected_at.isoformat()}\n"
        f"collect_job_url={job_url}\n"
        f"expids={','.join(expids)}\n"
        f"reports={','.join(r.name for r in result.reports)}\n"
    )
    _prune_receipts(receipt.parent, collected_at)


def _prune_receipts(root: Path, now: datetime) -> None:
    """Drop expired receipts, which nothing else on the runner reclaims."""
    cutoff = (now - RECEIPT_RETENTION).timestamp()
    for path in root.glob(RECEIPT_GLOB):
        try:
            if path.stat().st_mtime < cutoff:
                path.unlink()
        except OSError:
            # Another pipeline's collect is pruning the same directory.
            continue


def _clear_previous(reports_dir: Path) -> None:
    """Drop anything a previous collection left in *reports_dir*.

    A retried collect must publish the new attempt alone.  The runner normally
    hands out a clean workspace, but relying on that would let a superseded
    report survive into the JUnit -- and fail the gate on a green re-run.
    Only the files collection itself writes are removed, so a report pulled in
    from `needs:` under another name is left alone.
    """
    for glob in (REPORT_GLOB, *EXTRA_GLOBS):
        for path in reports_dir.glob(glob):
            path.unlink()
    for name in (PROVENANCE_FILE, "metrics.txt", "metrics-all.txt"):
        (reports_dir / name).unlink(missing_ok=True)


def collect(
    shared_dir: Path,
    reports_dir: Path,
    *,
    job_url: str = "",
    now: datetime | None = None,
) -> CollectResult:
    """Publish the child's results from *shared_dir* into *reports_dir*.

    Copies the per-expid JUnit reports, rolls the per-expid metrics into a
    single ``metrics.txt``, stamps provenance onto both, then writes the
    receipt and removes *shared_dir* so a subsequent re-run starts clean.
    """
    collected_at = now or datetime.now(timezone.utc)
    receipt = receipt_path(shared_dir)
    prior = receipt.read_text() if receipt.is_file() else ""

    # Always present, so `artifacts: paths: reports/` has something to upload
    # even when there was nothing to collect.
    reports_dir.mkdir(parents=True, exist_ok=True)

    if not shared_dir.is_dir():
        return CollectResult(status="stale" if prior else "empty", prior_receipt=prior)

    _clear_previous(reports_dir)
    provenance = shared_dir / PROVENANCE_FILE
    sources = parse_provenance(provenance.read_text()) if provenance.is_file() else []
    by_expid: dict[str, list[Source]] = defaultdict(list)
    for source in sources:
        by_expid[source.expid].append(source)

    reports = []
    for xml in sorted(shared_dir.glob(REPORT_GLOB)):
        target = reports_dir / xml.name
        shutil.copy2(xml, target)
        stamp_report(target, by_expid.get(_expid_of(target), []), collected_at)
        reports.append(target)

    extras = []
    for glob in EXTRA_GLOBS:
        for path in sorted(shared_dir.glob(glob)):
            shutil.copy2(path, reports_dir / path.name)
            extras.append(reports_dir / path.name)

    metric_files = sorted(shared_dir.glob(METRICS_GLOB))
    if metric_files:
        (reports_dir / "metrics-all.txt").write_text(
            "".join(path.read_text() for path in metric_files)
        )
    metrics = merge_metrics(metric_files)
    metrics.update(provenance_metrics(sources, collected_at))
    (reports_dir / "metrics.txt").write_text(
        "".join(f"{key} {value}\n" for key, value in metrics.items())
    )

    if sources:
        (reports_dir / PROVENANCE_FILE).write_text(
            "".join(f"{s.as_line()}\n" for s in sources)
        )

    result = CollectResult(
        status="collected",
        sources=sources,
        reports=reports,
        extras=extras,
        metrics=metrics,
        prior_receipt=prior,
    )
    _write_receipt(shared_dir, result, collected_at, job_url)
    shutil.rmtree(shared_dir, ignore_errors=True)
    return result
