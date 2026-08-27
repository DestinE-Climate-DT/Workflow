import datetime
import glob
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
        CPUTimeRAW_Seconds: Per-chunk CPUTimeRAW in logical core-seconds (float).
            Recovered by diffing consecutive chunks' aggregates downstream.
        CPUTimeRAW_Aggregated_Seconds: Wrapper-cumulative CPUTimeRAW summed over
            the chunk's sacct steps (logical core-seconds, float).
        RunTime: Elapsed time in seconds (float). CPUTime-derived model-compute
            wall span (per-chunk CPUTimeRAW / logical cores), SIM_STAT fallback.
        RunTime_Sim_Stat_Seconds: SIM_STAT full-allocation wall time in seconds
            (end-start), used for GPU hours and as the RunTime fallback (float).
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
    Gpu_Count: int
    Energy_Joules: float
    CPUTimeRAW_Seconds: float
    CPUTimeRAW_Aggregated_Seconds: float
    RunTime: float
    RunTime_Sim_Stat_Seconds: float
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


class GpuMetrics(TypedDict):
    """
    GPU metrics derived from SLURM accounting (the gres/gpu attribute in the
    sacct AllocTRES). Populated for GPU runs; zeros for CPU runs (no gres/gpu).

    Returns:
        Gpu_Count: GPUs allocated to the job (gres/gpu in sacct AllocTRES).
        Gpu_Hours: Gpu_Count x runtime hours.
        Gpu_Hours_Per_Simulated_Year: Gpu_Hours normalized by simulated years.
    """

    Gpu_Count: int
    Gpu_Hours: float
    Gpu_Hours_Per_Simulated_Year: float


class MemoryMetrics(TypedDict):
    """
    Memory efficiency metrics with detailed breakdown.

    Returns:
        Memory_Bloat_Ratio: Per-task runtime memory beyond the binary, relative to the
            per-task restart size: (MaxRSS - binary_per_task) / (restart_total /
            MPI_Tasks). All three operands are per-task so the ratio is meaningful.
        RSS_Bytes: Per-task peak Resident Set Size (MaxRSS) in bytes.
        Binary_Size_Bytes: Total binary footprint (binary size × MPI tasks) in bytes.
        Restart_Size_Bytes: Expected (total) restart file size in bytes.
        MPI_Tasks: Number of MPI compute tasks used in calculation.
        Binary_Size_Per_Task_GB: Size of binary per task in GB.
        Restart_Size_GB: Expected restart size in GB.
        Model: Normalized model name.
        Resolution: Resolution string.
        Notes: Optional list of issues encountered during calculation.
    """

    Memory_Bloat_Ratio: float
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
        Data_Intensity_Bytes_Per_Gpu_Hour: Data output per GPU hour
            (bytes/GPU-hour). 0.0 on CPU runs (no GPU hours).
        Notes: Optional list of issues encountered during calculation.
    """

    Total_Output_Bytes: int
    Data_Intensity_Bytes_Per_Core_Hour: float
    Data_Intensity_Bytes_Per_Gpu_Hour: float
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
    - Components: Per-component breakdown (e.g., IFS, NEMO) with detailed metrics
    - Notes: Additional notes about the analysis
    """

    Resources: Dict[str, ResourceAllocation]  # Keys: 'Compute', 'IO', 'Total'
    Times: TimeAllocation
    Percentages: PercentageMetrics
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
    Gpu: GpuMetrics
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
    CPUTimeRAW_Aggregated_Seconds: float
    RunTime_Seconds: float
    RunTime_Sim_Stat_Seconds: float
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

# Sequential Coupling Cost parameters by model and HPC.
# Cost is calculated as: cost_percentage = (slope * nodes + intercept) * 100
# tasks_per_node is NOT a key — the linear model is calibrated against nodes
# regardless of the per-node task layout used to drive that allocation.
SEQUENTIAL_COUPLING_COST_CONFIG = {
    "IFS-NEMO": {
        "MARENOSTRUM5": {
            "slope": 0.00027878602878260444,
            "intercept": 0.0012039618766926385,
        },
        # Add more HPCs as needed (e.g. "LUMI": {...}).
    },
    "IFS-FESOM": {
        "LUMI": {
            "slope": 0.00015036917751487758,
            "intercept": -0.01052979845771479,
        },
    },
    # Add more models as needed (e.g. "ICON": {...}).
}

# =============================================================================
# Small helpers (logic preserved; added docstrings)
# =============================================================================


# =============================================================================
# sacct parsing
# =============================================================================


def parse_sacct_output(
    output: str, fields: List[str], preferred_job_id: Optional[str] = None
) -> Dict[str, Any]:
    """
    Parse 'sacct -P' output.

    Args:
        output: Raw stdout from sacct.
        fields: Field names used in -o.
        preferred_job_id: When provided, prefer the record whose JobID exactly
            matches this value (e.g. "12345" for a main job or "12345.0" for a
            step). Falls back to the record with the highest CPUTimeRAW.

    Returns:
        dict: Best-effort record for the requested job/step.
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
        if preferred_job_id:
            return str(jobid) == preferred_job_id
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
    "AllocTRES",
    "NTasks",
    "CPUTimeRAW",
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

    Accepts either a bare JobID (e.g. "12345") or a step ID (e.g. "12345.0");
    sacct -j accepts both forms.

    Args:
        job_id: SLURM job id (main job) or step id (JOBID.STEPID).
        timeout: Command timeout in seconds.

    Returns:
        (rc, stdout, stderr): Return code and outputs.
    """
    fmt = ",".join(SACCT_FIELDS)
    # --noconvert: emit memory (MaxRSS/AveRSS) as raw bytes with no unit suffix.
    # Without it this system's sacct returns mixed units in the SAME row —
    # MaxRSS in KiB (e.g. "12536725K") but AveRSS in bare bytes (e.g.
    # "10927778547") — which silently inflates AveRSS x1024 when parsed. Raw
    # bytes everywhere makes extract_memory_kb unambiguous.
    cmd = ["sacct", "-j", job_id, "-o", fmt, "-P", "--noconvert"]

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


