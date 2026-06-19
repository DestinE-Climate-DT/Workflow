"""
Parser for the ICON climate model.

ICON's compute / I/O split is taken from the task counts the SIM captured at
runtime (with the real SLURM_GPUS_ON_NODE) and recorded in the performance env
file's IO_CONFIG block (exposed here as self.icon_resources):

    atm_compute_tasks / oce_tasks  -> Compute ranks
    yaco_tasks                     -> I/O ranks (the YAC output servers)
    total                          -> sum of the three

The compute / I/O time split comes from the per-rank-range timer reports in
``icon_run.log`` (in the rundir), read from the ``total avg (s)`` column (mean
across that component's PEs). ATM and OCE are the compute components: each one's
Compute = ``total`` - ``coupling_output`` and its I/O = ``coupling_output``.
Because they run concurrently, the model-level values are averaged across them
(Compute = Total - IO). The ``coupling_output`` timer lives on the ATM/OCE ranks,
not YACO; it is used as the I/O time because YACO (the YAC output server) writes
asynchronously and has no synchronous I/O timer of its own. The coupling_output
I/O is attributed to the YACO component. Times are zero when the log is missing
or unparseable.
"""

import os
import re
from typing import Any, Dict

from .base_parser import IOMetrics, ModelParser, ComponentMetrics


# Strips the "<timestamp>:  <rank>:  " line prefix ICON prints on every timer row.
_TIMER_PREFIX_RE = re.compile(r"^\S+:\s+\d+:\s+")


