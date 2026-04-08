import datetime
import os
import re
import subprocess
import yaml
from typing import Any, Callable, Dict, List, Optional, TypedDict

# =============================================================================
# Typed structures
# =============================================================================


class RawInfo(TypedDict):
    """
    Raw information gathered from SLURM accounting for a single job.

    IMPORTANT: All timestamp fields (StartTime, EndTime, SubmitTime) are normalized
    to ISO-8601 format in local time (e.g., '2025-10-30T14:30:59').
    SLURM reports timestamps in local time, and they are kept as-is.

    Args:
        None

    Returns:
        JobID: Job identifier (string).
        JobName: Job name string.
        Parallelization: Number of physical cores used (integer).
        Threads_Per_Core_Count: Detected threads per core (best-effort).
        Nodes: Allocated nodes (integer).
        NTasks: Number of tasks from SLURM (integer).
        Energy_Joules: Consumed energy in Joules (float).
        CPUTimeRAW_Seconds: CPUTimeRAW from sacct in seconds (logical cores × elapsed) (float).
        RunTime: Elapsed time in seconds (float).
        StartTime: Job start timestamp in local ISO-8601 format (e.g., '2025-10-30T14:30:59').
        EndTime: Job end timestamp in local ISO-8601 format (e.g., '2025-10-30T14:41:44').
        SubmitTime: Job submission timestamp in local ISO-8601 format (e.g., '2025-10-30T14:30:51').
        MaxRSS_KB: Max resident set size in KB (float).
        AveRSS_KB: Average resident set size in KB (float).
    """

    JobID: str
    JobName: str
    Parallelization: int
    Threads_Per_Core_Count: int
    Nodes: int
    NTasks: int
    Energy_Joules: float
    CPUTimeRAW_Seconds: float
    RunTime: float
    StartTime: str
    EndTime: str
    SubmitTime: str
    MaxRSS_KB: float
    AveRSS_KB: float


class CpuMetrics(TypedDict):
    """
    CPU performance metrics using physical cores (normalized by TPC).

    Returns:
        Core_Hours: Total physical core hours consumed.
        Core_Hours_Per_Simulated_Year: Core hours normalized by simulated years (CHSY).
    """

    Core_Hours: float
    Core_Hours_Per_Simulated_Year: float


class MemoryMetrics(TypedDict):
    """
    Memory efficiency metrics with detailed breakdown.

    Returns:
        Memory_Bloat: Ratio of actual memory usage to theoretical restart size.
        RSS_Bytes: Total Maximum Resident Set Size in bytes.
        Binary_Size_Bytes: Total binary footprint (binary size × MPI tasks) in bytes.
        Restart_Size_Bytes: Expected restart file size in bytes.
        MPI_Tasks: Number of MPI compute tasks used in calculation.
        Binary_Size_Per_Task_GB: Size of binary per task in GB.
        Restart_Size_GB: Expected restart size in GB.
        Model: Normalized model name.
        Resolution: Resolution string.
        Notes: Optional list of issues encountered during calculation.
    """

    Memory_Bloat: float
    RSS_Bytes: int
    Binary_Size_Bytes: int
    Restart_Size_Bytes: int
    MPI_Tasks: int
    Binary_Size_Per_Task_GB: float
    Restart_Size_GB: float
    Model: str
    Resolution: str
    Notes: List[str]


class StorageMetrics(TypedDict):
    """
    Storage and data intensity metrics (all in bytes, base 1024).

    Returns:
        Total_Output_Bytes: Total FDB output data size in bytes.
        Data_Intensity_Bytes_Per_Core_Hour: Data output per core hour (bytes/core-hour).
        Notes: Optional list of issues encountered during calculation.
    """

    Total_Output_Bytes: int
    Data_Intensity_Bytes_Per_Core_Hour: float
    Notes: List[str]


class HPCParameters(TypedDict):
    """HPC-specific energy parameters."""

    Conversion_Factor_gCO2_per_kWh: float
    PUE: float


class EnergyMetrics(TypedDict):
    """
    Energy consumption and carbon footprint metrics.

    Returns:
        Energy_Joules: Total energy consumed in Joules.
        Joules_Per_Simulated_Year: Energy consumption per simulated year.
        Carbon_Footprint_gCO2: Carbon footprint in grams of CO2.
        HPC_Parameters: Dict with Conversion_Factor_gCO2_per_kWh and PUE.
        Notes: Optional list of issues encountered during calculation.
    """

    Energy_Joules: float
    Joules_Per_Simulated_Year: float
    Carbon_Footprint_gCO2: float
    HPC_Parameters: HPCParameters
    Notes: List[str]


class ResourceAllocation(TypedDict):
    """Resource allocation metrics with MPI tasks and physical cores."""

    MPI_Tasks: int
    Physical_Cores: int


class TimeMetric(TypedDict):
    """Time metric with seconds and percentage."""

    Time_Seconds: float
    Percentage: float


class TimeAllocation(TypedDict):
    """Time allocation metrics in seconds."""

    Compute: float
    IO: float
    Total: float


class PercentageMetrics(TypedDict):
    """Percentage metrics (0-100)."""

    Compute_Time: float  # Porcentaje del tiempo total dedicado a compute
    IO_Time: float  # Porcentaje del tiempo total dedicado a I/O
    Compute_Resources: float  # Porcentaje de recursos dedicados a compute
    IO_Resources: float  # Porcentaje de recursos dedicados a I/O


class IOEfficiencyMetrics(TypedDict):
    """I/O efficiency and cost metrics."""

    Serialization_Factor: float  # Factor de penalización por I/O serial (>= 1.0)
    Wasted_Node_Hours: float  # Node-hours desperdiciadas por I/O serial


class ComponentBreakdown(TypedDict):
    """Per-component breakdown with compute, I/O, total times and resources."""

    Compute: TimeMetric
    IO: TimeMetric
    Total: float
    Resources: ResourceAllocation


class DataOutputCostMetrics(TypedDict):
    """
    Data Output Cost performance metrics from model output analysis.

    Structured hierarchically to avoid redundancy:
    - Resources: Organized by category (Compute, IO, Total) with MPI tasks and physical cores
    - Times: Time measurements (Compute, IO, Total) in seconds
    - Percentages: Relative metrics (compute/io times and resources) from 0-100
    - IO_Efficiency: Efficiency metrics (Serialization_Factor, Wasted_Node_Hours)
    - Components: Per-component breakdown (e.g., IFS, NEMO) with detailed metrics
    - Notes: Additional notes about the analysis
    """

    Resources: Dict[str, ResourceAllocation]  # Keys: 'Compute', 'IO', 'Total'
    Times: TimeAllocation
    Percentages: PercentageMetrics
    IO_Efficiency: IOEfficiencyMetrics
    Components: Dict[str, ComponentBreakdown]  # Keys: 'IFS', 'NEMO', 'FESOM', etc.
    Notes: List[str]


class LinearModelCoefficients(TypedDict):
    """Linear model coefficients for sequential coupling cost."""

    Slope: float
    Intercept: float


class SequentialCouplingCostMetrics(TypedDict):
    """
    Sequential Coupling Cost metrics for coupled climate models.

    The sequential coupling cost represents the overhead introduced by the sequential
    execution pattern in coupled models, calculated using a linear model based on
    the number of compute nodes.

    Returns:
        Sequential_Coupling_Cost_Percentage: Sequential coupling overhead as percentage (0-100).
        Nodes: Number of nodes used in the calculation.
        Tasks_Per_Node: Number of tasks per node used in the calculation.
        Model: Model name used for configuration lookup.
        HPC: HPC site name used for configuration lookup.
        Linear_Model_Coefficients: Dict with Slope and Intercept (exact values without rounding).
        Notes: Optional list of issues encountered during calculation.
    """

    Sequential_Coupling_Cost_Percentage: float
    Nodes: int
    Tasks_Per_Node: int
    Model: str
    HPC: str
    Linear_Model_Coefficients: LinearModelCoefficients
    Notes: List[str]


