"""
Base parser class for climate model I/O analysis.

This abstract class defines the interface that all model-specific parsers must implement.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Dict, List, Optional, TypedDict


class ResourceMetrics(TypedDict):
    """Type definition for resource allocation metrics."""

    mpi_tasks: int
    physical_cores: int


class TimeMetrics(TypedDict):
    """Type definition for time-based metrics."""

    time_seconds: float
    percentage: float


class ComponentMetrics(TypedDict):
    """Type definition for per-component breakdown."""

    compute: TimeMetrics
    io: TimeMetrics
    total: float
    resources: ResourceMetrics


@dataclass
class IOMetrics:
    """
    Container for I/O metrics extracted from model outputs.

    This dataclass uses nested dictionaries to organize metrics hierarchically
    and avoid redundancy. Structure:
    - resources: MPI tasks and physical cores (compute, io, total)
    - times: Time measurements in seconds (compute, io, overhead, total)
    - percentages: Relative metrics (io_time, io_resources)
    - overhead: Efficiency metrics (factor, cost_node_hours)
    - components: Per-component breakdown
    - metadata: Model name and notes
    """

    # Nested resource metrics (MPI tasks and physical cores)
    resources: Dict[str, ResourceMetrics]  # Keys: 'compute', 'io', 'total'

    # Nested time metrics in seconds
    times: Dict[str, float]  # Keys: 'compute', 'io', 'overhead', 'total'

    # Percentage metrics (0-100)
    percentages: Dict[str, float]  # Keys: 'io_time', 'io_resources'

    # Overhead and cost metrics
    overhead: Dict[str, float]  # Keys: 'factor', 'cost_node_hours'

    # Per-component breakdown (e.g., IFS, NEMO)
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
    ):
        """
        Initialize the parser with the run directory path and resource configuration.

        Args:
            rundir_path: Path to the model run directory containing output files.
            nodes: Total number of compute nodes allocated.
            tasks_per_node: Number of tasks per node.
            threads: Number of OpenMP threads per task.
            ifs_io_tasks: Number of IFS I/O tasks (task-based allocation).
            nemo_io_tasks: Number of NEMO I/O tasks (task-based allocation).
            ifs_io_nodes: Number of IFS I/O nodes (node-based allocation).
            nemo_io_nodes: Number of NEMO I/O nodes (node-based allocation).
            ifs_io_ppn: IFS I/O processes per node (node-based allocation).
            nemo_io_ppn: NEMO I/O processes per node (node-based allocation).
            fesom_io_tasks: Number of FESOM I/O tasks (task-based allocation).
            fesom_io_nodes: Number of FESOM I/O nodes (node-based allocation).
            fesom_io_ppn: FESOM I/O processes per node (node-based allocation).
            threads_per_core: Number of hardware threads per physical core (hyperthreading).
        """
        self.rundir_path = rundir_path
        self.nodes = nodes
        self.tasks_per_node = tasks_per_node
        self.threads = threads
        self.ifs_io_tasks = ifs_io_tasks
        self.nemo_io_tasks = nemo_io_tasks
        self.ifs_io_nodes = ifs_io_nodes
        self.nemo_io_nodes = nemo_io_nodes
        self.ifs_io_ppn = ifs_io_ppn
        self.nemo_io_ppn = nemo_io_ppn
        self.fesom_io_tasks = fesom_io_tasks
        self.fesom_io_nodes = fesom_io_nodes
        self.fesom_io_ppn = fesom_io_ppn
        self.threads_per_core = threads_per_core
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
                "compute": {
                    "mpi_tasks": compute_tasks,
                    "physical_cores": compute_cores,
                },
                "io": {"mpi_tasks": io_tasks, "physical_cores": io_cores},
                "total": {"mpi_tasks": total_tasks, "physical_cores": total_cores},
            },
            times={
                "compute": compute_time,
                "io": io_time,
                "total": total_time,
            },
            percentages={
                "compute_time": compute_percentage_time,
                "io_time": io_percentage_time,
                "compute_resources": compute_percentage_resources,
                "io_resources": io_percentage_resources,
            },
            overhead={
                "serialization_factor": serialization_factor,
                "wasted_node_hours": wasted_node_hours,
            },
            components=components,
            notes=notes,
        )
