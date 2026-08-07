import argparse
import gzip
import json
import os
import time
from datetime import datetime
from typing import Any, Dict, Optional, Tuple

from utils_performance import (
    get_raw_info_from_sacct,  # Get SLURM data
    get_performance_metrics,  # Main calculation function
    build_metadata,  # Build metadata structure
    read_chunk_runtime_from_stat,  # Authoritative chunk wall time from AS log
    Metadata,  # TypedDict for metadata
    RawInfo,  # TypedDict for raw info
    PerformanceSummary,  # TypedDict for performance metrics
)
from monitor.utils.timestamps import convert_slurm_timestamp


# =============================================================================
# JSON and time helpers
# =============================================================================

# Fields that should maintain full precision (not rounded to 2 decimals)
FULL_PRECISION_FIELDS = {"Slope", "Intercept"}


def _round_floats_2dp(obj: Any, parent_key: str = "") -> Any:
    """
    Recursively round floats to 2 decimals; keep booleans unchanged.
    Certain fields maintain full precision (e.g., Slope, Intercept).

    Args:
        obj: Any JSON-serializable object.
        parent_key: The key of the parent dict (used to check if field needs full precision).

    Returns:
        Any: Object with most floats rounded to 2 decimals, except full precision fields.
    """
    if isinstance(obj, dict):
        return {k: _round_floats_2dp(v, k) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_round_floats_2dp(v, parent_key) for v in obj]
    if isinstance(obj, float) and not isinstance(obj, bool):
        # Don't round if this field requires full precision
        if parent_key in FULL_PRECISION_FIELDS:
            return obj
        return round(obj, 2)
    return obj


def _now_timestamp() -> Tuple[int, str]:
    """
    Return current epoch seconds and ISO-8601 local time string.

    Args:
        None

    Returns:
        (epoch, iso_local): Tuple with epoch (int) and ISO timestamp in local time (str).
    """
    dt = datetime.now()
    return int(dt.timestamp()), dt.isoformat()


def _save_json_gz(path: str, data: Dict[str, Any]) -> None:
    """
    Save dict to a GZIP-compressed JSON file with readable indentation.

    Args:
        path: Destination filename ('.json.gz' recommended).
        data: Dictionary to serialize.

    Returns:
        None
    """
    os.makedirs(os.path.dirname(path), exist_ok=True)
    safe = _round_floats_2dp(data)
    with gzip.open(path, "wt", encoding="utf-8") as f:
        json.dump(safe, f, ensure_ascii=False, indent=2)


# =============================================================================
# Main class
# =============================================================================