class ICONParser(ModelParser):
    """Parser for ICON model output."""

    def _get_model_name(self) -> str:
        """
        Return the name of the model.

        Args:
            None

        Returns:
            str: 'ICON'.
        """
        return "ICON"

    def parse(self) -> IOMetrics:
        """
        Build IOMetrics for an ICON run.

        Compute / IO times come from icon_run.log (see module docstring);
        resources come from the SIM-provided IO_CONFIG task counts.

        Args:
            None

        Returns:
            IOMetrics: With Resources and Times populated (Times are zero when
            icon_run.log is missing or has no parseable timer reports).
        """
        time_metrics = self._extract_time_metrics()
        resource_metrics = self._extract_resource_metrics()

        notes = list(resource_metrics.get("allocation_notes", []))
        if time_metrics.get("total_time", 0.0) > 0:
            notes.append(
                "ICON times from icon_run.log (total-avg column): ATM/OCE are the "
                "compute components (Compute = total - coupling_output, IO = "
                "coupling_output), averaged across them since they run "
                "concurrently; Compute = Total - IO"
            )
            notes.append(
                "I/O time is the 'coupling_output' timer measured on the ATM/OCE "
                "(compute) ranks, NOT on YACO; it is used as the model I/O time "
                "because YACO writes output asynchronously and has no synchronous "
                "I/O timer of its own. The coupling_output I/O is attributed to "
                "the YACO component"
            )
        else:
            notes.append(
                "ICON timing unavailable (icon_run.log missing or no parseable "
                "timer reports); Compute/IO/Total times are zero"
            )

        atm_compute_tasks = resource_metrics.get("atm_compute_tasks", 0)
        oce_compute_tasks = resource_metrics.get("oce_compute_tasks", 0)
        yaco_tasks = resource_metrics.get("yaco_tasks", 0)

        atm_cores = self._calculate_physical_cores(atm_compute_tasks)
        oce_cores = self._calculate_physical_cores(oce_compute_tasks)
        yaco_cores = self._calculate_physical_cores(yaco_tasks)

        components: Dict[str, ComponentMetrics] = {
            "ATM": self._component_metrics(
                time_metrics, "atm", atm_compute_tasks, atm_cores
            ),
            "OCE": self._component_metrics(
                time_metrics, "oce", oce_compute_tasks, oce_cores
            ),
            "YACO": self._component_metrics(
                time_metrics, "yaco", yaco_tasks, yaco_cores
            ),
        }

        resource_metrics_clean = {
            "compute_tasks": resource_metrics["compute_tasks"],
            "io_tasks": resource_metrics["io_tasks"],
            "total_tasks": resource_metrics["total_tasks"],
        }

        return self._calculate_metrics(
            time_metrics, resource_metrics_clean, components, notes
        )

    def _extract_time_metrics(self) -> Dict[str, float]:
        """
        Build the ICON compute / I/O time split from icon_run.log.

        ICON prints one timer report per rank-range (one per concurrently
        running component). For each report this reads the ``total avg (s)``
        column of the ``total`` row (the component runtime) and of the
        ``coupling_output`` row (the component I/O time), both averaged across
        that component's PEs. Reports are mapped to ATM / OCE / YACO by matching
        the report's PE count to the SIM-provided task counts.

        Because the components run concurrently, the model-level Total and IO
        are the mean across components and Compute = Total - IO.

        Args:
            None

        Returns:
            Dict[str, float]: io_time / total_time / compute_time plus the
            per-component <atm|oce|yaco>_{total,io}_time values. All zero when
            icon_run.log is missing or has no parseable timer reports.
        """
        metrics: Dict[str, float] = {
            "io_time": 0.0,
            "total_time": 0.0,
            "compute_time": 0.0,
            "atm_total_time": 0.0,
            "atm_io_time": 0.0,
            "oce_total_time": 0.0,
            "oce_io_time": 0.0,
            "yaco_total_time": 0.0,
            "yaco_io_time": 0.0,
        }

        if not self.rundir_path:
            return metrics
        log_path = os.path.join(self.rundir_path, "icon_run.log")
        if not os.path.isfile(log_path):
            return metrics

        blocks = self._parse_timer_reports(log_path)
        if not blocks:
            return metrics

        # Map each report to a component by matching its PE count to the
        # SIM-provided task counts. Unmatched reports (e.g. if the YAC output
        # servers emit one) still feed the model-level mean below.
        override = self.icon_resources or {}

        def _count(key: str) -> int:
            try:
                return int(override.get(key, 0) or 0)
            except (TypeError, ValueError):
                return 0

        pes_to_component = {}
        for comp, key in (
            ("atm", "atm_compute_tasks"),
            ("oce", "oce_tasks"),
            ("yaco", "yaco_tasks"),
        ):
            count = _count(key)
            if count > 0:
                pes_to_component[count] = comp

        # ATM/OCE are the compute components; record each one's total and
        # coupling_output for the breakdown. The YAC output server (YACO) is the
        # asynchronous I/O server and is handled separately below — its report,
        # if any, is dropped from the compute average.
        compute_blocks = []
        for blk in blocks:
            comp = pes_to_component.get(blk["pes"])
            if comp == "yaco":
                continue
            if comp in ("atm", "oce"):
                metrics[f"{comp}_total_time"] = blk["total"]
                metrics[f"{comp}_io_time"] = blk["io"]
            compute_blocks.append(blk)

        if not compute_blocks:
            return metrics

        # Concurrent compute components: average runtime and coupling_output
        # across them. coupling_output is the model I/O time (it is timed on the
        # compute ranks, not YACO; see the note in parse()).
        n = len(compute_blocks)
        total_time = sum(b["total"] for b in compute_blocks) / n
        io_time = sum(b["io"] for b in compute_blocks) / n
        metrics["total_time"] = total_time
        metrics["io_time"] = io_time
        metrics["compute_time"] = max(total_time - io_time, 0.0)

        # Attribute the coupling_output I/O to YACO (Compute = total - io = 0 in
        # _component_metrics): YACO accounts for the asynchronous output.
        metrics["yaco_total_time"] = io_time
        metrics["yaco_io_time"] = io_time
        return metrics

    def _parse_timer_reports(self, log_path: str) -> list:
        """
        Return one entry per timer report in icon_run.log.

        Each entry is {"pes": int, "total": float, "io": float}, where ``total``
        and ``io`` are the ``total avg (s)`` column of the report's ``total`` and
        ``coupling_output`` rows. The 12 trailing numeric columns are taken from
        the right of each row so timer names containing spaces don't break the
        split; rows are grouped into reports by their leading ``total`` row.

        Args:
            log_path: Path to icon_run.log.

        Returns:
            list: One dict per report; empty if none are found or readable.
        """
        blocks: list = []
        current = None

        try:
            with open(log_path, "r", encoding="utf-8", errors="replace") as handle:
                lines = handle.readlines()
        except OSError:
            return blocks

        for raw in lines:
            tokens = _TIMER_PREFIX_RE.sub("", raw).split()
            # name + 12 columns (# calls ... total avg (s) ... # PEs).
            if len(tokens) < 13:
                continue
            name = tokens[-13]
            if name not in ("total", "coupling_output"):
                continue
            cols = tokens[-12:]
            try:
                total_avg = float(cols[10].rstrip("s"))
                pes = int(cols[11])
            except (ValueError, IndexError):
                continue
            if name == "total":
                if current is not None:
                    blocks.append(current)
                current = {"pes": pes, "total": total_avg, "io": 0.0}
            elif current is not None:
                current["io"] = total_avg

        if current is not None:
            blocks.append(current)
        return blocks

    @staticmethod
    def _component_metrics(
        time_metrics: Dict[str, float], key: str, tasks: int, cores: int
    ) -> ComponentMetrics:
        """
        Assemble one component's ComponentMetrics from the extracted times.

        Args:
            time_metrics: Output of _extract_time_metrics.
            key: Component prefix ('atm' / 'oce' / 'yaco').
            tasks: MPI task count for the component.
            cores: Physical core count for the component.

        Returns:
            ComponentMetrics: Compute/IO/Total times (Compute = Total - IO,
            clamped at 0) and the component's resources.
        """
        total = max(time_metrics.get(f"{key}_total_time", 0.0), 0.0)
        io = time_metrics.get(f"{key}_io_time", 0.0)
        io = min(max(io, 0.0), total) if total > 0 else max(io, 0.0)
        compute = max(total - io, 0.0)
        io_pct = (io / total * 100) if total > 0 else 0.0
        compute_pct = (compute / total * 100) if total > 0 else 0.0
        return {
            "Compute": {"Time_Seconds": compute, "Percentage": compute_pct},
            "IO": {"Time_Seconds": io, "Percentage": io_pct},
            "Total": total,
            "Resources": {"MPI_Tasks": tasks, "Physical_Cores": cores},
        }

    def _extract_resource_metrics(self) -> Dict[str, Any]:
        """
        Read ATM / OCE / YACO task counts from the SIM-provided IO_CONFIG.

        The SIM captures the numbers the runscript actually computed at runtime
        (with the real SLURM_GPUS_ON_NODE) and records them in the performance
        env file's IO_CONFIG block; this parser uses them directly. There is no
        static-file or default fallback: when the counts are absent every task
        count is reported as zero.

        Args:
            None

        Returns:
            Dict: Contains compute_tasks / io_tasks / total_tasks (the keys
            ``_calculate_metrics`` needs) plus the per-component breakdown
            and an ``allocation_notes`` list documenting the source.
        """
        notes = []

        override = self.icon_resources or {}

        def _ov(key: str) -> int:
            try:
                return int(override.get(key, 0) or 0)
            except (TypeError, ValueError):
                return 0

        atm_compute_tasks = _ov("atm_compute_tasks")
        oce_compute_tasks = _ov("oce_tasks")
        yaco_tasks = _ov("yaco_tasks")

        compute_tasks = atm_compute_tasks + oce_compute_tasks
        io_tasks = yaco_tasks
        total_tasks = compute_tasks + io_tasks

        if total_tasks > 0:
            notes.append(
                f"ICON allocation from SIM-provided task counts: "
                f"ATM={atm_compute_tasks}, OCE={oce_compute_tasks}, "
                f"YACO/IO={yaco_tasks}, total={total_tasks}"
            )
        else:
            notes.append(
                "ICON task counts unavailable (no SIM-provided IO_CONFIG in the "
                "performance env file); reporting zero tasks"
            )

        return {
            "compute_tasks": compute_tasks,
            "io_tasks": io_tasks,
            "total_tasks": total_tasks,
            "atm_compute_tasks": atm_compute_tasks,
            "oce_compute_tasks": oce_compute_tasks,
            "yaco_tasks": yaco_tasks,
            "allocation_notes": notes,
        }