class PerformanceSummary(TypedDict):
    """
    High-level performance metrics following Variable_Name_Unit convention.

    Returns:
        Resolution_Km: Resolution string (km) for memory bloat.
        Performance_Resolution: Grid points resolution from PERFORMANCE_METRICS.RESOLUTION.
        Complexity: Model complexity dict with model-specific keys.
        Simulated_Years: Simulated years for the chunk.
        Simulated_Years_Per_Day: Simulated years per day (runtime only).
        Queue_Simulated_Years_Per_Day: Simulated years per day including queue time.
        Cpu: CPU-related metrics (physical cores, TPC normalized).
        Energy: Energy consumption and carbon footprint metrics.
        Memory: Memory efficiency metrics.
        Storage: Storage and data intensity metrics.
        Data_Output_Cost: Data output cost metrics.
        Sequential_Coupling_Cost: Sequential coupling cost metrics.
        Grid_Points: Total number of atmospheric grid points.
    """

    Resolution_Km: str
    Performance_Resolution: str
    Complexity: Dict[str, str]
    Simulated_Years: float
    Simulated_Years_Per_Day: Any
    Queue_Simulated_Years_Per_Day: Any
    Cpu: CpuMetrics
    Energy: EnergyMetrics
    Memory: MemoryMetrics
    Storage: StorageMetrics
    Data_Output_Cost: DataOutputCostMetrics
    Sequential_Coupling_Cost: SequentialCouplingCostMetrics
    Grid_Points: int


class JobMetadata(TypedDict):
    """Job identification metadata."""

    JobID: Any
    JobName: Any


class ExperimentMetadata(TypedDict):
    """Experiment configuration metadata."""

    ExpId: str
    Chunk: str
    Start_Date: str
    End_Date: str


class EnvironmentMetadata(TypedDict):
    """Environment metadata."""

    HPC: str
    Model: str


class GridsMetadata(TypedDict):
    """Grid configuration metadata."""

    Atm: str
    Oce: str


class AllocationMetadata(TypedDict):
    """Resource allocation metadata."""

    Parallelization: int
    Threads_Per_Core_Count: int
    Nodes: int


class TimestampsMetadata(TypedDict):
    """Job timestamps metadata."""

    StartTime: str
    EndTime: str
    SubmitTime: str


class Metadata(TypedDict):
    """Complete metadata structure."""

    Timestamp_Epoch: int
    Timestamp_ISO_Local: str
    Job: JobMetadata
    Experiment: ExperimentMetadata
    Environment: EnvironmentMetadata
    Grids: GridsMetadata
    Allocation: AllocationMetadata
    Timestamps: TimestampsMetadata
    Energy_Joules: float
    CPUTimeRAW_Seconds: float
    RunTime_Seconds: float
    Queue_Time_Seconds: float
    MaxRSS_KB: float
    AveRSS_KB: float
    Notes: List[str]


# =============================================================================
# HPC Energy Configuration
# =============================================================================

# HPC-specific energy parameters
HPC_ENERGY_CONFIG = {
    "MARENOSTRUM5": {
        "conversion_factor_gCO2_per_kWh": 283.0,  # Energy mix conversion factor (gCO2/kWh)
        "pue": 1.2,  # Power Usage Effectiveness
    },
    "LUMI": {
        "conversion_factor_gCO2_per_kWh": 32.0,  # Energy mix conversion factor (gCO2/kWh)
        "pue": 1.04,  # Power Usage Effectiveness
    },
}

# =============================================================================
# Sequential Coupling Cost Configuration
# =============================================================================

# Sequential Coupling Cost parameters by model, HPC, and tasks per node
# Cost is calculated as: cost_percentage = (slope * nodes + intercept) * 100
SEQUENTIAL_COUPLING_COST_CONFIG = {
    "IFS-NEMO": {
        "MARENOSTRUM5": {
            8: {  # tasks per node
                "slope": 0.00027878602878260444,
                "intercept": 0.0012039618766926385,
            },
            # Add more task configurations as needed
            # 14: {"slope": X, "intercept": Y},
        },
        # Add more HPCs as needed
        # "LUMI": {8: {...}, 16: {...}},
    },
    # Add more models as needed
    # "IFS-FESOM": {...},
    # "ICON": {...},
}

# =============================================================================
# Small helpers (logic preserved; added docstrings)
# =============================================================================


def _memory_to_kilobytes(value: Optional[str]) -> Optional[float]:
    """
    Convert SLURM memory strings (e.g., '12G', '512M', '1024K') to kilobytes.

    Args:
        value: Memory string.

    Returns:
        float|None: Memory in kilobytes or None if not parseable.
    """
    if not value:
        return None

    value = str(value).strip()
    if not value or value in {"N/A", "None"}:
        return None

    try:
        if value.endswith("K"):
            return float(value[:-1])
        if value.endswith("M"):
            return float(value[:-1]) * 1024.0
        if value.endswith("G"):
            return float(value[:-1]) * 1024.0 * 1024.0
        if value.endswith("T"):
            return float(value[:-1]) * 1024.0 * 1024.0 * 1024.0
        # Plain number – assume KB
        return float(value)
    except Exception:
        return None


# =============================================================================
# sacct parsing
# =============================================================================


def parse_sacct_output(output: str, fields: List[str]) -> Dict[str, Any]:
    """
    Parse 'sacct -P' output.

    Args:
        output: Raw stdout from sacct.
        fields: Field names used in -o.

    Returns:
        dict: Best-effort record for the main job (prefers JobID without suffix).
    """
    lines = [ln for ln in output.strip().splitlines() if ln.strip()]
    if not lines:
        return {}

    header = [h.strip() for h in lines[0].split("|")]
    rows = [r.split("|") for r in lines[1:] if "|" in r]

    records: List[Dict[str, Any]] = []
    for r in rows:
        rec = {
            header[i]: (r[i].strip() if i < len(header) else "")
            for i in range(len(header))
        }
        rec["__raw_line"] = "|".join(r)
        records.append(rec)

    if not records:
        return {}

    def _is_main(jobid: Optional[str]) -> bool:
        return bool(jobid) and "." not in str(jobid)

    main = next((x for x in records if _is_main(x.get("JobID"))), None)
    if not main:

        def _cpu_sec(rec: Dict[str, Any]) -> int:
            try:
                return int(rec.get("CPUTimeRAW", 0) or 0)
            except Exception:
                return 0

        main = max(records, key=_cpu_sec)

    out: Dict[str, Any] = {}
    for f in fields:
        out[f] = main.get(f, "N/A")

    # If MaxRSS is missing or empty, try to get it from other records (e.g., .batch or steps)
    if not out.get("MaxRSS") or out.get("MaxRSS") in (None, "N/A", ""):
        memory_candidates = [
            rec
            for rec in records
            if rec.get("MaxRSS") and rec.get("MaxRSS") not in (None, "N/A", "")
        ]
        if memory_candidates:
            best_record = max(
                memory_candidates,
                key=lambda rec: _memory_to_kilobytes(rec.get("MaxRSS")) or -1,
            )
            out["MaxRSS"] = best_record.get("MaxRSS")
            if not out.get("AveRSS") or out.get("AveRSS") in (None, "N/A", ""):
                out["AveRSS"] = best_record.get("AveRSS")
            print(
                f"INFO: Filled MaxRSS/AveRSS from step "
                f"{best_record.get('JobID')} with MaxRSS={out['MaxRSS']}"
            )

    return out


# =============================================================================
# SACCT field configuration
# =============================================================================

# Centralized sacct fields
SACCT_FIELDS: List[str] = [
    # Identity
    "JobID",
    "JobName",
    # Allocation / time
    "AllocCPUS",
    "AllocNodes",
    "NTasks",
    "CPUTimeRAW",
    "ElapsedRaw",
    "Submit",
    "Start",
    "End",
    # Memory
    "MaxRSS",
    "AveRSS",
    # Energy (if accounting is enabled)
    "ConsumedEnergyRaw",
]


def run_sacct_for_job(job_id: str, timeout: int = 30) -> tuple[int, str, str]:
    """
    Invoke 'sacct' for the given JobID with the centralized fields.

    Args:
        job_id: SLURM job id (main job).
        timeout: Command timeout in seconds.

    Returns:
        (rc, stdout, stderr): Return code and outputs.
    """
    fmt = ",".join(SACCT_FIELDS)
    cmd = ["sacct", "-j", job_id, "-o", fmt, "-P"]

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return proc.returncode, proc.stdout, proc.stderr
    except subprocess.TimeoutExpired:
        return 124, "", f"TIMEOUT after {timeout}s"
    except Exception as e:
        return 1, "", f"ERROR: {e}"


