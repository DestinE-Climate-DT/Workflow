"""
Base parser class for climate model I/O analysis.

This abstract class defines the interface that all model-specific parsers must implement.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Dict, List, Optional, TypedDict


class ResourceMetrics(TypedDict):
    """Type definition for resource allocation metrics."""

    MPI_Tasks: int
    Physical_Cores: int


class TimeMetrics(TypedDict):
    """Type definition for time-based metrics."""

    Time_Seconds: float
    Percentage: float


class ComponentMetrics(TypedDict):
    """Type definition for per-component breakdown."""

    Compute: TimeMetrics
    IO: TimeMetrics
    Total: float
    Resources: ResourceMetrics


@dataclass
class IOMetrics:
    """
    Container for I/O metrics extracted from model outputs.

    All keys are CamelCase to match the DataOutputCostMetrics external
    contract emitted by utils_performance.calculate_data_output_cost_metrics.

    Structure:
    - resources:    {Compute, IO, Total} -> {MPI_Tasks, Physical_Cores}
    - times:        {Compute, IO, Total} -> seconds (float)
    - percentages:  {Compute_Time, IO_Time, Compute_Resources, IO_Resources}
    - overhead:     {Serialization_Factor, Wasted_Node_Hours}
    - components:   per-component breakdown (e.g. IFS, NEMO, FESOM, ATM, ...)
    - notes:        free-form provenance / warning messages
    """

    # Nested resource metrics (MPI tasks and physical cores).
    # Keys: 'Compute', 'IO', 'Total'.
    resources: Dict[str, ResourceMetrics]

    # Nested time metrics in seconds. Keys: 'Compute', 'IO', 'Total'.
    times: Dict[str, float]

    # Percentage metrics (0-100). Keys: 'Compute_Time', 'IO_Time',
    # 'Compute_Resources', 'IO_Resources'.
    percentages: Dict[str, float]

    # Overhead and cost metrics.
    # Keys: 'Serialization_Factor', 'Wasted_Node_Hours'.
    overhead: Dict[str, float]

    # Per-component breakdown (e.g., IFS, NEMO).
    components: Dict[str, ComponentMetrics]

    # Additional notes about the analysis
    notes: List[str] = field(default_factory=list)


class ModelParser(ABC):
    """Abstract base class for model-specific parsers."""

    def __init__(
        self,
        rundir_path: str,
        nodes: int = 0,
        tasks_per_node: int = 0,
        threads: int = 1,
        threads_per_core: int = 1,
        io_config: Optional[Dict[str, Dict[str, int]]] = None,
    ):
        """
        Initialize the parser with the run directory path and resource configuration.

        Args:
            rundir_path: Path to the model run directory containing output files.
            nodes: Total number of compute nodes allocated.
            tasks_per_node: Number of tasks per node.
            threads: Number of OpenMP threads per task.
            threads_per_core: Number of hardware threads per physical core (hyperthreading).
            io_config: I/O layout bundled per component. The IFS/NEMO/FESOM
                entries ({"tasks","nodes","ppn"}) are expanded into the
                individual self.<comp>_io_<field> attributes the concrete parsers
                read. The ICON entry ({"atm_compute_tasks","oce_tasks",
                "yaco_tasks"}, captured by the SIM at runtime with the real
                SLURM_GPUS_ON_NODE) is exposed as self.icon_resources, which
                ICONParser reads directly; when absent it reports zero tasks.
        """
        self.rundir_path = rundir_path
        self.nodes = nodes
        self.tasks_per_node = tasks_per_node
        self.threads = threads
        self.threads_per_core = threads_per_core

        # Expand the bundled I/O layout into the per-component attributes the
        # concrete parsers read. ICON's explicit task counts are exposed as-is.
        io_config = io_config or {}

        def _io(component: str, field: str) -> int:
            try:
                return int((io_config.get(component) or {}).get(field, 0) or 0)
            except (TypeError, ValueError):
                return 0

        self.ifs_io_tasks = _io("IFS", "tasks")
        self.ifs_io_nodes = _io("IFS", "nodes")
        self.ifs_io_ppn = _io("IFS", "ppn")
        self.nemo_io_tasks = _io("NEMO", "tasks")
        self.nemo_io_nodes = _io("NEMO", "nodes")
        self.nemo_io_ppn = _io("NEMO", "ppn")
        self.fesom_io_tasks = _io("FESOM", "tasks")
        self.fesom_io_nodes = _io("FESOM", "nodes")
        self.fesom_io_ppn = _io("FESOM", "ppn")
        self.icon_resources = io_config.get("ICON") or {}
        self.model_name = self._get_model_name()

    @abstractmethod
    def _get_model_name(self) -> str:
        """
        Return the name of the model.
        Args:
            None
        Returns:
            str: Model name (e.g., 'IFS-NEMO').
        """
        pass

    @abstractmethod
    def parse(self) -> IOMetrics:
        """
        Parse model output files and extract I/O metrics.
        Args:
            None
        Returns:
            IOMetrics object containing all calculated metrics.

        Raises:
            FileNotFoundError: If required files are not found.
            ValueError: If files contain invalid or unexpected data.
        """
        pass

    @abstractmethod
    def _extract_time_metrics(self) -> Dict[str, float]:
        """
        Extract time-based metrics from model output files.
        Args:
            None
        Returns:
            Dictionary with keys: 'io_time', 'total_time', and component-specific times.
        """
        pass

    @abstractmethod
    def _extract_resource_metrics(self) -> Dict[str, int]:
        """
        Extract resource allocation metrics from model output files.
        Args:
            None
        Returns:
            Dictionary with keys: 'compute_tasks', 'io_tasks', 'total_tasks'.
        """
        pass

    def _calculate_physical_cores(self, mpi_tasks: int) -> int:
        """
        Calculate physical cores from MPI tasks.

        Formula: physical_cores = (mpi_tasks × threads_per_task) / threads_per_core

        Args:
            mpi_tasks: Number of MPI tasks.

        Returns:
            Number of physical cores.
        """
        if mpi_tasks == 0 or self.threads_per_core == 0:
            return 0
        return int((mpi_tasks * self.threads) / self.threads_per_core)

    def _calculate_metrics(
        self,
        time_metrics: Dict[str, float],
        resource_metrics: Dict[str, int],
        components: Dict[str, ComponentMetrics],
        notes: Optional[List[str]] = None,
    ) -> IOMetrics:
        """
        Calculate all I/O metrics from extracted data.

        Args:
            time_metrics: Dictionary with time-based measurements ('io_time', 'total_time', 'compute_time')
            resource_metrics: Dictionary with resource allocation data ('compute_tasks', 'io_tasks', 'total_tasks')
            components: Dictionary with per-component breakdown
            notes: Optional list of notes about limitations or issues

        Returns:
            IOMetrics object with all calculated values in structured format
        """
        if notes is None:
            notes = []

        # Extract time values
        io_time = time_metrics["io_time"]
        total_time = time_metrics["total_time"]
        compute_time = time_metrics.get("compute_time", total_time - io_time)

        # Extract resource values
        compute_tasks = resource_metrics["compute_tasks"]
        io_tasks = resource_metrics["io_tasks"]
        total_tasks = resource_metrics["total_tasks"]

        # Calculate physical cores
        compute_cores = self._calculate_physical_cores(compute_tasks)
        io_cores = self._calculate_physical_cores(io_tasks)
        total_cores = self._calculate_physical_cores(total_tasks)

        # Calculate percentages
        compute_percentage_time = (
            (compute_time / total_time * 100) if total_time > 0 else 0.0
        )
        io_percentage_time = (io_time / total_time * 100) if total_time > 0 else 0.0
        compute_percentage_resources = (
            (compute_tasks / total_tasks * 100) if total_tasks > 0 else 0.0
        )
        io_percentage_resources = (
            (io_tasks / total_tasks * 100) if total_tasks > 0 else 0.0
        )

        # Calculate serialization factor: how much slower due to I/O overhead
        # Example: 1.5 means 50% slower, 2.0 means 100% slower (2x time)
        serialization_factor = (total_time / compute_time) if compute_time > 0 else 1.0

        # Calculate wasted node-hours due to I/O overhead
        # This is time when compute resources are idle or doing I/O instead of compute
        overhead_time = total_time - compute_time
        if self.tasks_per_node > 0:
            total_nodes = total_tasks / self.tasks_per_node
            wasted_node_hours = total_nodes * (overhead_time / 3600.0)
        else:
            wasted_node_hours = 0.0

        return IOMetrics(
            resources={
                "Compute": {
                    "MPI_Tasks": compute_tasks,
                    "Physical_Cores": compute_cores,
                },
                "IO": {"MPI_Tasks": io_tasks, "Physical_Cores": io_cores},
                "Total": {"MPI_Tasks": total_tasks, "Physical_Cores": total_cores},
            },
            times={
                "Compute": compute_time,
                "IO": io_time,
                "Total": total_time,
            },
            percentages={
                "Compute_Time": compute_percentage_time,
                "IO_Time": io_percentage_time,
                "Compute_Resources": compute_percentage_resources,
                "IO_Resources": io_percentage_resources,
            },
            overhead={
                "Serialization_Factor": serialization_factor,
                "Wasted_Node_Hours": wasted_node_hours,
            },
            components=components,
            notes=notes,
        )