class PerformanceMetrics:
    """
    Compute performance metrics for a SLURM job using sacct outputs.

    Notes:
        - The computational logic and KPI definitions are preserved.
        - Additions include: safe shell wrapper, gzip+rounding+timestamps,
          centralized SACCT fields, and physical-core informational fields.
    """

    # --------------------------------------------------------------------------------------
    # Initialization
    # --------------------------------------------------------------------------------------

    def __init__(
        self,
        output_dir: str,
        expid: str,
        member: str,
        chunk: str,
        jobid: str,
        job_name: str,
        start_date_chunk: str,
        end_date_chunk: str,
        grid_atm: str,
        grid_oce: str,
        resolution_km: str,
        complexity: str,
        hpc: str,
        model: str,
        fdb_home: str,
        class_val: str,
        dataset: str,
        activity: str,
        experiment: str,
        generation: str,
        model_req: str,
        realization: str,
        expver: str,
        stream: str,
        slurm_freq: int,
        rundir_path: str = "N/A",
        tasks_per_node: int = 0,
        performance_resolution: str = "N/A",
        io_config: Optional[Dict[str, Any]] = None,
        threads: int = 1,
        processor_unit: str = "cpu",
    ):
        """
        Initialize the calculator with contextual and storage parameters.

        Args:
            output_dir: Base output directory.
            expid: Experiment id.
            member: Ensemble member identifier.
            chunk: Chunk identifier.
            jobid: SLURM job id (may include step suffix).
            job_name: SLURM job name.
            start_date_chunk: Start date (yyyymmdd).
            end_date_chunk: End date (yyyymmdd).
            grid_atm: Atmospheric grid.
            grid_oce: Ocean grid.
            resolution_km: Resolution (km) for memory bloat calculation.
            complexity: Complexity tag (JSON with model-specific keys).
            hpc: HPC site name.
            model: Model name.
            stream: Storage/FDB path pieces.
            slurm_freq: Seconds to wait before sacct (accounting consolidation).
            rundir_path: Path to the model run directory for I/O analysis.
            tasks_per_node: Number of tasks per node.
            performance_resolution: Resolution from PERFORMANCE_METRICS.RESOLUTION.
            io_config: I/O layout bundled per component, e.g.
                {"IFS": {"tasks","nodes","ppn"}, "NEMO": {...}, "FESOM": {...},
                "ICON": {"atm_compute_tasks","oce_tasks","yaco_tasks"}}. Threaded
                to the io_analyzer, which expands it (see ModelParser).
            threads: Number of OpenMP threads per task.
            processor_unit: Processor type ('cpu' or 'gpu').

        Returns:
            None
        """
        self.output_dir = output_dir
        self.expid = expid
        self.member = member
        self.chunk = chunk

        self.original_jobid = str(jobid)
        # Preserve legacy behavior: main job id before any ".step" suffix.
        self.jobid = self.original_jobid.split(".")[0]

        self.job_name = job_name
        self.start_date_chunk = start_date_chunk
        self.end_date_chunk = end_date_chunk
        self.grid_atm = grid_atm
        self.grid_oce = grid_oce
        self.resolution_km = resolution_km
        self.performance_resolution = performance_resolution

        try:
            self.complexity = json.loads(complexity)
        except Exception as e:
            print(
                f"WARNING: Failed to parse complexity JSON: {e}. Using default values."
            )
            self.complexity = {}

        self.hpc = hpc
        self.model = model

        self.fdb_home = fdb_home
        self.class_val = class_val
        self.dataset = dataset
        self.activity = activity
        self.experiment = experiment
        self.generation = generation
        self.model_req = model_req
        self.realization = realization
        self.expver = expver
        self.stream = stream

        self.slurm_freq = int(slurm_freq)
        self.rundir_path = rundir_path

        # Sequential Coupling Cost and Data Output Cost inputs.
        self.tasks_per_node = tasks_per_node
        self.threads = threads
        self.processor_unit = processor_unit
        # I/O layout bundled per component (IFS/NEMO/FESOM + ICON task counts),
        # threaded as-is to the io_analyzer, which expands it (see ModelParser).
        self.io_config = io_config or {}

        # Containers
        self.monitor_metadata: Dict[
            str, Any
        ] = {}  # Will be populated from resource monitor if available
        # Authoritative chunk wall time (start_epoch, end_epoch) from the
        # Autosubmit SIM STAT file — scopes sacct attribution to this chunk
        # (set in main() via read_chunk_runtime_from_stat).
        self.chunk_window: Optional[Tuple[int, int]] = None
        self.raw_info: RawInfo = {}  # type: ignore  # Populated by get_raw_info_from_sacct()
        self.metadata: Metadata = {}  # type: ignore  # Populated by update_metadata()
        self.performance_metrics: PerformanceSummary = {}  # type: ignore  # Populated by get_performance_metrics()

    # --------------------------------------------------------------------------------------
    # Public methods (now delegate to utils functions)
    # --------------------------------------------------------------------------------------

    def get_raw_info(self, job_id: str) -> RawInfo:
        """
        Retrieve raw sacct information for the specified job.

        Chunk attribution uses the SIM_STAT window (self.chunk_window) to scope
        sacct to this chunk's steps; without it, falls back to the wrapper-wide
        job row — see get_raw_info_from_sacct.

        Args:
            job_id: SLURM job id.

        Returns:
            RawInfo: Dictionary with raw fields including physical cores, TPC, timestamps, etc.
        """
        return get_raw_info_from_sacct(
            job_id=job_id,
            monitor_metadata=self.monitor_metadata,
            normalize_timestamp_func=convert_slurm_timestamp,
            chunk_window=self.chunk_window,
        )

    def update_raw_info(self) -> None:
        """
        Update 'self.raw_info' from sacct.

        Args:
            None

        Returns:
            None
        """
        self.raw_info = self.get_raw_info(self.jobid)

    def _previous_chunk_aggregated_cputime(self) -> Optional[float]:
        """
        Read the previous chunk's AGGREGATED CPUTimeRAW from its CPMIPS output.

        The previous chunk's output sits next to this one under the same
        wrapper-<jobid> dir, with the chunk number decremented in the
        ``<sdate>_<member>_<chunk>`` leaf. Keeping the same wrapper dir means a
        previous chunk that ran under a DIFFERENT allocation (different jobid)
        is naturally not found, so the caller uses the fallback. Returns None
        when there is no predecessor or its file/value is unavailable.
        """
        # output_dir = .../<jobname>-<jobid>/<sdate>_<member>_<chunk>/performance
        chunk_dir = os.path.dirname(self.output_dir)
        wrapper_dir = os.path.dirname(chunk_dir)
        leaf = os.path.basename(chunk_dir)
        try:
            head, chunk_s = leaf.rsplit("_", 1)
            prev_chunk = int(chunk_s) - 1
        except (ValueError, IndexError):
            return None
        if prev_chunk < 1:
            # Chunks are 1-indexed; the first chunk has no predecessor.
            return None
        prev_path = os.path.join(
            wrapper_dir,
            f"{head}_{prev_chunk}",
            "performance",
            "CPMIPS",
            "CPMIPS.json.gz",
        )
        data = _load_json_gz(prev_path)
        if not data:
            print(
                f"INFO: no previous chunk aggregate at {prev_path} (expected for "
                f"non-wrapper runs); using this chunk's aggregate directly"
            )
            return None
        val = data.get("Metadata", {}).get("CPUTimeRAW_Aggregated_Seconds")
        try:
            return float(val) if val is not None else None
        except (TypeError, ValueError):
            return None

    def _fallback_cputime_seconds(self) -> float:
        """
        Last-resort per-chunk CPUTimeRAW when sacct returned no usable
        CPUTimeRAW at all: AllocCPUS × SIM_STAT wall time = physical cores × TPC
        × RunTime, in logical core-seconds (so the downstream /TPC yields
        physical core-hours). The normal no-previous case uses the aggregated
        sacct value directly (see _resolve_actual_cpu_time); this only fires when
        even that is zero.
        """
        tpc = int(self.raw_info.get("Threads_Per_Core_Count", 1) or 1)
        if tpc < 1:
            tpc = 1
        physical = int(self.raw_info.get("Parallelization", 0) or 0)
        runtime = float(self.raw_info.get("RunTime", 0.0) or 0.0)
        return float(physical) * tpc * runtime

    def _resolve_actual_cpu_time(self) -> None:
        """
        Recover this chunk's CPUTimeRAW from the wrapper-cumulative aggregate.

        sacct's per-step CPUTimeRAW is inflated under a wrapper (each step's
        ElapsedRaw spans from the allocation start), so the aggregate grows
        chunk over chunk. The current chunk's actual CPUTimeRAW is therefore
        aggregate(this) − aggregate(previous). The aggregate stays in the output
        so the next chunk can take its own difference.
        """
        aggregated = float(
            self.raw_info.get("CPUTimeRAW_Aggregated_Seconds", 0.0) or 0.0
        )
        prev = self._previous_chunk_aggregated_cputime()
        if prev is not None and prev > 0 and aggregated > prev:
            # Wrapper, later chunk: the aggregate is cumulative from the
            # allocation start, so subtract the previous chunk's aggregate.
            actual = aggregated - prev
            source = f"diff (aggregate {aggregated:.0f} - previous {prev:.0f})"
        elif aggregated > 0:
            # No previous chunk in THIS allocation, so nothing inflated this
            # chunk's aggregate and it is already the per-chunk value. Normal
            # for non-wrapper runs (each chunk is its own SLURM job, with a
            # chunk-specific jobname/jobid) and for a wrapper's first chunk.
            actual = aggregated
            source = "aggregate (no prior chunk in this allocation)"
        else:
            # sacct returned no usable CPUTimeRAW: last-resort estimate.
            actual = self._fallback_cputime_seconds()
            source = "cores × SIM_STAT runtime (no sacct CPUTimeRAW)"
        self.raw_info["CPUTimeRAW_Seconds"] = actual
        print(
            f"INFO: CPUTimeRAW per-chunk={actual:.0f} via {source} "
            f"[aggregated={aggregated:.0f}, "
            f"previous={'N/A' if prev is None else format(prev, '.0f')}]"
        )

    def _resolve_runtime(self) -> None:
        """
        Set RunTime to the CPUTime-derived wall span, falling back to SIM_STAT.

        Since CPUTimeRAW = logical_cores × wall, the per-chunk CPUTimeRAW divided
        by the allocation's logical cores recovers the model-compute wall time.
        This becomes the primary RunTime (used by SYPD/QSYPD/Core_Hours). The
        SIM_STAT wall time is preserved as RunTime_Sim_Stat_Seconds — it is the
        fallback here and is what GPU hours use. Must run AFTER
        _resolve_actual_cpu_time (it reads the per-chunk CPUTimeRAW_Seconds).
        """
        sim_stat = float(self.raw_info.get("RunTime", 0.0) or 0.0)
        self.raw_info["RunTime_Sim_Stat_Seconds"] = sim_stat

        tpc = int(self.raw_info.get("Threads_Per_Core_Count", 1) or 1)
        if tpc < 1:
            tpc = 1
        logical_cores = int(self.raw_info.get("Parallelization", 0) or 0) * tpc
        cpu_time = float(self.raw_info.get("CPUTimeRAW_Seconds", 0.0) or 0.0)
        if logical_cores > 0 and cpu_time > 0:
            runtime = cpu_time / logical_cores
            source = "CPUTime"
        else:
            runtime = sim_stat
            source = "SIM_STAT (fallback)"
        self.raw_info["RunTime"] = runtime
        print(
            f"INFO: RunTime={runtime:.0f}s from {source} "
            f"(SIM_STAT wall={sim_stat:.0f}s, used for GPU hours)"
        )

    def update_metadata(self) -> None:
        """
        Build lightweight metadata with timestamps.

        Delegates to build_metadata() in utils_performance.py.

        Args:
            None

        Returns:
            None
        """
        self.metadata = build_metadata(
            raw_info=self.raw_info,
            expid=self.expid,
            member=self.member,
            chunk=self.chunk,
            start_date_chunk=self.start_date_chunk,
            end_date_chunk=self.end_date_chunk,
            grid_atm=self.grid_atm,
            grid_oce=self.grid_oce,
            hpc=self.hpc,
            model=self.model,
            monitor_metadata=self.monitor_metadata,
            timestamp_func=_now_timestamp,
        )

    # --------------------------------------------------------------------------------------
    # Orchestration
    # --------------------------------------------------------------------------------------

    def update_performance_metrics(self) -> None:
        """
        Recompute and update performance metrics based on current 'self.raw_info'.

        Calls get_performance_metrics() from utils_performance.py directly.

        Args:
            None

        Returns:
            None
        """
        # Always use nodes from raw_info (sacct) - the authoritative source
        nodes_from_sacct = self.raw_info.get("Nodes", 0)

        self.performance_metrics = get_performance_metrics(
            raw_info=self.raw_info,
            start_date_chunk=self.start_date_chunk,
            end_date_chunk=self.end_date_chunk,
            grid_atm=self.grid_atm,
            grid_oce=self.grid_oce,
            resolution_km=self.resolution_km,
            complexity=self.complexity,
            hpc=self.hpc,
            model=self.model,
            fdb_home=self.fdb_home,
            class_val=self.class_val,
            dataset=self.dataset,
            activity=self.activity,
            experiment=self.experiment,
            generation=self.generation,
            model_req=self.model_req,
            realization=self.realization,
            expver=self.expver,
            stream=self.stream,
            rundir_path=self.rundir_path,
            nodes=nodes_from_sacct,
            tasks_per_node=self.tasks_per_node,
            performance_resolution=self.performance_resolution,
            io_config=self.io_config,
            threads=self.threads,
            processor_unit=self.processor_unit,
        )

    def save_to_file(self) -> None:
        """
        Persist the combined payload to a compressed JSON with timestamps.

        Args:
            None

        Returns:
            None
        """
        payload = {
            "Metadata": self.metadata,
            "Performance_Metrics": self.performance_metrics,
        }
        out_path = os.path.join(self.output_dir, "CPMIPS", "CPMIPS.json.gz")
        _save_json_gz(out_path, payload)

    def compute(self) -> None:
        """
        End-to-end routine:
            1) Sleep for sacct consolidation if slurm_freq > 0 (legacy standalone
               flow only — embedded SIMs pass 0 since they no longer rely on
               sacct for the wrapper-contaminated fields).
            2) Query sacct and build raw info.
            3) Build metadata (timestamps).
            4) Compute metrics.
            5) Save to file compressed.

        Args:
            None

        Returns:
            None
        """
        if self.slurm_freq > 0:
            print(f"INFO: Waiting {self.slurm_freq} seconds before querying sacct...")
            time.sleep(self.slurm_freq)

        self.update_raw_info()
        self._resolve_actual_cpu_time()
        self._resolve_runtime()
        self.update_metadata()
        self.update_performance_metrics()
        self.save_to_file()