def extract_memory_kb(mem_str: Any) -> float:
    """
    Extract KB value from memory string (e.g., '28911798K' -> 28911798.0).

    Args:
        mem_str: Memory string from SLURM.

    Returns:
        float: Memory in KB, or 0.0 if cannot parse.
    """
    if not mem_str or mem_str == "N/A":
        return 0.0
    mem_str = str(mem_str).strip()
    if mem_str.endswith("K"):
        try:
            return float(mem_str[:-1])
        except (ValueError, TypeError):
            return 0.0
    elif mem_str.endswith("M"):
        try:
            return float(mem_str[:-1]) * 1024.0
        except (ValueError, TypeError):
            return 0.0
    elif mem_str.endswith("G"):
        try:
            return float(mem_str[:-1]) * 1024.0 * 1024.0
        except (ValueError, TypeError):
            return 0.0
    else:
        try:
            return float(mem_str)
        except (ValueError, TypeError):
            return 0.0


def get_raw_info_from_sacct(
    job_id: str,
    monitor_metadata: Optional[Dict[str, Any]] = None,
    normalize_timestamp_func: Optional[Callable[[str], str]] = None,
) -> RawInfo:
    """
    Retrieve raw sacct information for the specified job.

    This function encapsulates all logic for querying SLURM accounting,
    detecting threads-per-core, normalizing timestamps, and extracting memory values.

    Args:
        job_id: SLURM job id.
        monitor_metadata: Optional monitor metadata dict containing Job_Metadata.
        normalize_timestamp_func: Optional function to normalize timestamps (e.g., normalize_slurm_timestamp).

    Returns:
        dict: Dictionary with raw fields including physical cores, TPC, timestamps, etc.
    """
    # Default empty dict with proper types (use 0/0.0 instead of "N/A" for numeric fields)
    default_raw: RawInfo = {
        "JobID": "N/A",
        "JobName": "N/A",
        "Parallelization": 0,
        "Threads_Per_Core_Count": 1,
        "Nodes": 0,
        "NTasks": 0,
        "Energy_Joules": 0.0,
        "CPUTimeRAW_Seconds": 0.0,
        "RunTime": 0.0,
        "StartTime": "N/A",
        "EndTime": "N/A",
        "SubmitTime": "N/A",
        "MaxRSS_KB": 0.0,
        "AveRSS_KB": 0.0,
    }

    # Query sacct
    rc, out, err = run_sacct_for_job(job_id)
    if rc != 0 or not out.strip():
        print(
            f"WARNING: sacct failed/empty for job {job_id} - rc={rc}, err={err.strip()}"
        )
        return default_raw

    record = parse_sacct_output(out, SACCT_FIELDS) or {}

    # Detect threads-per-core
    tpc = 1
    if monitor_metadata:
        # Get Threads_Per_Core_Count from Job_Metadata
        job_metadata = monitor_metadata.get("Job_Metadata", {})
        tpc_value = job_metadata.get("Threads_Per_Core_Count")

        if tpc_value and tpc_value > 0:
            tpc = int(tpc_value)
            print(f"INFO: Using Threads_Per_Core_Count from monitor metadata - {tpc}")

    # Calculate physical cores (AllocCPUS / TPC)
    alloc_cpus = record.get("AllocCPUS")
    try:
        alloc_cpus_i = int(str(alloc_cpus)) if alloc_cpus not in (None, "N/A") else 0
    except Exception:
        alloc_cpus_i = 0

    physical_parallelization = 0
    if alloc_cpus_i > 0:
        physical_parallelization = int(alloc_cpus_i / tpc)

    # Extract and convert nodes to int
    nodes_value = record.get("AllocNodes", 0)
    try:
        nodes_int = int(str(nodes_value)) if nodes_value not in (None, "N/A", "") else 0
    except Exception:
        nodes_int = 0

    # Extract and convert NTasks to int
    # Prioritize scontrol data (from monitor_metadata) over sacct
    ntasks_int = 0
    if monitor_metadata:
        job_metadata = monitor_metadata.get("Job_Metadata", {})
        resource_info = job_metadata.get("Resource_Info", {})
        ntasks_scontrol = resource_info.get("Num_Tasks_Count", 0)
        try:
            ntasks_int = int(ntasks_scontrol) if ntasks_scontrol else 0
            if ntasks_int > 0:
                print(
                    f"INFO: Using NTasks from scontrol (monitor metadata): {ntasks_int}"
                )
        except Exception:
            ntasks_int = 0

    # Fallback to sacct if not available from monitor
    if ntasks_int == 0:
        ntasks_value = record.get("NTasks", 0)
        try:
            ntasks_int = (
                int(str(ntasks_value)) if ntasks_value not in (None, "N/A", "") else 0
            )
            if ntasks_int > 0:
                print(f"INFO: Using NTasks from sacct: {ntasks_int}")
        except Exception:
            ntasks_int = 0

    # Extract and convert energy to float
    energy_value = record.get("ConsumedEnergyRaw", 0.0)
    try:
        energy_float = (
            float(str(energy_value)) if energy_value not in (None, "N/A", "") else 0.0
        )
    except Exception:
        energy_float = 0.0

    # Extract and convert CPUTimeRAW to float
    cputime_value = record.get("CPUTimeRAW", 0.0)
    try:
        cputime_float = (
            float(str(cputime_value)) if cputime_value not in (None, "N/A", "") else 0.0
        )
    except Exception:
        cputime_float = 0.0

    # Extract and convert ElapsedRaw to float
    elapsed_value = record.get("ElapsedRaw", 0.0)
    try:
        elapsed_float = (
            float(str(elapsed_value)) if elapsed_value not in (None, "N/A", "") else 0.0
        )
    except Exception:
        elapsed_float = 0.0

    # Normalize SLURM timestamps
    if normalize_timestamp_func:
        start_time = normalize_timestamp_func(record.get("Start", "N/A"))
        end_time = normalize_timestamp_func(record.get("End", "N/A"))
        submit_time = normalize_timestamp_func(record.get("Submit", "N/A"))
    else:
        # No normalization function provided, use as-is
        start_time = record.get("Start", "N/A")
        end_time = record.get("End", "N/A")
        submit_time = record.get("Submit", "N/A")

    # Extract and convert memory values to float
    maxrss_value = extract_memory_kb(record.get("MaxRSS", "N/A"))
    averss_value = extract_memory_kb(record.get("AveRSS", "N/A"))

    # Ensure memory values are float (extract_memory_kb can return "N/A")
    try:
        maxrss_float = (
            float(maxrss_value) if maxrss_value not in (None, "N/A", "") else 0.0
        )
    except (ValueError, TypeError):
        maxrss_float = 0.0

    try:
        averss_float = (
            float(averss_value) if averss_value not in (None, "N/A", "") else 0.0
        )
    except (ValueError, TypeError):
        averss_float = 0.0

    # Construct dict with proper types
    raw: RawInfo = {
        "JobID": str(record.get("JobID", "N/A")),
        "JobName": str(record.get("JobName", "N/A")),
        "Parallelization": physical_parallelization,
        "Threads_Per_Core_Count": tpc,
        "Nodes": nodes_int,
        "NTasks": ntasks_int,
        "Energy_Joules": energy_float,
        "CPUTimeRAW_Seconds": cputime_float,
        "RunTime": elapsed_float,
        "StartTime": start_time,
        "EndTime": end_time,
        "SubmitTime": submit_time,
        "MaxRSS_KB": maxrss_float,
        "AveRSS_KB": averss_float,
    }
    return raw


# =============================================================================
# Domain computations
# =============================================================================


def calculate_simulated_years(start_date_chunk: str, end_date_chunk: str) -> float:
    """
    Calculate simulated years between two dates (inclusive).

    Args:
        start_date_chunk: Start date 'yyyymmdd'.
        end_date_chunk: End date 'yyyymmdd'.

    Returns:
        float: Simulated years (days / 365.0). 0.0 on error.
    """
    try:
        s = datetime.datetime.strptime(start_date_chunk, "%Y%m%d")
        e = datetime.datetime.strptime(end_date_chunk, "%Y%m%d")
        days = (e - s).days + 1
        return max(days, 0) / 365.0
    except Exception:
        return 0.0


def calculate_queue_time(submit_time_chunk: str, start_time_chunk: str) -> float:
    """
    Calculate queue time in seconds.

    IMPORTANT: Input timestamps are expected to be in ISO-8601 format in local time
    (e.g., '2025-10-30T14:30:59'). If timestamps are from SLURM directly, they should
    be normalized first using normalize_slurm_timestamp().

    Args:
        submit_time_chunk: Submit timestamp in local ISO-8601 format.
        start_time_chunk: Start timestamp in local ISO-8601 format.

    Returns:
        float: Queue time seconds (>=0). 0.0 on error.
    """
    try:
        if (
            not submit_time_chunk
            or not start_time_chunk
            or submit_time_chunk == "N/A"
            or start_time_chunk == "N/A"
        ):
            return 0.0

        # Parse local timestamps
        t0 = datetime.datetime.fromisoformat(submit_time_chunk)
        t1 = datetime.datetime.fromisoformat(start_time_chunk)
        dt = (t1 - t0).total_seconds()
        return dt if dt >= 0 else 0.0
    except Exception:
        return 0.0