def _parse_sacct_rows(output: str) -> List[Dict[str, str]]:
    """
    Parse a sacct -P table into a list of row dicts keyed by header field.

    Used by the per-step aggregator, which needs every row (not the
    "preferred record" semantics of parse_sacct_output).
    """
    lines = [ln for ln in output.strip().splitlines() if ln.strip()]
    if not lines:
        return []
    header = [h.strip() for h in lines[0].split("|")]
    rows: List[Dict[str, str]] = []
    for line in lines[1:]:
        if "|" not in line:
            continue
        parts = line.split("|")
        rows.append(
            {
                header[i]: (parts[i].strip() if i < len(parts) else "")
                for i in range(len(header))
            }
        )
    return rows


def read_chunk_runtime_from_stat(
    hpcrootdir: str, expid: str, sdate: str, member: str, chunk: str
) -> Optional[tuple[int, int]]:
    """
    Read the authoritative chunk [start_epoch, end_epoch] from the Autosubmit
    SIM STAT file.

    Autosubmit writes one STAT file per SIM attempt at
    ``${HPCROOTDIR}/LOG_${EXPID}/${EXPID}_${SDATE}_${MEMBER}_${CHUNK}_SIM_STAT_<retrial>``
    whose first line is the run start epoch and second line the run end epoch.
    The file is named per chunk/member even under a wrapper, so it isolates a
    single chunk's wall time — which the shared-allocation SLURM step rows
    cannot (their Start collapses to the allocation start, inflating Elapsed).

    Globs the retrial-suffixed files and takes the most recently written one.
    The suffix is Autosubmit's FAIL_COUNT, which resets across experiment
    re-runs, so a stale higher-numbered file from a previous run can otherwise
    shadow this run's file (observed: a stale _SIM_STAT_2 from 28 min earlier
    hiding the current run's _SIM_STAT_0).

    Args:
        hpcrootdir: Experiment HPCROOTDIR.
        expid: Experiment id.
        sdate: Simulation start date (yyyymmdd) — the SDATE in the file name,
            NOT the chunk's own start date.
        member: Ensemble member (e.g. 'fc0').
        chunk: Chunk number.

    Returns:
        (start_epoch, end_epoch) as ints, or None when the file is missing or
        unparseable.
    """
    log_dir = os.path.join(hpcrootdir, f"LOG_{expid}")
    pattern = os.path.join(log_dir, f"{expid}_{sdate}_{member}_{chunk}_SIM_STAT_*")
    matches = glob.glob(pattern)
    if not matches:
        print(f"WARNING: no SIM STAT file matching {pattern}")
        return None

    # Take the most recently WRITTEN file (mtime), not the highest suffix. The
    # suffix is FAIL_COUNT and resets across experiment re-runs, so a stale
    # higher-numbered file can outrank this run's. Iterate newest-first and take
    # the first file with a valid start/end pair (skips a half-written file that
    # has the start line but not yet the end).
    def _mtime(path: str) -> float:
        try:
            return os.path.getmtime(path)
        except OSError:
            return -1.0

    for latest in sorted(matches, key=_mtime, reverse=True):
        try:
            with open(latest, encoding="utf-8") as handle:
                lines = [ln.strip() for ln in handle if ln.strip()]
            start_epoch = int(float(lines[0]))
            end_epoch = int(float(lines[1]))
        except (OSError, IndexError, ValueError) as exc:
            print(
                f"WARNING: could not read start/end from SIM STAT file {latest}: {exc}"
            )
            continue
        if end_epoch < start_epoch:
            print(
                f"WARNING: SIM STAT end {end_epoch} precedes start {start_epoch} "
                f"in {latest}; ignoring"
            )
            continue
        print(
            f"INFO: chunk wall time from SIM STAT {os.path.basename(latest)}: "
            f"start={start_epoch}, end={end_epoch} ({end_epoch - start_epoch}s)"
        )
        return start_epoch, end_epoch

    return None


def _sacct_time_to_epoch(value: Any) -> Optional[float]:
    """
    Convert a sacct ISO timestamp ('2026-05-29T18:02:55', local time) to an
    epoch. Returns None for empty / 'Unknown' / unparseable values.

    Interpreted as local time (naive .timestamp()), matching the SIM's
    `date +%s`, since both run on the cluster in the same timezone.
    """
    s = str(value).strip() if value is not None else ""
    if s in ("", "N/A", "Unknown"):
        return None
    try:
        return datetime.datetime.strptime(s, "%Y-%m-%dT%H:%M:%S").timestamp()
    except (ValueError, TypeError):
        return None