# =============================================================================
# CLI
# =============================================================================


def _build_arg_parser() -> argparse.ArgumentParser:
    """
    Build argument parser for CLI usage.

    Args:
        None

    Returns:
        argparse.ArgumentParser: Configured parser.
    """
    p = argparse.ArgumentParser(
        description="Compute performance metrics for a SLURM job"
    )

    # Essential arguments for computation
    p.add_argument("--jobid", required=True, help="SLURM job ID")
    p.add_argument("--output_dir", required=True, help="Output directory for metrics")

    # Job identification (with defaults)
    p.add_argument("--job_name", dest="job_name", default="N/A", help="SLURM job name")
    p.add_argument("--expid", default="N/A", help="Experiment ID")
    p.add_argument("--member", default="N/A", help="Ensemble member identifier")
    p.add_argument("--chunk", default="N/A", help="Chunk identifier")

    # Authoritative chunk wall time: located via the Autosubmit SIM STAT file at
    # ${HPCROOTDIR}/LOG_${EXPID}/${EXPID}_${SDATE}_${MEMBER}_${CHUNK}_SIM_STAT_*
    p.add_argument(
        "--hpcrootdir",
        default="",
        help="Experiment HPCROOTDIR (to locate LOG_<expid>/<...>_SIM_STAT_* )",
    )
    p.add_argument(
        "--sdate",
        default="",
        help="Simulation start date (yyyymmdd) — the SDATE in the SIM STAT file "
        "name, not the chunk's own start date",
    )

    # Date range for simulated years calculation (optional)
    p.add_argument(
        "--start_date_chunk",
        dest="start_date_chunk",
        default="N/A",
        help="Start date (yyyymmdd)",
    )
    p.add_argument(
        "--end_date_chunk",
        dest="end_date_chunk",
        default="N/A",
        help="End date (yyyymmdd)",
    )

    # Grid and resolution information (optional)
    p.add_argument("--grid_atm", default="N/A", help="Atmospheric grid")
    p.add_argument("--grid_oce", default="N/A", help="Ocean grid")
    p.add_argument("--resolution_km", default="N/A", help="Resolution in km")

    # Model configuration (optional)
    p.add_argument(
        "--complexity",
        default='{"OCEAN": "N/A", "ATM": "N/A", "LAND": "N/A"}',
        help="Model complexity (JSON string)",
    )
    p.add_argument("--hpc", default="N/A", help="HPC site name")
    p.add_argument("--model", default="N/A", help="Model name")

    # Storage / FDB parameters (optional - only needed for storage metrics)
    p.add_argument("--fdb_home", default="N/A", help="FDB home directory")
    p.add_argument("--class_val", default="N/A", help="FDB class value")
    p.add_argument("--dataset", default="N/A", help="FDB dataset")
    p.add_argument("--activity", default="N/A", help="FDB activity")
    p.add_argument("--experiment", default="N/A", help="FDB experiment")
    p.add_argument("--generation", default="N/A", help="FDB generation")
    p.add_argument("--model_req", default="N/A", help="FDB model requirement")
    p.add_argument("--realization", default="N/A", help="FDB realization")
    p.add_argument("--expver", default="N/A", help="FDB experiment version")
    p.add_argument("--stream", default="N/A", help="FDB stream")

    # Optional parameters with defaults
    p.add_argument(
        "--slurm_freq",
        type=int,
        default=30,
        help="Seconds to wait before querying sacct (default: 30)",
    )
    p.add_argument(
        "--monitor_dir",
        type=str,
        default=None,
        help="Resource monitor output directory containing metadata/metadata.json.gz",
    )
    p.add_argument(
        "--rundir_path",
        type=str,
        default="N/A",
        help="Path to model run directory for I/O analysis",
    )

    # Sequential Coupling Cost and Data Output Cost parameters
    p.add_argument(
        "--tasks_per_node",
        type=int,
        default=0,
        help="Number of tasks per node",
    )
    p.add_argument(
        "--performance_resolution",
        type=str,
        default="N/A",
        help="Grid points resolution from PERFORMANCE_METRICS.RESOLUTION",
    )

    # Data Output Cost: I/O layout, bundled into a single JSON arg (mirrors
    # --complexity). _apply_io_config expands it onto the per-component values.
    p.add_argument(
        "--io_config",
        type=str,
        default="",
        help=(
            "I/O layout as a JSON string bundling per-component tasks/nodes/ppn, "
            'e.g. \'{"IFS":{"tasks":0,"nodes":4,"ppn":8},'
            '"FESOM":{"tasks":0,"nodes":2,"ppn":8}}\'. For ICON the entry carries '
            'explicit task counts: {"ICON":{"atm_compute_tasks":N,"oce_tasks":M,'
            '"yaco_tasks":K}}.'
        ),
    )
    p.add_argument(
        "--threads",
        type=int,
        default=1,
        help="Number of OpenMP threads per task",
    )
    p.add_argument(
        "--processor_unit",
        type=str,
        default="cpu",
        choices=["cpu", "gpu"],
        help="Processor type for binary size selection (default: cpu)",
    )

    return p