def calculate_memory_bloat(
    max_rss_kb: float,
    model: str,
    resolution_km: str,
    mpi_tasks: int,
    processor_unit: str = "cpu",
) -> MemoryMetrics:
    """
    Compute memory bloat ratio based on RSS and restart-size heuristic.

    The memory bloat formula accounts for binary size:
    Memory_bloat = (M(RSS) - (Binary_size × MPI_ranks)) / Restart_size

    Where:
    - M(RSS): Maximum Resident Set Size (total memory usage in KB)
    - Binary_size: Size of the model executable binary
    - MPI_ranks: Number of MPI compute tasks (from Data Output Cost analysis)
    - Restart_size: Expected size of restart files for the model/resolution

    This formula represents the memory overhead beyond the binary footprint
    and restart data, normalized by restart size.

    Args:
        max_rss_kb: Maximum RSS in kilobytes (direct value, not from raw_info).
        model: Model name (e.g., 'ifs-nemo', 'ICON', 'IFS-FESOM').
        resolution_km: Resolution string (e.g., '10km', '5km', '25', '50', '100', 'N/A').
        mpi_tasks: Number of MPI compute tasks (from Data Output Cost metrics).
        processor_unit: Processor type ('cpu' or 'gpu') for ICON binary selection.

    Returns:
        MemoryMetrics: Dictionary with memory bloat ratio and all formula components.
    """
    notes = []

    # Default error result
    def error_result(note: str) -> MemoryMetrics:
        return {
            "Memory_Bloat": 0.0,
            "RSS_Bytes": 0,
            "Binary_Size_Bytes": 0,
            "Restart_Size_Bytes": 0,
            "MPI_Tasks": 0,
            "Binary_Size_Per_Task_GB": 0.0,
            "Restart_Size_GB": 0.0,
            "Model": str(model),
            "Resolution": str(resolution_km),
            "Notes": [note],
        }

    try:
        # Validate inputs
        if not max_rss_kb or max_rss_kb <= 0:
            return error_result(
                "No memory data available (MaxRSS_KB not found or zero)"
            )

        if not mpi_tasks or mpi_tasks <= 0:
            return error_result(
                "No MPI tasks data available (required from Data Output Cost)"
            )

        # Restart sizes in GB - unified table from legacy and current versions
        MODEL_RES_RESTART_GB = {
            "ICON": {"10km": 148, "5km": 592},
            "IFS-NEMO": {"144km": 8.8, "10km": 200, "5km": 650},
            "IFS-FESOM": {"10km": 200, "5km": 650},
            "IFS": {"25": 60, "50": 30, "100": 15},
            "NEMO": {"25": 80, "50": 40, "100": 20},
        }

        # Binary size in GB
        # These values represent typical binary sizes for each model executable
        # ICON: CPU version (189 MB = 0.189 GB), GPU version (206 MB = 0.206 GB)
        # IFS-NEMO: 2 MB = 0.002 GB
        MODEL_BINARY_GB = {
            "ICON": {
                "cpu": 0.189,  # 189 MB for CPU version
                "gpu": 0.206,  # 206 MB for GPU version
            },
            "IFS-NEMO": 0.002,  # ifsMASTER
            "IFS-FESOM": 0.002,  # ifsMASTER
            "IFS": 0.002,  # ifsMASTER
            "NEMO": 0.037,  # nemo.exe
        }

        # Normalize model name (handle ifs-nemo vs IFS-NEMO)
        model_normalized = str(model).upper().replace("_", "-")

        # Try to normalize resolution (extract numeric part or keep original)
        resolution_str = str(resolution_km).strip()
        if resolution_str in ("N/A", "", "None"):
            return error_result(f"Resolution not specified (got '{resolution_str}')")

        # Try both original and numeric-only versions
        resolution_numeric = re.sub(r"[^\d]", "", resolution_str)

        restart_size_gb = None
        if model_normalized in MODEL_RES_RESTART_GB:
            # Try exact match first
            restart_size_gb = MODEL_RES_RESTART_GB[model_normalized].get(resolution_str)
            # Then try numeric-only
            if restart_size_gb is None and resolution_numeric:
                restart_size_gb = MODEL_RES_RESTART_GB[model_normalized].get(
                    resolution_numeric
                )

        if restart_size_gb is None:
            return error_result(
                f"Unknown model/resolution combination: {model_normalized}/{resolution_str}"
            )

        # Get binary size for this model
        binary_size_entry = MODEL_BINARY_GB.get(model_normalized, 0.0)

        # Handle ICON's dual structure (cpu/gpu)
        if isinstance(binary_size_entry, dict):
            # ICON model: select based on processor_unit
            pu_normalized = str(processor_unit).lower()
            binary_size_gb = binary_size_entry.get(
                pu_normalized, binary_size_entry.get("cpu", 0.0)
            )
            notes.append(f"Using {pu_normalized.upper()} binary size for ICON")
        else:
            # Other models: single value
            binary_size_gb = binary_size_entry

        # Total memory usage in bytes (RSS is already total across all tasks)
        total_memory_bytes = int(max_rss_kb * 1024)

        # Binary memory footprint in bytes (binary size × MPI ranks)
        binary_memory_bytes = int(binary_size_gb * (1024**3) * mpi_tasks)

        # Restart size in bytes
        restart_size_bytes = int(restart_size_gb * (1024**3))

        # Updated formula: Memory_bloat = (RSS - (Binary_size × MPI_ranks)) / Restart_size
        # This represents how much extra memory beyond binary and restart is being used
        numerator = total_memory_bytes - binary_memory_bytes

        memory_bloat = (
            float(numerator) / float(restart_size_bytes)
            if restart_size_bytes > 0
            else 0.0
        )

        return {
            "Memory_Bloat": memory_bloat,
            "RSS_Bytes": total_memory_bytes,
            "Binary_Size_Bytes": binary_memory_bytes,
            "Restart_Size_Bytes": restart_size_bytes,
            "MPI_Tasks": mpi_tasks,
            "Binary_Size_Per_Task_GB": binary_size_gb,
            "Restart_Size_GB": restart_size_gb,
            "Model": model_normalized,
            "Resolution": resolution_str,
            "Notes": notes,
        }

    except Exception as e:
        return error_result(f"Unexpected error calculating memory bloat: {str(e)}")