def _aggregate_step_rows(rows: List[Dict[str, str]]) -> Dict[str, Any]:
    """
    Aggregate already-selected sacct step rows into chunk-scoped metrics. The
    rows are chosen by aggregate_sacct_in_window (SIM_STAT end-time window).

    Aggregation rules:
      - Energy_Joules:       sum   (cumulative counter)
      - CPUTimeRAW_Seconds:  sum   (cumulative counter; this is the AGGREGATED,
                                    wrapper-cumulative value — the per-chunk
                                    value is recovered downstream by diffing
                                    consecutive chunks, see PerformanceMetrics)
      - MaxRSS_KB:           max   (peak across steps)
      - AveRSS_KB:           NTasks-weighted mean, mirroring the sstat-side
                             aggregator in monitor/slurm/sstat/aggregation
      - AllocCPUS:           max   (peak logical CPUs in use; physical cores
                                    derive from AllocCPUS / TPC downstream)
      - StartTime:           min   (earliest step start = chunk start)
      - EndTime:             max   (latest step end = chunk end)
      - Step_Count:          number of step rows matched

    NTasks is not aggregated here: the allocation-wide value comes from
    scontrol (Num_Tasks_Count) and is reported verbatim by the caller.
    """
    agg: Dict[str, Any] = {
        "Energy_Joules": 0.0,
        "CPUTimeRAW_Seconds": 0.0,
        "MaxRSS_KB": 0.0,
        "AveRSS_KB": 0.0,
        "AllocCPUS": 0,
        "StartTime": "",
        "EndTime": "",
        "Step_Count": 0,
        "Step_Ids": [],
    }
    if not rows:
        return agg

    def _f(v: Any) -> float:
        try:
            return float(v) if v not in (None, "", "N/A") else 0.0
        except (TypeError, ValueError):
            return 0.0

    def _i(v: Any) -> int:
        try:
            return int(v) if v not in (None, "", "N/A") else 0
        except (TypeError, ValueError):
            return 0

    def _ts(v: Any) -> str:
        # sacct emits "Unknown" for steps that haven't finished yet, and
        # empty strings for unset fields. Both must be excluded from the
        # min/max comparison — otherwise "Unknown" lex-sorts to the top
        # and shadows real timestamps.
        s = str(v).strip() if v is not None else ""
        if s in ("", "N/A", "Unknown"):
            return ""
        return s

    averss_weighted_sum = 0.0
    averss_weight_total = 0
    start_candidates: List[str] = []
    end_candidates: List[str] = []
    for r in rows:
        agg["Energy_Joules"] += _f(r.get("ConsumedEnergyRaw"))
        agg["CPUTimeRAW_Seconds"] += _f(r.get("CPUTimeRAW"))
        agg["MaxRSS_KB"] = max(agg["MaxRSS_KB"], extract_memory_kb(r.get("MaxRSS")))
        # ntasks is used only as the per-row weight for the AveRSS mean;
        # we do not aggregate it across steps (scontrol provides NTasks).
        ntasks = _i(r.get("NTasks"))
        agg["AllocCPUS"] = max(agg["AllocCPUS"], _i(r.get("AllocCPUS")))
        averss = extract_memory_kb(r.get("AveRSS"))
        if averss > 0 and ntasks > 0:
            averss_weighted_sum += averss * ntasks
            averss_weight_total += ntasks
        elif averss > 0:
            # No NTasks attached to this row — fall back to unweighted sample.
            averss_weighted_sum += averss
            averss_weight_total += 1
        # ISO-8601 timestamps are lexicographically sortable, so plain
        # min/max on the strings yields the correct chunk boundaries.
        s = _ts(r.get("Start"))
        if s:
            start_candidates.append(s)
        e = _ts(r.get("End"))
        if e:
            end_candidates.append(e)

    if averss_weight_total > 0:
        agg["AveRSS_KB"] = averss_weighted_sum / averss_weight_total
    if start_candidates:
        agg["StartTime"] = min(start_candidates)
    if end_candidates:
        agg["EndTime"] = max(end_candidates)
    agg["Step_Count"] = len(rows)
    agg["Step_Ids"] = sorted(str(r.get("JobID", "")) for r in rows)
    return agg


def _is_model_step_row(r: Dict[str, str]) -> bool:
    """
    True for a sacct row that is a model step we attribute to a chunk.

    Excludes the bare job-level row (no '.step' suffix), the allocation-wide
    .batch/.extern bookkeeping rows, and the monitor's housekeeping steps. The
    current monitor labels those resource_monitor_* (and the one-off lscpu TPC
    probe), but an older monitor ran per-sample srun without a job name, so its
    steps show up as 'bash'/'singularity' — excluded here too. No model launcher
    is named bash/singularity (ICON is 'mpmd.conf', IFS is the binary), so this
    only drops housekeeping and leaves the model step. Shared by the wrapper
    window aggregation and the non-wrapper all-steps aggregation.
    """
    jobid_field = str(r.get("JobID", ""))
    if "." not in jobid_field:
        return False
    if jobid_field.endswith((".batch", ".extern")):
        return False
    job_name = str(r.get("JobName", ""))
    if job_name in ("lscpu", "bash", "singularity"):
        return False
    if job_name.startswith("resource_monitor_"):
        return False
    return True


def aggregate_sacct_in_window(
    job_id: str, start_epoch: int, end_epoch: int
) -> Dict[str, Any]:
    """
    Discover and aggregate THIS chunk's model step rows straight from sacct,
    selecting steps whose End time lands inside the SIM_STAT [start, end]
    window.

    Selecting straight from sacct does NOT depend on the monitor having caught
    the step in a 60s sstat poll, so it recovers short steps (e.g. an 84s orted)
    the monitor missed. It stays chunk-scoped under a wrapper because each
    chunk's orted ends inside its own SIM job window, while the inflated per-step
    Start (collapsed to the allocation start) is deliberately NOT used for
    selection.

    Excludes the bare job-level row, the allocation-wide .batch/.extern rows,
    and the monitor's housekeeping steps (resource_monitor_* samplers and the
    one-off lscpu TPC probe).

    Args:
        job_id: Wrapper SLURM job id.
        start_epoch: Chunk start epoch from the SIM STAT file.
        end_epoch: Chunk end epoch from the SIM STAT file.

    Returns:
        Dict with the aggregated fields (see _aggregate_step_rows).
    """
    rc, out, err = run_sacct_for_job(job_id)
    if rc != 0 or not out.strip():
        print(
            f"WARNING: sacct failed/empty for job {job_id} during windowed "
            f"aggregation - rc={rc}, err={err.strip()}"
        )
        return _aggregate_step_rows([])

    rows: List[Dict[str, str]] = []
    for r in _parse_sacct_rows(out):
        if not _is_model_step_row(r):
            continue
        end_row = _sacct_time_to_epoch(r.get("End"))
        if end_row is None or not (start_epoch <= end_row <= end_epoch):
            continue
        rows.append(r)

    if not rows:
        print(
            f"WARNING: no sacct step rows for job {job_id} end within SIM_STAT "
            f"window [{start_epoch}, {end_epoch}]"
        )
    return _aggregate_step_rows(rows)


def _to_float(value: Any) -> float:
    """Lenient float coercion: empty / N/A / non-numeric → 0.0."""
    try:
        return float(str(value)) if value not in (None, "N/A", "") else 0.0
    except (TypeError, ValueError):
        return 0.0


def parse_gres_gpu_count(alloc_tres: Any) -> int:
    """
    Extract the allocated GPU count from a sacct AllocTRES string.

    AllocTRES looks like 'cpu=128,mem=224G,node=1,gres/gpu=4' — or typed, e.g.
    'gres/gpu:a100=4'. Sums every gres/gpu entry; returns 0 when there is none
    (CPU runs) or the field is empty.

    Args:
        alloc_tres: Raw AllocTRES value from sacct.

    Returns:
        int: Number of GPUs allocated.
    """
    s = str(alloc_tres or "")
    if not s or s in ("N/A", "Unknown"):
        return 0
    total = 0
    for m in re.finditer(r"gres/gpu[^=,]*=(\d+)", s):
        try:
            total += int(m.group(1))
        except ValueError:
            continue
    return total


