"""
Parser for IFS-NEMO coupled climate model.

Extracts I/O metrics from:
- pie.csv: Component timing breakdown including IFS, NEMO, and I/O
- timing.output: NEMO I/O timing statistics (iom_put_p3d_dp)
"""

import csv
import os
import re
from typing import Dict, Any

from .base_parser import IOMetrics, ModelParser, ComponentMetrics


class IFSNEMOParser(ModelParser):
    """Parser for IFS-NEMO coupled model output files."""

    def _get_model_name(self) -> str:
        """
        Return the name of the model.

        Args:
            None

        Returns:
            str: Model name 'IFS-NEMO'.
        """
        return "IFS-NEMO"

    def parse(self) -> IOMetrics:
        """
        Parse IFS-NEMO output files and extract I/O metrics.

        Args:
            None

        Returns:
            IOMetrics: Object with all calculated metrics.

        Raises:
            FileNotFoundError: If required files are not found.
            ValueError: If files contain invalid data.
        """
        time_metrics = self._extract_time_metrics()
        resource_metrics = self._extract_resource_metrics()

        # Build component breakdown with proper structure
        ifs_compute_time = time_metrics.get("ifs_total_time", 0.0)
        ifs_io_time = time_metrics.get("ifs_io_time", 0.0)
        ifs_total_time = ifs_compute_time + ifs_io_time
        ifs_io_pct = (ifs_io_time / ifs_total_time * 100) if ifs_total_time > 0 else 0.0
        ifs_compute_pct = 100.0 - ifs_io_pct

        nemo_compute_time = time_metrics.get("nemo_compute_time", 0.0)
        nemo_io_time = time_metrics.get("nemo_io_time", 0.0)
        nemo_total_time = time_metrics.get("nemo_total_time", 0.0)
        nemo_io_pct = (
            (nemo_io_time / nemo_total_time * 100) if nemo_total_time > 0 else 0.0
        )
        nemo_compute_pct = 100.0 - nemo_io_pct

        # Calculate physical cores for each component
        ifs_compute_cores = self._calculate_physical_cores(
            resource_metrics.get("ifs_compute_tasks", 0)
        )
        nemo_compute_cores = self._calculate_physical_cores(
            resource_metrics.get("nemo_compute_tasks", 0)
        )

        components: Dict[str, ComponentMetrics] = {
            "IFS": {
                "compute": {
                    "time_seconds": ifs_compute_time,
                    "percentage": ifs_compute_pct,
                },
                "io": {
                    "time_seconds": ifs_io_time,
                    "percentage": ifs_io_pct,
                },
                "total": ifs_total_time,
                "resources": {
                    "mpi_tasks": resource_metrics.get("ifs_compute_tasks", 0),
                    "physical_cores": ifs_compute_cores,
                },
            },
            "NEMO": {
                "compute": {
                    "time_seconds": nemo_compute_time,
                    "percentage": nemo_compute_pct,
                },
                "io": {
                    "time_seconds": nemo_io_time,
                    "percentage": nemo_io_pct,
                },
                "total": nemo_total_time,
                "resources": {
                    "mpi_tasks": resource_metrics.get("nemo_compute_tasks", 0),
                    "physical_cores": nemo_compute_cores,
                },
            },
        }

        # Add notes about allocation mode and shared compute tasks
        notes = resource_metrics.get("allocation_notes", [])
        if not isinstance(notes, list):
            notes = []
        notes.append("Compute tasks are shared between IFS and NEMO in coupled mode")

        # Remove temporary keys from resource_metrics for calculate_metrics
        resource_metrics_clean = {
            "compute_tasks": resource_metrics["compute_tasks"],
            "io_tasks": resource_metrics["io_tasks"],
            "total_tasks": resource_metrics["total_tasks"],
        }

        # Add compute time for overhead calculation
        time_metrics["compute_time"] = ifs_compute_time + nemo_compute_time

        return self._calculate_metrics(
            time_metrics, resource_metrics_clean, components, notes
        )

    def _extract_time_metrics(self) -> Dict[str, float]:
        """
        Extract time metrics from pie.csv and timing.output.

        Time calculation:
        - IFS time = sum(all components) - "I/O" - "NEMO" (from pie.csv)
        - IFS I/O time = "I/O" component (from pie.csv)
        - NEMO total time = "NEMO" component (from pie.csv)
        - NEMO I/O time = iom_put_p3d_dp time (from timing.output)
        - NEMO compute time = NEMO total - NEMO I/O
        - Coupled total time = sum(all components from pie.csv)

        Args:
            None

        Returns:
            Dict[str, float]: Dictionary with timing data for IFS and NEMO.

        Raises:
            FileNotFoundError: If required files are not found.
            ValueError: If required data cannot be extracted.
        """
        metrics: Dict[str, float] = {}

        # Parse component timing from pie.csv
        pie_csv_path = os.path.join(self.rundir_path, "pie.csv")
        if not os.path.exists(pie_csv_path):
            raise FileNotFoundError(f"pie.csv not found at {pie_csv_path}")

        component_times = self._parse_pie_csv(pie_csv_path)

        # Extract key components
        ifs_io_time = component_times.get("I/O", 0.0)
        nemo_total_time = component_times.get("NEMO", 0.0)
        total_time = sum(component_times.values())

        # Calculate IFS compute time: all components except I/O and NEMO
        ifs_compute_time = total_time - ifs_io_time - nemo_total_time

        if ifs_compute_time < 0:
            raise ValueError(
                f"Calculated IFS compute time is negative ({ifs_compute_time:.2f}s). "
                f"Total: {total_time:.2f}s, I/O: {ifs_io_time:.2f}s, "
                f"NEMO: {nemo_total_time:.2f}s"
            )

        # Parse NEMO I/O timing from timing.output
        nemo_io_time = self._extract_nemo_io_time()

        # Calculate NEMO compute time
        nemo_compute_time = nemo_total_time - nemo_io_time

        if nemo_compute_time < 0:
            raise ValueError(
                f"Calculated NEMO compute time is negative ({nemo_compute_time:.2f}s). "
                f"NEMO total: {nemo_total_time:.2f}s, NEMO I/O: {nemo_io_time:.2f}s"
            )

        # Store metrics
        metrics["ifs_io_time"] = ifs_io_time
        metrics["ifs_total_time"] = (
            ifs_compute_time  # IFS compute time (renamed for clarity)
        )
        metrics["nemo_io_time"] = nemo_io_time
        metrics["nemo_compute_time"] = nemo_compute_time
        metrics["nemo_total_time"] = nemo_total_time
        metrics["coupled_total_time"] = total_time

        # Combined metrics
        metrics["io_time"] = ifs_io_time + nemo_io_time
        metrics["total_time"] = total_time

        return metrics

    def _parse_pie_csv(self, pie_csv_path: str) -> Dict[str, float]:
        """
        Parse pie.csv file to extract component times.

        Expected format:
        #label,time,fraction
        "PHYSICS",147.5,15.9
        "RADIATION",102.4,11.0
        ...

        Args:
            pie_csv_path: Path to pie.csv file.

        Returns:
            Dict[str, float]: Dictionary mapping component names to times in seconds.

        Raises:
            ValueError: If CSV format is invalid or data cannot be parsed.
        """
        component_times: Dict[str, float] = {}

        try:
            with open(pie_csv_path, "r") as f:
                # Read first line to detect if header starts with #
                first_line = f.readline()
                f.seek(0)  # Reset to beginning

                # If the header starts with #, remove it for proper CSV parsing
                if first_line.strip().startswith("#"):
                    # Read all lines
                    lines = f.readlines()
                    # Remove # from the first line
                    lines[0] = lines[0].lstrip("#")
                    # Create a StringIO object for csv.DictReader
                    from io import StringIO

                    f_clean = StringIO("".join(lines))
                    reader = csv.DictReader(f_clean)
                else:
                    reader = csv.DictReader(f)

                # Validate header
                if not reader.fieldnames or "label" not in reader.fieldnames:
                    raise ValueError("pie.csv missing required 'label' column")
                if "time" not in reader.fieldnames:
                    raise ValueError("pie.csv missing required 'time' column")

                for row in reader:
                    label = row["label"].strip().strip('"')
                    time_str = row["time"].strip()

                    try:
                        time_value = float(time_str)
                    except ValueError:
                        raise ValueError(
                            f"Invalid time value '{time_str}' for component '{label}'"
                        )

                    component_times[label] = time_value

        except csv.Error as e:
            raise ValueError(f"Failed to parse pie.csv: {e}")

        if not component_times:
            raise ValueError("pie.csv contains no data rows")

        # Validate required components
        required_components = {"I/O", "NEMO"}
        missing = required_components - set(component_times.keys())
        if missing:
            raise ValueError(
                f"pie.csv missing required components: {', '.join(missing)}"
            )

        return component_times

    def _extract_nemo_io_time(self) -> float:
        """
        Extract NEMO I/O time from timing.output.

        Looks for iom_put_p3d_dp in the detailed timing section.

        Args:
            None

        Returns:
            float: NEMO I/O time in seconds.

        Raises:
            FileNotFoundError: If timing.output not found.
            ValueError: If required data cannot be extracted.
        """
        timing_path = os.path.join(self.rundir_path, "timing.output")
        if not os.path.exists(timing_path):
            raise FileNotFoundError(f"timing.output not found at {timing_path}")

        with open(timing_path, "r") as f:
            content = f.read()

        # Look for iom_put_p3d_dp in the detailed timing section
        # Format: iom_put_p3d_dp    12.664    2.155    119.917    2.630    9.469    29760
        # The first numeric value is the average time per processor
        iom_match = re.search(
            r"iom_put_p3d_dp\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)", content
        )

        if not iom_match:
            raise ValueError("Could not find iom_put_p3d_dp time in timing.output")

        return float(iom_match.group(1))

    def _extract_resource_metrics(self) -> Dict[str, Any]:
        """
        Extract resource allocation from configuration passed at initialization.

        Supports three I/O allocation modes:
        1. Task-based: Specific number of I/O tasks (ifs_io_tasks, nemo_io_tasks)
        2. Node-based: Full nodes dedicated to I/O (ifs_io_nodes, nemo_io_nodes with ppn)
        3. Auto-calculated: Only IFS_IO_NODES defined, NEMO uses half of IFS resources

        Detection logic:
        - If ifs_io_tasks > 0 or nemo_io_tasks > 0: Use task-based allocation
        - Else if ifs_io_nodes > 0 and nemo_io_nodes > 0: Use node-based allocation
        - Else if ifs_io_nodes > 0 and nemo_io_nodes == 0: Use auto-calculated mode
        - Else: Error - no I/O configuration provided

        Args:
            None

        Returns:
            Dict: Dictionary with compute and I/O task counts, includes allocation_notes.

        Raises:
            ValueError: If resource configuration is invalid.
        """
        notes = []

        # Detect allocation mode
        task_based = self.ifs_io_tasks > 0 or self.nemo_io_tasks > 0
        node_based = self.ifs_io_nodes > 0 and self.nemo_io_nodes > 0
        auto_calculated = (
            self.ifs_io_nodes > 0
            and self.nemo_io_nodes == 0
            and self.nemo_io_tasks == 0
        )

        if task_based:
            # CASE 1: Task-based allocation mode
            notes.append(
                f"I/O allocation mode: task-based "
                f"(IFS I/O tasks: {self.ifs_io_tasks}, NEMO I/O tasks: {self.nemo_io_tasks})"
            )

            # Total tasks allocated
            total_tasks = self.nodes * self.tasks_per_node

            if total_tasks <= 0:
                raise ValueError(
                    f"Invalid total tasks: nodes={self.nodes}, "
                    f"tasks_per_node={self.tasks_per_node}"
                )

            # I/O tasks
            ifs_io_tasks = self.ifs_io_tasks
            nemo_io_tasks = self.nemo_io_tasks
            total_io_tasks = ifs_io_tasks + nemo_io_tasks

            # Compute tasks (shared between IFS and NEMO in coupled mode)
            compute_tasks = total_tasks - total_io_tasks

            if compute_tasks <= 0:
                raise ValueError(
                    f"Invalid compute tasks: total={total_tasks}, "
                    f"I/O={total_io_tasks} (IFS={ifs_io_tasks}, NEMO={nemo_io_tasks})"
                )

        elif node_based:
            # CASE 2: Node-based allocation mode
            notes.append(
                f"I/O allocation mode: node-based "
                f"(IFS I/O: {self.ifs_io_nodes} nodes × {self.ifs_io_ppn} ppn, "
                f"NEMO I/O: {self.nemo_io_nodes} nodes × {self.nemo_io_ppn} ppn)"
            )

            # Calculate I/O tasks from nodes
            ifs_io_tasks = self.ifs_io_nodes * self.ifs_io_ppn
            nemo_io_tasks = self.nemo_io_nodes * self.nemo_io_ppn
            total_io_tasks = ifs_io_tasks + nemo_io_tasks

            # Total tasks = compute nodes × tasks_per_node + I/O tasks
            # Compute nodes = total nodes - I/O nodes
            io_nodes = self.ifs_io_nodes + self.nemo_io_nodes
            compute_nodes = self.nodes - io_nodes

            if compute_nodes <= 0:
                raise ValueError(
                    f"Invalid compute nodes: total_nodes={self.nodes}, "
                    f"I/O_nodes={io_nodes}"
                )

            compute_tasks = compute_nodes * self.tasks_per_node
            total_tasks = compute_tasks + total_io_tasks

            notes.append(
                f"Physical distribution: {compute_nodes} compute nodes + "
                f"{self.ifs_io_nodes} IFS I/O nodes + {self.nemo_io_nodes} NEMO I/O nodes = "
                f"{self.nodes} total nodes"
            )

        elif auto_calculated:
            # CASE 3: Auto-calculated mode (only IFS_IO_NODES defined)
            # Calculate I/O tasks: IFS_IO_NODES * CPUS_ON_NODE / CPUS_PER_TASK / 2
            # Split evenly between IFS and NEMO

            # Calculate total CPUs per node from tasks_per_node and threads
            cpus_per_task = self.threads
            cpus_on_node = self.tasks_per_node * cpus_per_task

            # Total I/O tasks from IFS nodes, split in half
            total_io_tasks_from_nodes = (
                self.ifs_io_nodes * cpus_on_node // cpus_per_task
            )
            ifs_io_tasks = total_io_tasks_from_nodes // 2
            nemo_io_tasks = total_io_tasks_from_nodes // 2
            total_io_tasks = ifs_io_tasks + nemo_io_tasks

            notes.append(
                f"I/O allocation mode: auto-calculated "
                f"(IFS_IO_NODES={self.ifs_io_nodes}, split evenly: "
                f"IFS={ifs_io_tasks} tasks, NEMO={nemo_io_tasks} tasks)"
            )

            notes.append(
                f"Calculation: {self.ifs_io_nodes} nodes × {cpus_on_node} CPUs ÷ "
                f"{cpus_per_task} CPUs/task ÷ 2 = {ifs_io_tasks} tasks per model"
            )

            # Compute tasks
            total_tasks = self.nodes * self.tasks_per_node
            compute_tasks = total_tasks - total_io_tasks

            if compute_tasks <= 0:
                raise ValueError(
                    f"Invalid compute tasks: total={total_tasks}, I/O={total_io_tasks}"
                )

        else:
            raise ValueError(
                "No I/O allocation configuration provided. "
                "Either set ifs_io_tasks/nemo_io_tasks (task-based), "
                "ifs_io_nodes/nemo_io_nodes with ppn (node-based), "
                "or ifs_io_nodes alone (auto-calculated)"
            )

        # In coupled IFS-NEMO, compute tasks are shared between both models
        return {
            "compute_tasks": compute_tasks,
            "io_tasks": total_io_tasks,
            "total_tasks": total_tasks,
            "ifs_compute_tasks": compute_tasks,
            "nemo_compute_tasks": compute_tasks,
            "ifs_io_tasks": ifs_io_tasks,
            "nemo_io_tasks": nemo_io_tasks,
            "allocation_notes": notes,
        }