def calculate_storage_size(
    fdb_home: str,
    class_val: str,
    dataset: str,
    activity: str,
    experiment: str,
    generation: str,
    model: str,
    realization: str,
    expver: str,
    stream: str,
    start_date: str,
    end_date: str,
) -> tuple[int, Optional[str]]:
    """
    Calculate total storage size for FDB data within a date range.

    Reads paths from FDB_HOME/etc/fdb/config.yaml using YAML parser,
    filters paths by read/execute permissions, uses du -sb for byte-accurate sizes,
    and iterates over date range (inclusive).

    Args:
        fdb_home: FDB home directory (contains etc/fdb/config.yaml).
        class_val: Request class.
        dataset: Dataset name.
        activity: Activity name.
        experiment: Experiment name.
        generation: Generation.
        model: Model name.
        realization: Realization.
        expver: Experiment version.
        stream: Stream name.
        start_date: Start date 'yyyymmdd'.
        end_date: End date 'yyyymmdd'.

    Returns:
        tuple[int, Optional[str]]: (Total size in bytes, error note or None)
    """
    # Validate FDB config exists
    config_file = os.path.join(fdb_home, "etc", "fdb", "config.yaml")
    if not os.path.exists(config_file):
        return (0, f"FDB config file not found: {config_file}")

    # Read FDB config to get storage paths
    try:
        with open(config_file, "r") as f:
            config = yaml.safe_load(f)
    except Exception as e:
        return (0, f"Error reading FDB config file: {str(e)}")

    # Extract paths from config recursively
    paths = []
    if isinstance(config, dict):

        def extract_paths(obj):
            """Recursively extract all 'path' entries from nested dict/list structure."""
            if isinstance(obj, dict):
                for key, value in obj.items():
                    if key == "path" and isinstance(value, str):
                        paths.append(value.strip('"').strip("'"))
                    else:
                        extract_paths(value)
            elif isinstance(obj, list):
                for item in obj:
                    extract_paths(item)

        try:
            extract_paths(config)
        except Exception as e:
            return (0, f"Error extracting paths from FDB config: {str(e)}")

    if not paths:
        return (0, "No storage paths found in FDB config")

    # Filter paths with read/execute permissions
    valid_paths = []
    for path in set(paths):  # Remove duplicates
        try:
            if os.path.exists(path) and os.access(path, os.R_OK | os.X_OK):
                valid_paths.append(path)
        except Exception:
            # Skip paths that cause permission errors
            continue

    if not valid_paths:
        return (
            0,
            f"No accessible storage paths found (checked {len(paths)} paths)",
        )

    # Parse dates
    try:
        start_dt = datetime.datetime.strptime(start_date, "%Y%m%d")
        end_dt = datetime.datetime.strptime(end_date, "%Y%m%d")
    except ValueError as e:
        return (0, f"Invalid date format: {str(e)}")

    total_size_bytes = 0
    found_any_data = False
    dirs_checked = 0
    dirs_found = 0

    print(
        f"INFO: Searching for FDB data in {len(valid_paths)} path(s) for date range {start_date}-{end_date}"
    )

    current_dt = start_dt
    while current_dt <= end_dt:
        current_date_str = current_dt.strftime("%Y%m%d")

        # Construct folder name - FDB directories use uppercase model names
        folder_name = f"{class_val}:{dataset}:{activity}:{experiment}:{generation}:{model.upper()}:{realization}:{expver}:{stream}:{current_date_str}"

        for root_path in valid_paths:
            full_path = os.path.join(root_path, folder_name)
            dirs_checked += 1

            if os.path.exists(full_path) and os.path.isdir(full_path):
                found_any_data = True
                dirs_found += 1
                try:
                    # Use du command to get directory size
                    result = subprocess.run(
                        ["du", "-sb", full_path],
                        capture_output=True,
                        text=True,
                        check=True,
                        timeout=60,
                    )
                    size_bytes = int(result.stdout.split()[0])
                    total_size_bytes += size_bytes

                except subprocess.TimeoutExpired:
                    return (0, f"Timeout calculating size for {full_path}")
                except (subprocess.CalledProcessError, ValueError, IndexError) as e:
                    return (0, f"Error calculating size for {full_path}: {str(e)}")

        current_dt += datetime.timedelta(days=1)

    if not found_any_data:
        print(
            f"WARNING: No FDB output data found after checking {dirs_checked} directories"
        )
        print(f"WARNING: Searched in paths - {valid_paths}")
        print(
            f"WARNING: Expected folder pattern - {class_val}:{dataset}:{activity}:{experiment}:{generation}:{model.upper()}:{realization}:{expver}:{stream}:YYYYMMDD"
        )
        return (
            0,
            f"No FDB output data found (checked {dirs_checked} directories). Data may not be written yet or paths are incorrect",
        )

    return (int(total_size_bytes), None)


def calculate_number_of_grid_points(grid_atm: str) -> int:
    """
    Estimate the number of grid points based on atmospheric grid resolution.

    Args:
        grid_atm: Atmospheric grid resolution string (e.g., 'tco79l137', 'T255l123').

    Returns:
        int: Estimated number of grid points, or 0 if unknown/invalid.
    """
    try:
        if not grid_atm:
            return 0

        s = str(grid_atm).lower()

        # Extract levels (L component)
        level_match = re.search(r"l(\d+)", s)
        if not level_match:
            return 0

        try:
            levels = int(level_match.group(1))
        except (ValueError, AttributeError):
            return 0

        # Extract truncation/resolution number (T or TCO component)
        points_match = re.search(r"(?:tco|t)\s*(\d+)", s)
        if not points_match:
            return 0

        try:
            points = int(points_match.group(1))
        except (ValueError, AttributeError):
            return 0

        # Formula: (points * 8) * levels
        # For tco79l137: (79 * 8) * 137 = 86,632 grid points
        grid_points = (points * 8) * levels
        return grid_points

    except Exception:
        # Catch any unexpected errors (regex, etc.)
        return 0


# =============================================================================
# Metrics calculation functions
# =============================================================================


def calculate_cpu_metrics(raw_info: RawInfo, simulated_years: float) -> CpuMetrics:
    """
    Compute CPU-related metrics using physical cores.

    Args:
        raw_info: RawInfo structure with CPUTimeRAW_Seconds and Threads_Per_Core_Count.
        simulated_years: Simulated years.

    Returns:
        CpuMetrics: CPU metrics with Core_Hours and Core_Hours_Per_Simulated_Year (CHSY).
    """
    # Get TPC to normalize from logical to physical cores
    tpc = int(raw_info.get("Threads_Per_Core_Count", 1))
    if tpc < 1:
        tpc = 1

    # CPUTimeRAW from sacct = AllocCPUS (logical cores) × ElapsedRaw (seconds)
    # To get physical core-hours: divide by TPC to convert logical→physical, then /3600 for hours
    cpu_time_raw_value = raw_info.get("CPUTimeRAW_Seconds", 0.0)
    try:
        cpu_time_raw_seconds = float(cpu_time_raw_value)
    except Exception:
        cpu_time_raw_seconds = 0.0

    # Normalize: logical core-seconds → physical core-hours
    core_hours = (
        (cpu_time_raw_seconds / tpc) / 3600.0
        if cpu_time_raw_seconds > 0 and tpc > 0
        else 0.0
    )
    chsy = (
        (core_hours / simulated_years)
        if (simulated_years and simulated_years > 0)
        else 0.0
    )

    return {
        "Core_Hours": core_hours,
        "Core_Hours_Per_Simulated_Year": chsy,
    }


def calculate_memory_metrics(
    raw_info: RawInfo,
    model: str,
    resolution_km: str,
    mpi_tasks: int,
    processor_unit: str = "cpu",
) -> MemoryMetrics:
    """
    Compute memory-related metrics with notes for failures.

    Args:
        raw_info: RawInfo structure with MaxRSS_KB.
        model: Model name.
        resolution_km: Resolution string.
        mpi_tasks: Number of MPI compute tasks (from Data Output Cost).
        processor_unit: Processor type ('cpu' or 'gpu').

    Returns:
        MemoryMetrics: Memory metrics with full breakdown including all formula components.
    """

    # Default error result helper
    def error_result(note: str) -> MemoryMetrics:
        return {
            "Memory_Bloat": 0.0,
            "RSS_Bytes": 0,
            "Binary_Size_Bytes": 0,
            "Restart_Size_Bytes": 0,
            "MPI_Tasks": 0,
            "Binary_Size_Per_Task_GB": 0.0,
            "Restart_Size_GB": 0.0,
            "Model": str(model),
            "Resolution": str(resolution_km),
            "Notes": [note],
        }

    # Extract MaxRSS_KB directly from raw_info (already float type)
    max_rss_kb = raw_info.get("MaxRSS_KB", 0.0)

    # Validate
    if max_rss_kb <= 0:
        return error_result("MaxRSS_KB not available or zero in raw_info")

    # Calculate memory bloat and get detailed breakdown
    bloat_details = calculate_memory_bloat(
        max_rss_kb, model, resolution_km, mpi_tasks, processor_unit
    )

    # Return the complete MemoryBloatDetails as MemoryMetrics (they have the same structure)
    return bloat_details