def extract_memory_kb(mem_str: Any) -> float:
    """
    Extract a KB value from a SLURM memory string.

    sacct is queried with --noconvert (see run_sacct_for_job), so memory comes
    back as a raw byte count with no unit suffix. A bare number is therefore
    interpreted as BYTES and divided by 1024. Explicit K/M/G/T suffixes are
    still honoured as a fallback for any human-formatted input (older sacct,
    sstat snapshots, manual values).

    Args:
        mem_str: Memory string from SLURM (e.g. '10927778547', '12536725K').

    Returns:
        float: Memory in KB, or 0.0 if it cannot be parsed.
    """
    if not mem_str or mem_str == "N/A":
        return 0.0
    # Strip sacct's '+' truncation marker (only emitted in fixed-width, not -P,
    # output, but harmless to guard against).
    mem_str = str(mem_str).strip().rstrip("+")
    if not mem_str:
        return 0.0
    # K/M/G/T are SLURM binary (base-1024) units; K already maps to KB.
    multipliers = {
        "K": 1.0,
        "M": 1024.0,
        "G": 1024.0 * 1024.0,
        "T": 1024.0 * 1024.0 * 1024.0,
    }
    try:
        suffix = mem_str[-1].upper()
        if suffix in multipliers:
            return float(mem_str[:-1]) * multipliers[suffix]
        # Bare number: raw bytes (--noconvert) -> KB.
        return float(mem_str) / 1024.0
    except (ValueError, TypeError):
        return 0.0