def _parse_io_config(io_config_json: str) -> Dict[str, Any]:
    """
    Parse the --io_config JSON string into a per-component dict.

    Mirrors --complexity: one JSON string collapses the whole I/O layout. Shape:
    {"IFS"|"NEMO"|"FESOM": {"tasks","nodes","ppn"},
     "ICON": {"atm_compute_tasks","oce_tasks","yaco_tasks"}}. The dict is
    threaded as-is to the io_analyzer, which coerces/expands the values
    (see ModelParser); this only handles the JSON decoding.

    Args:
        io_config_json: JSON string from --io_config (may be empty).

    Returns:
        The parsed dict, or {} when the string is empty or unparseable.
    """
    if not io_config_json or io_config_json in ("N/A", "{}"):
        return {}
    try:
        cfg = json.loads(io_config_json)
    except Exception as e:
        print(f"WARNING: Failed to parse --io_config JSON: {e}. Ignoring I/O layout.")
        return {}
    return cfg if isinstance(cfg, dict) else {}


def _load_json_gz(path: str) -> Dict[str, Any]:
    """Load a gzipped JSON file; return {} when missing/unreadable."""
    if not path or not os.path.exists(path):
        return {}
    try:
        with gzip.open(path, "rt", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"ERROR: Failed to load {path} - {e}")
        return {}