def calculate_energy_metrics(
    raw_info: RawInfo, simulated_years: float, hpc: str
) -> EnergyMetrics:
    """
    Compute energy consumption and carbon footprint metrics.

    Formula for Carbon Footprint:
        Carbon_Footprint (gCO2) = Energy (Joules) * Conversion_Factor (gCO2/kWh) * PUE / 3,600,000

    Where:
        - Energy is in Joules
        - Conversion Factor is the energy mix of the HPC (gCO2/kWh)
        - PUE is the Power Usage Effectiveness of the HPC
        - 3,600,000 converts Joules to kWh (1 kWh = 3,600,000 J)

    Args:
        raw_info: RawInfo structure.
        simulated_years: Simulated years.
        hpc: HPC site name.

    Returns:
        EnergyMetrics: Energy metrics with Joules, Joules_Per_Simulated_Year, and Carbon_Footprint_gCO2.
    """
    notes = []

    # Extract energy in Joules (already float type)
    energy_joules = raw_info.get("Energy_Joules", 0.0)

    if energy_joules <= 0:
        notes.append("Energy data not available or zero")

    # Calculate Joules per Simulated Year
    joules_per_sy = (
        (energy_joules / simulated_years)
        if (simulated_years and simulated_years > 0 and energy_joules > 0)
        else 0.0
    )

    # Get HPC energy configuration
    hpc_config = HPC_ENERGY_CONFIG.get(hpc.upper())

    carbon_footprint = 0.0
    conversion_factor = 0.0
    pue = 0.0

    if not hpc_config:
        notes.append(f"No energy configuration found for HPC: {hpc}")
    elif energy_joules <= 0:
        notes.append(
            "Energy consumption is zero or negative - cannot calculate carbon footprint"
        )
    else:
        conversion_factor = hpc_config["conversion_factor_gCO2_per_kWh"]
        pue = hpc_config["pue"]
        # Convert Joules to kWh and calculate carbon footprint
        # 1 kWh = 3,600,000 Joules
        carbon_footprint = (energy_joules * conversion_factor * pue) / 3_600_000

    return {
        "Energy_Joules": energy_joules,
        "Joules_Per_Simulated_Year": joules_per_sy,
        "Carbon_Footprint_gCO2": carbon_footprint,
        "HPC_Parameters": {
            "Conversion_Factor_gCO2_per_kWh": conversion_factor,
            "PUE": pue,
        },
        "Notes": notes,
    }


def calculate_storage_metrics_with_intensity(
    raw_info: RawInfo,
    simulated_years: float,
    fdb_home: str,
    class_val: str,
    dataset: str,
    activity: str,
    experiment: str,
    generation: str,
    model: str,
    realization: str,
    expver: str,
    stream: str,
    start_date: str,
    end_date: str,
) -> StorageMetrics:
    """
    Compute storage/data intensity metrics with notes for failures.

    Args:
        raw_info: RawInfo structure.
        simulated_years: Simulated years.
        fdb_home: FDB home directory.
        class_val: FDB class value.
        dataset: FDB dataset.
        activity: FDB activity.
        experiment: FDB experiment.
        generation: FDB generation.
        model: Model name.
        realization: FDB realization.
        expver: FDB experiment version.
        stream: FDB stream.
        start_date: Start date (yyyymmdd).
        end_date: End date (yyyymmdd).

    Returns:
        StorageMetrics: Storage metrics with Total_Output_Bytes, Data_Intensity_Bytes_Per_Core_Hour, and Notes.
    """
    storage_size_bytes, storage_error = calculate_storage_size(
        fdb_home=fdb_home,
        class_val=class_val,
        dataset=dataset,
        activity=activity,
        experiment=experiment,
        generation=generation,
        model=model,
        realization=realization,
        expver=expver,
        stream=stream,
        start_date=start_date,
        end_date=end_date,
    )

    notes = []
    if storage_error:
        notes.append(storage_error)

    cpu = calculate_cpu_metrics(raw_info, simulated_years)
    core_hours = cpu.get("Core_Hours", 0.0) or 0.0

    data_intensity = (storage_size_bytes / core_hours) if core_hours > 0 else 0.0

    return {
        "Total_Output_Bytes": int(storage_size_bytes),
        "Data_Intensity_Bytes_Per_Core_Hour": data_intensity,
        "Notes": notes,
    }


def calculate_data_output_cost_metrics(
    rundir_path: str,
    model: str,
    nodes: int = 0,
    tasks_per_node: int = 0,
    threads: int = 1,
    ifs_io_tasks: int = 0,
    nemo_io_tasks: int = 0,
    ifs_io_nodes: int = 0,
    nemo_io_nodes: int = 0,
    ifs_io_ppn: int = 0,
    nemo_io_ppn: int = 0,
    fesom_io_tasks: int = 0,
    fesom_io_nodes: int = 0,
    fesom_io_ppn: int = 0,
    threads_per_core: int = 1,
) -> DataOutputCostMetrics:
    """
    Calculate Data Output Cost performance metrics from model output files.

    Uses the io_analyzer component to parse timing and I/O statistics
    from the rundir (pie.csv and timing.output for IFS-NEMO).

    BEHAVIOR:
    - TIME METRICS (Times, Percentages, IO_Efficiency, Components): Always calculated
      if rundir_path exists and contains valid model output files.
    - RESOURCE METRICS (MPI_Tasks, Physical_Cores): Always set to 0 (not calculated).

    This means the function can work with minimal information - it only needs:
    1. Valid rundir_path with model output files
    2. Model name

    All other parameters (nodes, tasks_per_node, io_tasks, etc.) are optional and
    not used in the current implementation.

    Args:
        rundir_path: Path to model run directory.
        model: Model name.
        nodes: Total number of compute nodes allocated (NOT USED).
        tasks_per_node: Number of tasks per node (NOT USED).
        threads: Number of OpenMP threads per task (NOT USED).
        ifs_io_tasks: Number of IFS I/O tasks (NOT USED).
        nemo_io_tasks: Number of NEMO I/O tasks (NOT USED).
        ifs_io_nodes: Number of IFS I/O nodes (NOT USED).
        nemo_io_nodes: Number of NEMO I/O nodes (NOT USED).
        ifs_io_ppn: IFS I/O processes per node (NOT USED).
        nemo_io_ppn: NEMO I/O processes per node (NOT USED).
        fesom_io_tasks: Number of FESOM I/O tasks (NOT USED).
        fesom_io_nodes: Number of FESOM I/O nodes (NOT USED).
        fesom_io_ppn: FESOM I/O processes per node (NOT USED).
        threads_per_core: Number of hardware threads per physical core (NOT USED).

    Returns:
        DataOutputCostMetrics: Data Output Cost metrics with:
            - Times: Compute, IO, Total times in seconds (calculated from rundir)
            - Percentages: Time percentages (calculated from rundir)
            - IO_Efficiency: Serialization factor and wasted hours (calculated from rundir)
            - Components: Per-component breakdown (calculated from rundir)
            - Resources: Always 0 (not calculated)
            - Notes: Any warnings or errors encountered
    """
    notes = []

    # Initialize default values (N/A case) - Resources always set to 0
    default_metrics: DataOutputCostMetrics = {
        "Resources": {
            "Compute": {"MPI_Tasks": 0, "Physical_Cores": 0},
            "IO": {"MPI_Tasks": 0, "Physical_Cores": 0},
            "Total": {"MPI_Tasks": 0, "Physical_Cores": 0},
        },
        "Times": {
            "Compute": 0.0,
            "IO": 0.0,
            "Total": 0.0,
        },
        "Percentages": {
            "Compute_Time": 0.0,
            "IO_Time": 0.0,
            "Compute_Resources": 0.0,
            "IO_Resources": 0.0,
        },
        "IO_Efficiency": {
            "Serialization_Factor": 0.0,
            "Wasted_Node_Hours": 0.0,
        },
        "Components": {},
        "Notes": [],
    }

    # Check if rundir is available
    if not rundir_path or rundir_path == "N/A":
        notes.append(
            "Run directory path not provided - Data Output Cost metrics unavailable"
        )
        default_metrics["Notes"] = notes
        return default_metrics

    if not os.path.exists(rundir_path):
        notes.append(f"Run directory does not exist: {rundir_path}")
        default_metrics["Notes"] = notes
        return default_metrics

    if not os.path.isdir(rundir_path):
        notes.append(f"Run directory path is not a directory: {rundir_path}")
        default_metrics["Notes"] = notes
        return default_metrics

    # Import io_analyzer module
    try:
        from io_analyzer import analyze_io
    except ImportError as e:
        notes.append(f"io_analyzer module not available: {str(e)}")
        default_metrics["Notes"] = notes
        return default_metrics

    # Use the analyze_io function with all parameters
    try:
        io_results = analyze_io(
            rundir_path=rundir_path,
            model_name=model,
            nodes=nodes,
            tasks_per_node=tasks_per_node,
            threads=threads,
            ifs_io_tasks=ifs_io_tasks,
            nemo_io_tasks=nemo_io_tasks,
            ifs_io_nodes=ifs_io_nodes,
            nemo_io_nodes=nemo_io_nodes,
            ifs_io_ppn=ifs_io_ppn,
            nemo_io_ppn=nemo_io_ppn,
            fesom_io_tasks=fesom_io_tasks,
            fesom_io_nodes=fesom_io_nodes,
            fesom_io_ppn=fesom_io_ppn,
            threads_per_core=threads_per_core,
        )

        # NOTE: We only extract TIME-based metrics, not resource metrics
        # Resource metrics (MPI_Tasks, Physical_Cores) are left at default (0)
        from typing import cast

        result: DataOutputCostMetrics = {
            "Resources": {
                "Compute": {"MPI_Tasks": 0, "Physical_Cores": 0},
                "IO": {"MPI_Tasks": 0, "Physical_Cores": 0},
                "Total": {"MPI_Tasks": 0, "Physical_Cores": 0},
            },
            "Times": cast(TimeAllocation, io_results.times),
            "Percentages": cast(PercentageMetrics, io_results.percentages),
            "IO_Efficiency": cast(IOEfficiencyMetrics, io_results.overhead),
            "Components": cast(Dict[str, ComponentBreakdown], io_results.components),
            "Notes": io_results.notes,
        }

        # Add note about resource metrics not being calculated
        if "Resources not calculated" not in result["Notes"]:
            result["Notes"].append(
                "Resources (MPI_Tasks, Physical_Cores) not calculated - only time-based metrics available"
            )

        return result

    except FileNotFoundError as e:
        notes.append(f"Required data output analysis files not found: {str(e)}")
        default_metrics["Notes"] = notes
        return default_metrics
    except ValueError as e:
        notes.append(f"Error parsing data output data: {str(e)}")
        default_metrics["Notes"] = notes
        return default_metrics
    except Exception as e:
        notes.append(f"Unexpected error analyzing Data Output Cost metrics: {str(e)}")
        default_metrics["Notes"] = notes
        return default_metrics