def get_raw_info_from_sacct(
    job_id: str,
    monitor_metadata: Optional[Dict[str, Any]] = None,
    normalize_timestamp_func: Optional[Callable[[str], str]] = None,
    chunk_window: Optional[tuple[int, int]] = None,
) -> RawInfo:
    """
    Retrieve raw sacct information for the specified job.

    Chunk attribution:
      - chunk_window (SIM_STAT [start, end] from the Autosubmit log): the
        authoritative source. RunTime is end-start (immune to the wrapper's
        inflated per-step Elapsed) and the cumulative/peak fields aggregate
        exactly the model steps whose End lands inside the window — found
        directly in sacct. See aggregate_sacct_in_window.
      - Otherwise the job-level sacct record (legacy/standalone, no wrapper
        concerns).

    The wrapper-allocation fields (Nodes, NTasks, TPC) always come from scontrol
    via monitor_metadata because they describe the resources the chunk had
    available.

    Args:
        job_id: SLURM job id.
        monitor_metadata: Optional monitor metadata dict containing Job_Metadata.
        normalize_timestamp_func: Optional function to normalize timestamps (e.g., normalize_slurm_timestamp).
        chunk_window: Optional (start_epoch, end_epoch) from the SIM STAT file.
            Scopes sacct attribution to this chunk's steps.

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
        "Gpu_Count": 0,
        "Energy_Joules": 0.0,
        "CPUTimeRAW_Seconds": 0.0,
        "CPUTimeRAW_Aggregated_Seconds": 0.0,
        "RunTime": 0.0,
        "RunTime_Sim_Stat_Seconds": 0.0,
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

    record = parse_sacct_output(out, SACCT_FIELDS, preferred_job_id=job_id) or {}

    # Detect threads-per-core
    tpc = 1
    if monitor_metadata:
        # Get Threads_Per_Core_Count from Job_Metadata
        job_metadata = monitor_metadata.get("Job_Metadata", {})
        tpc_value = job_metadata.get("Threads_Per_Core_Count")

        if tpc_value and tpc_value > 0:
            tpc = int(tpc_value)

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

    # Chunk-attributed fields. The wrapper's job-level sacct row cannot isolate
    # a single chunk in shared-jobid mode, so when the SIM_STAT window is
    # available we attribute from the sacct step rows whose End lands inside it;
    # otherwise we fall back to the job-level record.
    chunk_start_raw = ""
    chunk_end_raw = ""
    if chunk_window:
        win_start, win_end = chunk_window
        windowed = aggregate_sacct_in_window(job_id, win_start, win_end)
        # RunTime/Start/End always come straight from the authoritative SIM_STAT
        # epochs — immune to the wrapper's inflated per-step Elapsed (the whole
        # reason we read SIM_STAT). NOT windowed["RunTime"] (max step Elapsed).
        elapsed_float = float(max(0, win_end - win_start))
        # Chunk Start/End rendered in the SLURM-style local ISO the downstream
        # normalizer expects.
        chunk_start_raw = datetime.datetime.fromtimestamp(win_start).strftime(
            "%Y-%m-%dT%H:%M:%S"
        )
        chunk_end_raw = datetime.datetime.fromtimestamp(win_end).strftime(
            "%Y-%m-%dT%H:%M:%S"
        )
        energy_float = windowed["Energy_Joules"]
        # AGGREGATED (wrapper-cumulative) CPUTimeRAW. The per-chunk value is
        # recovered downstream by subtracting the previous chunk's aggregate
        # (see PerformanceMetrics._resolve_actual_cpu_time).
        cputime_aggregated = windowed["CPUTimeRAW_Seconds"]
        maxrss_float = windowed["MaxRSS_KB"]
        averss_float = windowed["AveRSS_KB"]
        if alloc_cpus_i == 0 and windowed["AllocCPUS"] > 0:
            physical_parallelization = int(windowed["AllocCPUS"] / max(1, tpc))
        print(
            f"INFO: Chunk attribution from SIM_STAT window "
            f"({windowed['Step_Count']} step(s) {windowed['Step_Ids']}): "
            f"Energy_Joules={energy_float:.0f}, "
            f"CPUTimeRAW_Seconds(aggregated)={cputime_aggregated:.0f}, "
            f"RunTime={elapsed_float:.0f} (AS log), "
            f"MaxRSS_KB={maxrss_float:.0f}, "
            f"AveRSS_KB={averss_float:.0f}, "
            f"StartTime={chunk_start_raw}, "
            f"EndTime={chunk_end_raw}"
        )
    else:
        # Non-wrapper / standalone: the whole job is this chunk, so aggregate ALL
        # of its model step rows with the SAME filtering as the wrapper window
        # path (see _is_model_step_row). sacct never populates MaxRSS/AveRSS on
        # the job-level row, and the steps carry the real per-step peak, energy
        # and CPUTime — so the steps, not the job row, are the right source.
        # Elapsed has no SIM_STAT window here; take it from the job row Start/End.
        _se = _sacct_time_to_epoch(record.get("Start"))
        _ee = _sacct_time_to_epoch(record.get("End"))
        elapsed_float = float(_ee - _se) if (_se and _ee and _ee >= _se) else 0.0
        step_rows = [r for r in _parse_sacct_rows(out) if _is_model_step_row(r)]
        if step_rows:
            aggregated = _aggregate_step_rows(step_rows)
            energy_float = aggregated["Energy_Joules"]
            cputime_aggregated = aggregated["CPUTimeRAW_Seconds"]
            maxrss_float = aggregated["MaxRSS_KB"]
            averss_float = aggregated["AveRSS_KB"]
            if alloc_cpus_i == 0 and aggregated["AllocCPUS"] > 0:
                physical_parallelization = int(aggregated["AllocCPUS"] / max(1, tpc))
            print(
                f"INFO: standalone attribution from {aggregated['Step_Count']} "
                f"model step(s) {aggregated['Step_Ids']}: "
                f"Energy_Joules={energy_float:.0f}, "
                f"CPUTimeRAW_Seconds={cputime_aggregated:.0f}, "
                f"MaxRSS_KB={maxrss_float:.0f}, AveRSS_KB={averss_float:.0f}"
            )
        else:
            # No model step rows at all (e.g. a model launched via mpirun with no
            # srun .N steps). Fall back to the job-level cumulative row.
            energy_float = _to_float(record.get("ConsumedEnergyRaw"))
            cputime_aggregated = _to_float(record.get("CPUTimeRAW"))
            maxrss_float = extract_memory_kb(record.get("MaxRSS", "N/A"))
            averss_float = extract_memory_kb(record.get("AveRSS", "N/A"))
            print(
                "INFO: standalone mode — no model step rows in sacct; using the "
                "job-level cumulative row."
            )

    # Timestamps: chunk-scoped Start/End come from per-step aggregation when
    # available — the wrapper's job-level End is "Unknown" mid-allocation
    # (still-running siblings) so the job row would render as N/A. Submit
    # always comes from the job row (it's set at queue time, never per-step).
    start_raw = chunk_start_raw or record.get("Start", "N/A")
    end_raw = chunk_end_raw or record.get("End", "N/A")
    submit_raw = record.get("Submit", "N/A")
    if normalize_timestamp_func:
        start_time = normalize_timestamp_func(start_raw)
        end_time = normalize_timestamp_func(end_raw)
        submit_time = normalize_timestamp_func(submit_raw)
    else:
        start_time = start_raw
        end_time = end_raw
        submit_time = submit_raw

    # GPU count from the job-level AllocTRES (gres/gpu). Allocation-shape, so the
    # job row is the right source even under a wrapper (constant across chunks).
    gpu_count = parse_gres_gpu_count(record.get("AllocTRES"))

    # Construct dict with proper types
    raw: RawInfo = {
        "JobID": str(record.get("JobID", "N/A")),
        "JobName": str(record.get("JobName", "N/A")),
        "Parallelization": physical_parallelization,
        "Threads_Per_Core_Count": tpc,
        "Nodes": nodes_int,
        "NTasks": ntasks_int,
        "Gpu_Count": gpu_count,
        "Energy_Joules": energy_float,
        # Aggregated (wrapper-cumulative) CPUTimeRAW. CPUTimeRAW_Seconds (the
        # per-chunk value) starts equal to it and is replaced by
        # PerformanceMetrics._resolve_actual_cpu_time once the previous chunk's
        # aggregate is known.
        "CPUTimeRAW_Aggregated_Seconds": cputime_aggregated,
        "CPUTimeRAW_Seconds": cputime_aggregated,
        "RunTime": elapsed_float,
        "RunTime_Sim_Stat_Seconds": elapsed_float,
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
    Calculate simulated years between two dates (inclusive), accounting for
    leap years.

    Each calendar year covered by the chunk contributes its share as
    ``days_in_that_chunk_for_that_year / days_in_year`` where
    ``days_in_year`` is 366 for leap years and 365 otherwise. This keeps a
    full calendar year worth exactly 1.0 SY even when it has 366 days.

    Args:
        start_date_chunk: Start date 'yyyymmdd'.
        end_date_chunk: End date 'yyyymmdd' (inclusive).

    Returns:
        float: Simulated years summed per calendar year. 0.0 on error or
        when end precedes start.
    """
    import calendar

    try:
        s = datetime.datetime.strptime(start_date_chunk, "%Y%m%d").date()
        e = datetime.datetime.strptime(end_date_chunk, "%Y%m%d").date()
        if e < s:
            return 0.0

        total = 0.0
        current = s
        while current <= e:
            year = current.year
            year_end = datetime.date(year, 12, 31)
            segment_end = min(year_end, e)
            days_in_year = 366 if calendar.isleap(year) else 365
            days = (segment_end - current).days + 1
            total += days / days_in_year
            current = year_end + datetime.timedelta(days=1)
        return total
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
    notes: List[str] = []

    # Normalize and surface inputs eagerly so partial failures keep the
    # values that ARE known. Each field is populated only when its source
    # data resolves; anything that couldn't be computed stays at 0 with a
    # note explaining why.
    model_normalized = str(model).upper().replace("_", "-")
    resolution_str = str(resolution_km).strip()

    result: MemoryMetrics = {
        "Memory_Bloat_Ratio": 0.0,
        "RSS_Bytes": 0,
        "Binary_Size_Bytes": 0,
        "Restart_Size_Bytes": 0,
        "MPI_Tasks": 0,
        "Binary_Size_Per_Task_GB": 0.0,
        "Restart_Size_GB": 0.0,
        "Model": model_normalized,
        "Resolution": resolution_str,
        "Notes": notes,
    }

    try:
        # RSS — populate if available regardless of other failures
        if max_rss_kb and max_rss_kb > 0:
            result["RSS_Bytes"] = int(max_rss_kb * 1024)
        else:
            notes.append("No memory data available (MaxRSS_KB not found or zero)")

        # MPI tasks — populate if available
        if mpi_tasks and mpi_tasks > 0:
            result["MPI_Tasks"] = int(mpi_tasks)
        else:
            notes.append("No MPI tasks data available (required from Data Output Cost)")

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

        # Resolve restart size from model + resolution lookup
        restart_size_gb: Optional[float] = None
        if resolution_str in ("N/A", "", "None"):
            notes.append(f"Resolution not specified (got '{resolution_str}')")
        else:
            resolution_numeric = re.sub(r"[^\d]", "", resolution_str)
            if model_normalized in MODEL_RES_RESTART_GB:
                restart_size_gb = MODEL_RES_RESTART_GB[model_normalized].get(
                    resolution_str
                )
                if restart_size_gb is None and resolution_numeric:
                    restart_size_gb = MODEL_RES_RESTART_GB[model_normalized].get(
                        resolution_numeric
                    )
            if restart_size_gb is None:
                notes.append(
                    f"Unknown model/resolution combination: "
                    f"{model_normalized}/{resolution_str}"
                )

        if restart_size_gb is not None:
            result["Restart_Size_GB"] = float(restart_size_gb)
            result["Restart_Size_Bytes"] = int(restart_size_gb * (1024**3))

        # Resolve binary size from model (handle ICON's cpu/gpu dual entry)
        binary_size_gb: Optional[float] = None
        if model_normalized in MODEL_BINARY_GB:
            binary_size_entry = MODEL_BINARY_GB[model_normalized]
            if isinstance(binary_size_entry, dict):
                pu_normalized = str(processor_unit).lower()
                binary_size_gb = binary_size_entry.get(pu_normalized)
                if binary_size_gb is None:
                    binary_size_gb = binary_size_entry.get("cpu", 0.0)
                    notes.append(
                        f"Unknown processor_unit '{pu_normalized}' for "
                        f"{model_normalized}; defaulting to CPU binary size"
                    )
                else:
                    notes.append(
                        f"Using {pu_normalized.upper()} binary size for "
                        f"{model_normalized}"
                    )
            else:
                binary_size_gb = float(binary_size_entry)
        else:
            notes.append(f"No binary size entry for model {model_normalized}")

        if binary_size_gb is not None:
            result["Binary_Size_Per_Task_GB"] = float(binary_size_gb)
            if result["MPI_Tasks"] > 0:
                result["Binary_Size_Bytes"] = int(
                    binary_size_gb * (1024**3) * result["MPI_Tasks"]
                )

        # Memory_Bloat_Ratio on a consistent PER-TASK basis:
        #   (MaxRSS_per_task - binary_per_task) / restart_per_task
        # RSS_Bytes is already per-task (MaxRSS); Binary_Size_Bytes and
        # Restart_Size_Bytes are job totals, so divide both by MPI_Tasks. The old
        # formula subtracted the ALL-TASKS binary total from a single task's RSS
        # (mixing per-task with aggregate), which drove the ratio negative.
        # If any operand is missing the ratio stays at 0 and a note above
        # already explains which one was missing.
        if (
            result["RSS_Bytes"] > 0
            and result["Restart_Size_Bytes"] > 0
            and result["MPI_Tasks"] > 0
            and binary_size_gb is not None
        ):
            binary_per_task = result["Binary_Size_Bytes"] / result["MPI_Tasks"]
            restart_per_task = result["Restart_Size_Bytes"] / result["MPI_Tasks"]
            numerator = result["RSS_Bytes"] - binary_per_task
            result["Memory_Bloat_Ratio"] = float(numerator) / float(restart_per_task)

        return result

    except Exception as e:
        notes.append(f"Unexpected error calculating memory bloat: {str(e)}")
        return result


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

    current_dt = start_dt
    while current_dt <= end_dt:
        current_date_str = current_dt.strftime("%Y%m%d")

        # The model token's case varies across models in the FDB store (e.g.
        # ICON is uppercase, ifs-nemo lowercase), so try the model as given plus
        # upper/lower and stop at the first that exists for this date (so the
        # same day isn't counted twice under two case variants).
        for model_token in dict.fromkeys([model, model.upper(), model.lower()]):
            folder_name = f"{class_val}:{dataset}:{activity}:{experiment}:{generation}:{model_token}:{realization}:{expver}:{stream}:{current_date_str}"

            matched = False
            for root_path in valid_paths:
                full_path = os.path.join(root_path, folder_name)
                dirs_checked += 1

                if os.path.exists(full_path) and os.path.isdir(full_path):
                    found_any_data = True
                    dirs_found += 1
                    matched = True
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
                    except (
                        subprocess.CalledProcessError,
                        ValueError,
                        IndexError,
                    ) as e:
                        return (0, f"Error calculating size for {full_path}: {str(e)}")

            if matched:
                break

        current_dt += datetime.timedelta(days=1)

    if not found_any_data:
        print(
            f"WARNING: No FDB output data found after checking {dirs_checked} directories"
        )
        print(f"WARNING: Searched in paths - {valid_paths}")
        print(
            f"WARNING: Expected folder pattern - {class_val}:{dataset}:{activity}:{experiment}:{generation}:<{model}|{model.upper()}>:{realization}:{expver}:{stream}:YYYYMMDD"
        )
        return (
            0,
            f"No FDB output data found (checked {dirs_checked} directories). Data may not be written yet or paths are incorrect",
        )

    return (int(total_size_bytes), None)