def _load_monitor_outputs(monitor_dir: str) -> Dict[str, Any]:
    """
    Load the scontrol metadata (TPC / Nodes / NTasks) the monitor wrote.

    Returns:
        monitor_data mirroring the Job_Metadata structure, or {} when the file
        is missing.
    """
    if not monitor_dir or not os.path.isdir(monitor_dir):
        print(f"WARNING: monitor_dir not found - {monitor_dir}")
        return {}

    metadata_path = os.path.join(monitor_dir, "metadata", "metadata.json.gz")
    monitor_data = _load_json_gz(metadata_path)
    if monitor_data:
        job_id = monitor_data.get("Job_Metadata", {}).get("Job_Id", "N/A")
        print(f"INFO: Loaded monitor metadata from {metadata_path} (Job_Id={job_id})")
    else:
        print(f"WARNING: monitor metadata missing - {metadata_path}")

    return monitor_data


def main() -> None:
    """
    CLI entry point.

    Args:
        None

    Returns:
        None
    """
    parser = _build_arg_parser()
    args = parser.parse_args()

    # Parse the bundled I/O layout (IFS/NEMO/FESOM + ICON). Threaded as-is to
    # the io_analyzer, which expands it.
    io_config = _parse_io_config(args.io_config)

    # Load monitor outputs (scontrol metadata)
    monitor_data: Dict[str, Any] = {}
    if args.monitor_dir:
        monitor_data = _load_monitor_outputs(args.monitor_dir)

        # Verify Job_Id matches (nested in Job_Metadata)
        monitor_jobid = monitor_data.get("Job_Metadata", {}).get("Job_Id", "")
        if monitor_jobid and monitor_jobid != args.jobid:
            print(
                f"WARNING: Job ID mismatch - args: {args.jobid}, monitor: {monitor_jobid}"
            )

    calculator = PerformanceMetrics(
        output_dir=args.output_dir,
        expid=args.expid,
        member=args.member,
        chunk=args.chunk,
        jobid=args.jobid,
        job_name=args.job_name,
        start_date_chunk=args.start_date_chunk,
        end_date_chunk=args.end_date_chunk,
        grid_atm=args.grid_atm,
        grid_oce=args.grid_oce,
        resolution_km=args.resolution_km,
        complexity=args.complexity,
        hpc=args.hpc,
        model=args.model,
        fdb_home=args.fdb_home,
        class_val=args.class_val,
        dataset=args.dataset,
        activity=args.activity,
        experiment=args.experiment,
        generation=args.generation,
        model_req=args.model_req,
        realization=args.realization,
        expver=args.expver,
        stream=args.stream,
        slurm_freq=args.slurm_freq,
        rundir_path=args.rundir_path,
        tasks_per_node=args.tasks_per_node,
        performance_resolution=args.performance_resolution,
        io_config=io_config,
        threads=args.threads,
        processor_unit=args.processor_unit,
    )

    # Monitor metadata supplies TPC / Nodes / NTasks (scontrol view of the
    # allocation).
    if monitor_data:
        calculator.monitor_metadata = monitor_data

    # Authoritative chunk wall time from the Autosubmit SIM STAT file. It scopes
    # sacct attribution to this chunk (chunk-scoped under a wrapper); without it
    # the wrapper-wide job row is used.
    chunk_window = None
    if args.hpcrootdir and args.sdate:
        chunk_window = read_chunk_runtime_from_stat(
            args.hpcrootdir, args.expid, args.sdate, args.member, args.chunk
        )
    calculator.chunk_window = chunk_window

    calculator.compute()


if __name__ == "__main__":
    main()