def calculate_sequential_coupling_cost(
    model: str, hpc: str, nodes: int, tasks_per_node: int
) -> SequentialCouplingCostMetrics:
    """
    Calculate Sequential Coupling Cost based on model, HPC, and task configuration.

    The cost is calculated using a linear model: cost = slope * nodes + intercept
    The result is returned as a percentage (0-100).

    Args:
        model: Model name (e.g., 'ifs-nemo', 'IFS-FESOM').
        hpc: HPC site name (e.g., 'marenostrum5', 'LUMI').
        nodes: Number of nodes allocated to the job.
        tasks_per_node: Number of tasks per node.

    Returns:
        SequentialCouplingCostMetrics: Dictionary containing the calculated cost and metadata.
    """
    notes = []

    # Default result
    default_result: SequentialCouplingCostMetrics = {
        "Sequential_Coupling_Cost_Percentage": 0.0,
        "Nodes": nodes,
        "Tasks_Per_Node": tasks_per_node,
        "Model": model,
        "HPC": hpc,
        "Linear_Model_Coefficients": {
            "Slope": 0.0,
            "Intercept": 0.0,
        },
        "Notes": [],
    }

    # Normalize model and HPC names (case-insensitive, handle different formats)
    model_normalized = str(model).upper().replace("_", "-")
    hpc_normalized = str(hpc).upper().replace("-", "").replace("_", "")

    # Validate inputs
    if not model or model == "N/A":
        notes.append("Model name not provided - Sequential Coupling Cost unavailable")
        default_result["Notes"] = notes
        return default_result

    if not hpc or hpc == "N/A":
        notes.append("HPC name not provided - Sequential Coupling Cost unavailable")
        default_result["Notes"] = notes
        return default_result

    try:
        nodes_int = int(nodes)
        if nodes_int <= 0:
            raise ValueError("Nodes must be positive")
    except (ValueError, TypeError) as e:
        notes.append(f"Invalid nodes value '{nodes}': {str(e)}")
        default_result["Notes"] = notes
        return default_result

    try:
        tasks_per_node_int = int(tasks_per_node)
        if tasks_per_node_int <= 0:
            raise ValueError("Tasks per node must be positive")
    except (ValueError, TypeError) as e:
        notes.append(f"Invalid tasks_per_node value '{tasks_per_node}': {str(e)}")
        default_result["Notes"] = notes
        return default_result

    # Update default result with validated values
    default_result["Nodes"] = nodes_int
    default_result["Tasks_Per_Node"] = tasks_per_node_int

    # Check if model exists in configuration
    if model_normalized not in SEQUENTIAL_COUPLING_COST_CONFIG:
        notes.append(
            f"No Sequential Coupling Cost configuration for model: {model_normalized}"
        )
        default_result["Notes"] = notes
        return default_result

    model_config = SEQUENTIAL_COUPLING_COST_CONFIG[model_normalized]

    # Try to find HPC configuration (normalize for comparison)
    hpc_config = None
    for config_hpc in model_config.keys():
        if config_hpc.upper().replace("-", "").replace("_", "") == hpc_normalized:
            hpc_config = model_config[config_hpc]
            break

    if hpc_config is None:
        notes.append(
            f"No Sequential Coupling Cost configuration for HPC '{hpc}' in model {model_normalized}"
        )
        default_result["Notes"] = notes
        return default_result

    # Check if tasks_per_node configuration exists
    if tasks_per_node_int not in hpc_config:
        available_configs = sorted(hpc_config.keys())
        notes.append(
            f"No Sequential Coupling Cost configuration for {tasks_per_node_int} tasks/node "
            f"on {hpc} (available: {available_configs})"
        )
        default_result["Notes"] = notes
        return default_result

    # Get slope and intercept
    params = hpc_config[tasks_per_node_int]
    slope = params["slope"]
    intercept = params["intercept"]

    # Calculate cost: cost = slope * nodes + intercept
    # Convert to percentage (assuming the values are in decimal form, e.g., 0.05 = 5%)
    cost_decimal = slope * nodes_int + intercept
    cost_percentage = cost_decimal * 100.0

    # Ensure non-negative
    if cost_percentage < 0:
        notes.append(
            f"Calculated negative cost ({cost_percentage:.2f}%) - clamping to 0%"
        )
        cost_percentage = 0.0

    return {
        "Sequential_Coupling_Cost_Percentage": cost_percentage,
        "Nodes": nodes_int,
        "Tasks_Per_Node": tasks_per_node_int,
        "Model": model,
        "HPC": hpc,
        "Linear_Model_Coefficients": {
            "Slope": float(slope),
            "Intercept": float(intercept),
        },
        "Notes": notes,
    }


# =============================================================================
# Main orchestration function
# =============================================================================