def calculate_number_of_grid_points(grid_atm: str) -> int:
    """
    Estimate the number of grid points based on atmospheric grid resolution.

    Supports two grid families:
    - IFS Gaussian/octahedral (e.g. 'tco79l137'): (truncation * 8) * levels.
    - ICON icosahedral (e.g. 'r2b8'): 20 * root^2 * 4^bisections horizontal
      cells. ICON grid strings carry no vertical-level token, so this is the
      horizontal cell count only (not multiplied by levels like the IFS path).

    Args:
        grid_atm: Atmospheric grid resolution string (e.g., 'tco79l137', 'r2b8').

    Returns:
        int: Estimated number of grid points, or 0 if unknown/invalid.
    """
    try:
        if not grid_atm:
            return 0

        s = str(grid_atm).lower()

        # ICON icosahedral grid R<r>B<b> (e.g. r2b8): triangular cell count =
        # 20 * r^2 * 4^b — 20 icosahedron faces, root division r^2, then b edge
        # bisections (x4 each). r2b8 -> 5,242,880 (~10 km), r2b9 -> ~21M (~5 km).
        icon_match = re.search(r"r(\d+)b(\d+)", s)
        if icon_match:
            root = int(icon_match.group(1))
            bisections = int(icon_match.group(2))
            return 20 * (root**2) * (4**bisections)

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

    Core_Hours derives from the PER-CHUNK CPUTimeRAW (raw_info["CPUTimeRAW_Seconds"]),
    which PerformanceMetrics has already de-inflated by differencing consecutive
    chunks (sacct's raw per-step CPUTimeRAW is wrapper-cumulative). It is in
    logical core-seconds, so divide by TPC for physical cores and by 3600 for
    hours.

    Args:
        raw_info: RawInfo with CPUTimeRAW_Seconds (per-chunk, logical
            core-seconds) and Threads_Per_Core_Count.
        simulated_years: Simulated years.

    Returns:
        CpuMetrics: CPU metrics with Core_Hours and Core_Hours_Per_Simulated_Year (CHSY).
    """
    tpc = int(raw_info.get("Threads_Per_Core_Count", 1) or 1)
    if tpc < 1:
        tpc = 1
    try:
        cpu_time_raw_seconds = float(raw_info.get("CPUTimeRAW_Seconds", 0.0) or 0.0)
    except Exception:
        cpu_time_raw_seconds = 0.0

    # Logical core-seconds → physical core-hours.
    core_hours = (
        (cpu_time_raw_seconds / tpc) / 3600.0 if cpu_time_raw_seconds > 0 else 0.0
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
            "Memory_Bloat_Ratio": 0.0,
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
    gpu_hours: float = 0.0,
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
        gpu_hours: Total GPU hours for the chunk (Gpu_Count x wall hours); 0.0
            on CPU runs. Used for the bytes-per-GPU-hour intensity.

    Returns:
        StorageMetrics: Storage metrics with Total_Output_Bytes,
        Data_Intensity_Bytes_Per_Core_Hour, Data_Intensity_Bytes_Per_Gpu_Hour,
        and Notes.
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
    data_intensity_gpu = (storage_size_bytes / gpu_hours) if gpu_hours > 0 else 0.0

    return {
        "Total_Output_Bytes": int(storage_size_bytes),
        "Data_Intensity_Bytes_Per_Core_Hour": data_intensity,
        "Data_Intensity_Bytes_Per_Gpu_Hour": data_intensity_gpu,
        "Notes": notes,
    }


def calculate_data_output_cost_metrics(
    rundir_path: str,
    model: str,
    nodes: int = 0,
    tasks_per_node: int = 0,
    threads: int = 1,
    threads_per_core: int = 1,
    io_config: Optional[Dict[str, Any]] = None,
) -> DataOutputCostMetrics:
    """
    Calculate Data Output Cost performance metrics from model output files.

    Uses the io_analyzer component to parse timing and I/O statistics
    from the rundir (pie.csv and timing.output for IFS-NEMO).

    Args:
        rundir_path: Path to model run directory.
        model: Model name.
        nodes: Total number of compute nodes allocated.
        tasks_per_node: Number of tasks per node.
        threads: Number of OpenMP threads per task.
        threads_per_core: Number of hardware threads per physical core.
        io_config: I/O layout bundled per component (IFS/NEMO/FESOM {tasks,nodes,ppn}
            and ICON {atm_compute_tasks,oce_tasks,yaco_tasks}); forwarded to the
            parser, which expands it (see ModelParser).

    Returns:
        DataOutputCostMetrics: Data Output Cost metrics with Times, Percentages,
            Components, Resources, and Notes.
        Resources are populated when IO allocation configuration is provided;
        they default to 0 when configuration is missing or IO analysis fails.
    """
    notes: List[str] = []

    # Initialize default values (N/A case) - everything starts at 0 and we
    # fill in whatever we can compute below. Resources only need the
    # configured I/O variables + allocation shape — they DO NOT require
    # pie.csv, so we populate them even when timing parsing fails.
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
        "Components": {},
        "Notes": notes,
    }

    # Attempt to populate Resources from configured inputs regardless of
    # rundir / pie.csv state. We do this first so any later failure still
    # leaves the computed MPI_Tasks / Physical_Cores visible to consumers.
    def _populate_resources_from_inputs() -> None:
        try:
            from io_analyzer import PARSERS
        except ImportError as exc:
            notes.append(
                f"io_analyzer module not available for Resources fallback: {exc}"
            )
            return

        parser_cls = PARSERS.get(str(model).lower())
        if parser_cls is None:
            notes.append(
                f"No parser registered for model '{model}'; "
                f"Resources cannot be derived from inputs"
            )
            return

        try:
            parser = parser_cls(
                rundir_path=rundir_path or ".",
                nodes=nodes,
                tasks_per_node=tasks_per_node,
                threads=threads,
                threads_per_core=threads_per_core,
                io_config=io_config,
            )
            res = parser._extract_resource_metrics()
        except Exception as exc:
            notes.append(
                f"Could not derive Resources from inputs ({type(exc).__name__}): {exc}"
            )
            return

        compute_tasks = int(res.get("compute_tasks", 0) or 0)
        io_tasks = int(res.get("io_tasks", 0) or 0)
        total_tasks = int(res.get("total_tasks", 0) or 0)
        default_metrics["Resources"]["Compute"] = {
            "MPI_Tasks": compute_tasks,
            "Physical_Cores": parser._calculate_physical_cores(compute_tasks),
        }
        default_metrics["Resources"]["IO"] = {
            "MPI_Tasks": io_tasks,
            "Physical_Cores": parser._calculate_physical_cores(io_tasks),
        }
        default_metrics["Resources"]["Total"] = {
            "MPI_Tasks": total_tasks,
            "Physical_Cores": parser._calculate_physical_cores(total_tasks),
        }
        for n in res.get("allocation_notes", []) or []:
            if n not in notes:
                notes.append(n)

    _populate_resources_from_inputs()

    # Check if rundir is available for the full timing analysis
    if not rundir_path or rundir_path == "N/A":
        notes.append(
            "Run directory path not provided - timing metrics unavailable; "
            "Resources reported from configured inputs"
        )
        return default_metrics

    if not os.path.exists(rundir_path):
        notes.append(
            f"Run directory does not exist: {rundir_path}; "
            f"Resources reported from configured inputs"
        )
        return default_metrics

    if not os.path.isdir(rundir_path):
        notes.append(
            f"Run directory path is not a directory: {rundir_path}; "
            f"Resources reported from configured inputs"
        )
        return default_metrics

    # Import io_analyzer module
    try:
        from io_analyzer import analyze_io
    except ImportError as e:
        notes.append(f"io_analyzer module not available: {str(e)}")
        return default_metrics

    # Use the analyze_io function with all parameters
    try:
        io_results = analyze_io(
            rundir_path=rundir_path,
            model_name=model,
            nodes=nodes,
            tasks_per_node=tasks_per_node,
            threads=threads,
            threads_per_core=threads_per_core,
            io_config=io_config,
        )

        # io_analyzer now emits CamelCase keys natively (see
        # io_analyzer/parsers/base_parser.IOMetrics), so the dataclass
        # fields map 1:1 onto DataOutputCostMetrics. Merge analyze_io's
        # notes with any provenance already accumulated above.
        merged_notes = list(notes) + [
            n for n in (io_results.notes or []) if n not in notes
        ]
        from typing import cast

        result: DataOutputCostMetrics = {
            "Resources": cast(Dict[str, ResourceAllocation], io_results.resources),
            "Times": cast(TimeAllocation, io_results.times),
            "Percentages": cast(PercentageMetrics, io_results.percentages),
            "Components": cast(Dict[str, ComponentBreakdown], io_results.components),
            "Notes": merged_notes,
        }
        return result

    except FileNotFoundError as e:
        notes.append(
            f"Required data output analysis files not found: {str(e)}; "
            f"Resources reported from configured inputs"
        )
        return default_metrics
    except ValueError as e:
        notes.append(
            f"Error parsing data output data: {str(e)}; "
            f"Resources reported from configured inputs"
        )
        return default_metrics
    except Exception as e:
        notes.append(
            f"Unexpected error analyzing Data Output Cost metrics: {str(e)}; "
            f"Resources reported from configured inputs"
        )
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

    # Linear model is keyed only by (model, hpc); tasks_per_node is reported
    # back to the consumer but does not affect coefficient selection.
    slope = hpc_config["slope"]
    intercept = hpc_config["intercept"]

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
    io_config: Optional[Dict[str, Any]] = None,
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
        io_config: I/O layout bundled per component (IFS/NEMO/FESOM {tasks,nodes,ppn}
            and ICON {atm_compute_tasks,oce_tasks,yaco_tasks}); forwarded to the
            io_analyzer, which expands it (see ModelParser).
        threads: Number of OpenMP threads per task.
        processor_unit: Processor type ('cpu' or 'gpu').

    Returns:
        PerformanceSummary: Complete PerformanceSummary structure with all metrics.
    """
    # Calculate simulated years
    sy = calculate_simulated_years(start_date_chunk, end_date_chunk)

    # Extract runtime. RunTime is the CPUTime-derived model-compute wall span
    # (PerformanceMetrics._resolve_runtime), used for SYPD/QSYPD. GPU hours use
    # the SIM_STAT full-allocation wall time (RunTime_Sim_Stat_Seconds).
    runtime_seconds = float(raw_info.get("RunTime", 0) or 0)
    try:
        runtime_seconds = float(runtime_seconds)
    except Exception:
        runtime_seconds = 0.0
    sim_stat_runtime_seconds = float(
        raw_info.get("RunTime_Sim_Stat_Seconds", runtime_seconds) or runtime_seconds
    )

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

    # GPU metrics from SLURM accounting (gres/gpu in sacct AllocTRES). Zero for
    # CPU runs, which carry no gres/gpu. Uses the SIM_STAT full-allocation wall
    # time (not the CPUTime-derived compute span) per the GPU convention.
    gpu_count = int(raw_info.get("Gpu_Count", 0) or 0)
    gpu_hours = gpu_count * (sim_stat_runtime_seconds / 3600.0)
    gpu_metrics: GpuMetrics = {
        "Gpu_Count": gpu_count,
        "Gpu_Hours": round(gpu_hours, 2),
        "Gpu_Hours_Per_Simulated_Year": round(gpu_hours / sy, 2) if sy > 0 else 0.0,
    }

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
        gpu_hours=gpu_hours,
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
        threads_per_core=threads_per_core,
        io_config=io_config,
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

    # ICON (and any model that computes tasks-per-node inside its runscript,
    # not via SLURM --ntasks-per-node) reaches here with tasks_per_node=0 from
    # the env file. Derive it from the total task count / node count so
    # Sequential_Coupling_Cost (and any per-node metric) is valid.
    if tasks_per_node <= 0 and nodes > 0:
        total_tasks_doc = (
            data_output_cost_metrics.get("Resources", {})
            .get("Total", {})
            .get("MPI_Tasks", 0)
        )
        if total_tasks_doc > 0:
            tasks_per_node = total_tasks_doc // nodes

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
        "Gpu": gpu_metrics,
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
    member: str,
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
        member: Ensemble member identifier.
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
            "Member": member,
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
        # Per-chunk (differenced) value, and the aggregated/cumulative value the
        # NEXT chunk reads to take its own difference (wrapper case).
        "CPUTimeRAW_Seconds": raw_info.get("CPUTimeRAW_Seconds"),
        "CPUTimeRAW_Aggregated_Seconds": raw_info.get("CPUTimeRAW_Aggregated_Seconds"),
        # RunTime_Seconds is the CPUTime-derived compute span used for SYPD;
        # RunTime_Sim_Stat_Seconds is the SIM_STAT full-allocation wall time.
        "RunTime_Seconds": float(raw_info.get("RunTime", 0)),
        "RunTime_Sim_Stat_Seconds": float(raw_info.get("RunTime_Sim_Stat_Seconds", 0)),
        "Queue_Time_Seconds": queue_time_seconds,
        "MaxRSS_KB": raw_info.get("MaxRSS_KB"),
        "AveRSS_KB": raw_info.get("AveRSS_KB"),
        "Notes": notes,
    }
    return metadata
