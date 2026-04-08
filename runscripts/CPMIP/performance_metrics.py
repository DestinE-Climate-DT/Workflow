import argparse
import gzip
import json
import os
import time
from datetime import datetime
from typing import Any, Dict, Tuple

from utils_performance import (
    get_raw_info_from_sacct,  # Get SLURM data
    get_performance_metrics,  # Main calculation function
    build_metadata,  # Build metadata structure
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
        ifs_io_tasks: int = 0,
        nemo_io_tasks: int = 0,
        ifs_io_nodes: int = 0,
        nemo_io_nodes: int = 0,
        ifs_io_ppn: int = 0,
        nemo_io_ppn: int = 0,
        fesom_io_tasks: int = 0,
        fesom_io_nodes: int = 0,
        fesom_io_ppn: int = 0,
        threads: int = 1,
        processor_unit: str = "cpu",
    ):
        """
        Initialize the calculator with contextual and storage parameters.

        Args:
            output_dir: Base output directory.
            expid: Experiment id.
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
            ifs_io_tasks: Number of IFS I/O tasks (task-based allocation).
            nemo_io_tasks: Number of NEMO I/O tasks (task-based allocation).
            ifs_io_nodes: Number of IFS I/O nodes (node-based allocation).
            nemo_io_nodes: Number of NEMO I/O nodes (node-based allocation).
            ifs_io_ppn: IFS I/O processes per node (node-based allocation).
            nemo_io_ppn: NEMO I/O processes per node (node-based allocation).
            fesom_io_tasks: Number of FESOM I/O tasks (task-based allocation).
            fesom_io_nodes: Number of FESOM I/O nodes (node-based allocation).
            fesom_io_ppn: FESOM I/O processes per node (node-based allocation).
            threads: Number of OpenMP threads per task.
            processor_unit: Processor type ('cpu' or 'gpu').

        Returns:
            None
        """
        self.output_dir = output_dir
        self.expid = expid
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

        # New parameters for Sequential Coupling Cost and Data Output Cost
        self.tasks_per_node = tasks_per_node
        self.ifs_io_tasks = ifs_io_tasks
        self.nemo_io_tasks = nemo_io_tasks
        self.ifs_io_nodes = ifs_io_nodes
        self.nemo_io_nodes = nemo_io_nodes
        self.ifs_io_ppn = ifs_io_ppn
        self.nemo_io_ppn = nemo_io_ppn
        self.fesom_io_tasks = fesom_io_tasks
        self.fesom_io_nodes = fesom_io_nodes
        self.fesom_io_ppn = fesom_io_ppn
        self.threads = threads
        self.processor_unit = processor_unit

        # Containers
        self.monitor_metadata: Dict[
            str, Any
        ] = {}  # Will be populated from resource monitor if available
        self.raw_info: RawInfo = {}  # type: ignore  # Populated by get_raw_info_from_sacct()
        self.metadata: Metadata = {}  # type: ignore  # Populated by update_metadata()
        self.performance_metrics: PerformanceSummary = {}  # type: ignore  # Populated by get_performance_metrics()

    # --------------------------------------------------------------------------------------
    # Public methods (now delegate to utils functions)
    # --------------------------------------------------------------------------------------

    def get_raw_info(self, job_id: str) -> RawInfo:
        """
        Retrieve raw sacct information for the specified job.

        Delegates to get_raw_info_from_sacct() in utils_performance.py.

        Args:
            job_id: SLURM job id.

        Returns:
            RawInfo: Dictionary with raw fields including physical cores, TPC, timestamps, etc.
        """
        return get_raw_info_from_sacct(
            job_id=job_id,
            monitor_metadata=self.monitor_metadata,
            normalize_timestamp_func=convert_slurm_timestamp,
        )

    def update_raw_info(self) -> None:
        """
        Update 'self.raw_info' with the latest values from sacct.

        Args:
            None

        Returns:
            None
        """
        self.raw_info = self.get_raw_info(self.jobid)

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
        print(f"INFO: Using nodes from sacct: {nodes_from_sacct}")

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
            ifs_io_tasks=self.ifs_io_tasks,
            nemo_io_tasks=self.nemo_io_tasks,
            ifs_io_nodes=self.ifs_io_nodes,
            nemo_io_nodes=self.nemo_io_nodes,
            ifs_io_ppn=self.ifs_io_ppn,
            nemo_io_ppn=self.nemo_io_ppn,
            fesom_io_tasks=self.fesom_io_tasks,
            fesom_io_nodes=self.fesom_io_nodes,
            fesom_io_ppn=self.fesom_io_ppn,
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
        print(f"INFO: Saved performance metrics to {out_path}")

    def compute(self) -> None:
        """
        End-to-end routine:
            1) Sleep for sacct consolidation (slurm_freq).
            2) Query sacct and build raw info.
            3) Build metadata (timestamps).
            4) Compute metrics.
            5) Save to file compressed.

        Args:
            None

        Returns:
            None
        """
        print(f"INFO: Waiting {self.slurm_freq} seconds before querying sacct...")
        time.sleep(self.slurm_freq)

        self.update_raw_info()
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
    p.add_argument("--chunk", default="N/A", help="Chunk identifier")

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
        "--monitor_metadata",
        type=str,
        default=None,
        help="Path to resource monitor end.json.gz file",
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

    # Data Output Cost parameters
    p.add_argument(
        "--ifs_io_tasks",
        type=int,
        default=0,
        help="Number of IFS I/O tasks (task-based allocation)",
    )
    p.add_argument(
        "--nemo_io_tasks",
        type=int,
        default=0,
        help="Number of NEMO/FESOM I/O tasks (task-based allocation)",
    )
    p.add_argument(
        "--ifs_io_nodes",
        type=int,
        default=0,
        help="Number of IFS I/O nodes (node-based allocation)",
    )
    p.add_argument(
        "--nemo_io_nodes",
        type=int,
        default=0,
        help="Number of NEMO/FESOM I/O nodes (node-based allocation)",
    )
    p.add_argument(
        "--ifs_io_ppn",
        type=int,
        default=0,
        help="IFS I/O processes per node (node-based allocation)",
    )
    p.add_argument(
        "--nemo_io_ppn",
        type=int,
        default=0,
        help="NEMO I/O processes per node (node-based allocation)",
    )
    p.add_argument(
        "--fesom_io_tasks",
        type=int,
        default=0,
        help="Number of FESOM I/O tasks (task-based allocation)",
    )
    p.add_argument(
        "--fesom_io_nodes",
        type=int,
        default=0,
        help="Number of FESOM I/O nodes (node-based allocation)",
    )
    p.add_argument(
        "--fesom_io_ppn",
        type=int,
        default=0,
        help="FESOM I/O processes per node (node-based allocation)",
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


def _load_monitor_metadata(monitor_file: str) -> Dict[str, Any]:
    """
    Load and parse the monitor end.json.gz file.

    Args:
        monitor_file: Path to end.json.gz from resource monitor.

    Returns:
        dict: Parsed metadata including Job_Id, Threads_Per_Core_Count, etc.
    """
    if not monitor_file or not os.path.exists(monitor_file):
        print(f"WARNING: Monitor metadata file not found - {monitor_file}")
        return {}

    try:
        with gzip.open(monitor_file, "rt", encoding="utf-8") as f:
            data = json.load(f)
        print(f"INFO: Loaded monitor metadata from {monitor_file}")

        # Extract nested Job_Id from Job_Metadata
        job_metadata = data.get("Job_Metadata", {})
        job_id = job_metadata.get("Job_Id", "N/A")

        print(f"INFO: Monitor Job_Id is {job_id}")
        print(f"INFO: Monitor Timestamp is {data.get('Timestamp_ISO_Local', 'N/A')}")
        return data
    except Exception as e:
        print(f"ERROR: Failed to load monitor metadata - {e}")
        return {}


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

    # Load monitor metadata if provided
    monitor_data = {}
    if args.monitor_metadata:
        monitor_data = _load_monitor_metadata(args.monitor_metadata)

        # Verify Job_Id matches (nested in Job_Metadata)
        monitor_jobid = monitor_data.get("Job_Metadata", {}).get("Job_Id", "")
        if monitor_jobid and monitor_jobid != args.jobid:
            print(
                f"WARNING: Job ID mismatch - args: {args.jobid}, monitor: {monitor_jobid}"
            )

    calculator = PerformanceMetrics(
        output_dir=args.output_dir,
        expid=args.expid,
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
        ifs_io_tasks=args.ifs_io_tasks,
        nemo_io_tasks=args.nemo_io_tasks,
        ifs_io_nodes=args.ifs_io_nodes,
        nemo_io_nodes=args.nemo_io_nodes,
        ifs_io_ppn=args.ifs_io_ppn,
        nemo_io_ppn=args.nemo_io_ppn,
        fesom_io_tasks=args.fesom_io_tasks,
        fesom_io_nodes=args.fesom_io_nodes,
        fesom_io_ppn=args.fesom_io_ppn,
        threads=args.threads,
        processor_unit=args.processor_unit,
    )

    # Store monitor metadata for use in TPC detection
    if monitor_data:
        calculator.monitor_metadata = monitor_data

    calculator.compute()


if __name__ == "__main__":
    main()