def get_performance_metrics(
    raw_info: RawInfo,
    start_date_chunk: str,
    end_date_chunk: str,
    grid_atm: str,
    grid_oce: str,
    resolution_km: str,
    complexity: Dict[str, str],
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
    rundir_path: str = "N/A",
    nodes: int = 0,
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
) -> PerformanceSummary:
    """
    Calculate complete performance metrics from raw SLURM info and configuration.

    This is the main public API function that coordinates all metric calculations.

    Args:
        raw_info: RawInfo structure from SLURM accounting.
        start_date_chunk: Start date (yyyymmdd).
        end_date_chunk: End date (yyyymmdd).
        grid_atm: Atmospheric grid.
        grid_oce: Ocean grid.
        resolution_km: Resolution string (km) for memory bloat calculation.
        complexity: Model complexity dictionary with model-specific keys.
        hpc: HPC site name.
        model: Model name.
        fdb_home: FDB home directory.
        class_val: FDB class value.
        dataset: FDB dataset.
        activity: FDB activity.
        experiment: FDB experiment.
        generation: FDB generation.
        model_req: FDB model requirement.
        realization: FDB realization.
        expver: FDB experiment version.
        stream: FDB stream.
        rundir_path: Path to model run directory for I/O analysis.
        nodes: Number of nodes allocated to the job.
        tasks_per_node: Number of tasks per node.
        performance_resolution: Grid points resolution from PERFORMANCE_METRICS.RESOLUTION.
        ifs_io_tasks: Number of IFS I/O tasks (task-based allocation).
        nemo_io_tasks: Number of NEMO/FESOM I/O tasks (task-based allocation).
        ifs_io_nodes: Number of IFS I/O nodes (node-based allocation).
        nemo_io_nodes: Number of NEMO/FESOM I/O nodes (node-based allocation).
        ifs_io_ppn: IFS I/O processes per node (node-based allocation).
        nemo_io_ppn: NEMO/FESOM I/O processes per node (node-based allocation).
        threads: Number of OpenMP threads per task.
        processor_unit: Processor type ('cpu' or 'gpu').

    Returns:
        PerformanceSummary: Complete PerformanceSummary structure with all metrics.
    """
    # Calculate simulated years
    sy = calculate_simulated_years(start_date_chunk, end_date_chunk)

    # Extract runtime
    runtime_seconds = float(raw_info.get("RunTime", 0) or 0)
    try:
        runtime_seconds = float(runtime_seconds)
    except Exception:
        runtime_seconds = 0.0

    # Calculate SYPD (Simulated Years Per Day)
    sypd = (sy / (runtime_seconds / 86400.0)) if runtime_seconds > 0 else "N/A"

    # Calculate queue time and QSYPD
    queue_time_seconds = calculate_queue_time(
        raw_info.get("SubmitTime", "N/A"),
        raw_info.get("StartTime", "N/A"),
    )
    total_time_seconds = runtime_seconds + queue_time_seconds
    qsypd = (sy / (total_time_seconds / 86400.0)) if total_time_seconds > 0 else "N/A"

    # Calculate all metrics
    cpu_metrics = calculate_cpu_metrics(raw_info, sy)
    energy_metrics = calculate_energy_metrics(raw_info, sy, hpc)

    storage_metrics = calculate_storage_metrics_with_intensity(
        raw_info=raw_info,
        simulated_years=sy,
        fdb_home=fdb_home,
        class_val=class_val,
        dataset=dataset,
        activity=activity,
        experiment=experiment,
        generation=generation,
        model=model_req,
        realization=realization,
        expver=expver,
        stream=stream,
        start_date=start_date_chunk,
        end_date=end_date_chunk,
    )
    # Extract threads_per_core from monitor metadata if available
    threads_per_core = 1
    if raw_info.get("Monitor_Metadata"):
        monitor_data = raw_info.get("Monitor_Metadata", {})
        if isinstance(monitor_data, dict):
            threads_per_core = monitor_data.get("threads_per_core", 1)
            if not isinstance(threads_per_core, int) or threads_per_core < 1:
                threads_per_core = 1

    # Calculate Data Output Cost FIRST to attempt getting accurate MPI tasks count
    data_output_cost_metrics = calculate_data_output_cost_metrics(
        rundir_path=rundir_path,
        model=model,
        nodes=nodes,
        tasks_per_node=tasks_per_node,
        threads=threads,
        ifs_io_tasks=ifs_io_tasks,
        nemo_io_tasks=nemo_io_tasks,
        ifs_io_nodes=ifs_io_nodes,
        nemo_io_nodes=nemo_io_nodes,
        ifs_io_ppn=ifs_io_ppn,
        nemo_io_ppn=nemo_io_ppn,
        fesom_io_tasks=fesom_io_tasks,
        fesom_io_nodes=fesom_io_nodes,
        fesom_io_ppn=fesom_io_ppn,
        threads_per_core=threads_per_core,
    )

    # Extract compute MPI tasks from Data Output Cost (will be 0 if not available)
    mpi_tasks_from_doc = (
        data_output_cost_metrics.get("Resources", {})
        .get("Compute", {})
        .get("MPI_Tasks", 0)
    )

    # Use NTasks from sacct if Data Output Cost didn't provide MPI tasks
    # NTasks is the direct value from SLURM, not multiplied by nodes
    if mpi_tasks_from_doc == 0:
        mpi_tasks = raw_info.get("NTasks", 0)
    else:
        mpi_tasks = mpi_tasks_from_doc

    # Now calculate memory metrics using the MPI tasks count (from DOC or NTasks)
    memory_metrics = calculate_memory_metrics(
        raw_info, model, resolution_km, mpi_tasks, processor_unit
    )

    grid_points = calculate_number_of_grid_points(grid_atm)

    # Calculate Sequential Coupling Cost
    sequential_coupling_cost_metrics = calculate_sequential_coupling_cost(
        model=model,
        hpc=hpc,
        nodes=nodes,
        tasks_per_node=tasks_per_node,
    )

    # Assemble complete summary
    return {
        "Resolution_Km": resolution_km,
        "Performance_Resolution": performance_resolution,
        "Complexity": complexity,
        "Simulated_Years": sy,
        "Simulated_Years_Per_Day": sypd,
        "Queue_Simulated_Years_Per_Day": qsypd,
        "Cpu": cpu_metrics,
        "Energy": energy_metrics,
        "Memory": memory_metrics,
        "Storage": storage_metrics,
        "Data_Output_Cost": data_output_cost_metrics,
        "Sequential_Coupling_Cost": sequential_coupling_cost_metrics,
        "Grid_Points": int(grid_points) if isinstance(grid_points, (int, float)) else 0,
    }


def build_metadata(
    raw_info: RawInfo,
    expid: str,
    chunk: str,
    start_date_chunk: str,
    end_date_chunk: str,
    grid_atm: str,
    grid_oce: str,
    hpc: str,
    model: str,
    monitor_metadata: Optional[Dict[str, Any]] = None,
    timestamp_func: Optional[Callable[[], tuple[int, str]]] = None,
) -> Metadata:
    """
    Build complete metadata structure with timestamps and TPC information.

    Args:
        raw_info: RawInfo structure from SLURM accounting.
        expid: Experiment ID.
        chunk: Chunk identifier.
        start_date_chunk: Start date (yyyymmdd).
        end_date_chunk: End date (yyyymmdd).
        grid_atm: Atmospheric grid.
        grid_oce: Ocean grid.
        hpc: HPC site name.
        model: Model name.
        monitor_metadata: Optional monitor metadata dict for TPC detection.
        timestamp_func: Optional function to generate (epoch, iso) timestamps.

    Returns:
        Metadata: Complete metadata structure with all fields.
    """
    # Get timestamp - use provided function or import default
    if timestamp_func:
        epoch, iso = timestamp_func()
    else:
        # Import here to avoid circular dependency
        from datetime import datetime

        dt = datetime.now()
        epoch = int(dt.timestamp())
        iso = dt.isoformat()

    tpc: int = raw_info.get("Threads_Per_Core_Count", 1)

    # Generate notes about TPC source and calculation method
    notes: List[str] = []
    if monitor_metadata:
        job_metadata = monitor_metadata.get("Job_Metadata", {})
        tpc_value = job_metadata.get("Threads_Per_Core_Count")
        if tpc_value and tpc_value > 0:
            notes.append(
                "Threads_Per_Core_Count sourced from resource monitor metadata"
            )
        else:
            notes.append(
                "Threads_Per_Core_Count not found in monitor metadata, using default value of 1"
            )
            notes.append(
                "WARNING: All calculations are using logical CPUs instead of physical cores"
            )
    else:
        notes.append(
            "No monitor metadata available, using default Threads_Per_Core_Count value of 1"
        )
        notes.append(
            "WARNING: All calculations are using logical CPUs instead of physical cores"
        )

    if tpc == 1:
        notes.append(
            "WARNING: Core_Hours and related metrics represent logical CPU hours, not physical core hours"
        )

    # Calculate queue time
    submit_time = raw_info.get("SubmitTime", "N/A")
    start_time = raw_info.get("StartTime", "N/A")

    queue_time_seconds = 0.0
    if submit_time != "N/A" and start_time != "N/A":
        queue_time_seconds = calculate_queue_time(submit_time, start_time)

    metadata: Metadata = {
        "Timestamp_Epoch": epoch,
        "Timestamp_ISO_Local": iso,
        "Job": {
            "JobID": raw_info.get("JobID"),
            "JobName": raw_info.get("JobName"),
        },
        "Experiment": {
            "ExpId": expid,
            "Chunk": chunk,
            "Start_Date": start_date_chunk,
            "End_Date": end_date_chunk,
        },
        "Environment": {"HPC": hpc, "Model": model},
        "Grids": {"Atm": grid_atm, "Oce": grid_oce},
        "Allocation": {
            "Parallelization": raw_info.get("Parallelization"),
            "Threads_Per_Core_Count": tpc,
            "Nodes": raw_info.get("Nodes"),
        },
        "Timestamps": {
            "StartTime": raw_info.get("StartTime"),
            "EndTime": raw_info.get("EndTime"),
            "SubmitTime": raw_info.get("SubmitTime"),
        },
        "Energy_Joules": raw_info.get("Energy_Joules"),
        "CPUTimeRAW_Seconds": raw_info.get("CPUTimeRAW_Seconds"),
        "RunTime_Seconds": float(raw_info.get("RunTime", 0)),
        "Queue_Time_Seconds": queue_time_seconds,
        "MaxRSS_KB": raw_info.get("MaxRSS_KB"),
        "AveRSS_KB": raw_info.get("AveRSS_KB"),
        "Notes": notes,
    }
    return metadata
