"""
Parser for IFS-FESOM coupled climate model.

Extracts I/O metrics from:
- pie.csv: Component timing breakdown including IFS, the ocean component
  (labeled "NEMO" in the file even under IFS-FESOM — model-side bug), and I/O
- ifs.out: FESOM's per-task runtime table printed at finalization, whose
  "runtime output" row gives the FESOM I/O (output) time.
"""

import csv
import os
import re
from typing import Dict, Any

from .base_parser import IOMetrics, ModelParser, ComponentMetrics


class IFSFESOMParser(ModelParser):
    """Parser for IFS-FESOM coupled model output files."""

    def _get_model_name(self) -> str:
        """
        Return the name of the model.

        Args:
            None

        Returns:
            str: Model name 'IFS-FESOM'.
        """
        return "IFS-FESOM"

    def parse(self) -> IOMetrics:
        """
        Parse IFS-FESOM output files and extract I/O metrics.

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

        fesom_total_time = time_metrics.get("fesom_total_time", 0.0)
        fesom_io_time = time_metrics.get("fesom_io_time", 0.0)
        fesom_compute_time = time_metrics.get("fesom_compute_time", 0.0)
        fesom_io_pct = (
            (fesom_io_time / fesom_total_time * 100) if fesom_total_time > 0 else 0.0
        )
        fesom_compute_pct = 100.0 - fesom_io_pct

        # Calculate physical cores for each component
        ifs_compute_cores = self._calculate_physical_cores(
            resource_metrics.get("ifs_compute_tasks", 0)
        )
        fesom_compute_cores = self._calculate_physical_cores(
            resource_metrics.get("fesom_compute_tasks", 0)
        )

        components: Dict[str, ComponentMetrics] = {
            "IFS": {
                "Compute": {
                    "Time_Seconds": ifs_compute_time,
                    "Percentage": ifs_compute_pct,
                },
                "IO": {
                    "Time_Seconds": ifs_io_time,
                    "Percentage": ifs_io_pct,
                },
                "Total": ifs_total_time,
                "Resources": {
                    "MPI_Tasks": resource_metrics.get("ifs_compute_tasks", 0),
                    "Physical_Cores": ifs_compute_cores,
                },
            },
            "FESOM": {
                "Compute": {
                    "Time_Seconds": fesom_compute_time,
                    "Percentage": fesom_compute_pct,
                },
                "IO": {
                    "Time_Seconds": fesom_io_time,
                    "Percentage": fesom_io_pct,
                },
                "Total": fesom_total_time,
                "Resources": {
                    "MPI_Tasks": resource_metrics.get("fesom_compute_tasks", 0),
                    "Physical_Cores": fesom_compute_cores,
                },
            },
        }

        # Add notes about allocation mode and shared compute tasks
        notes = resource_metrics.get("allocation_notes", [])
        if not isinstance(notes, list):
            notes = []
        notes.append("FESOM I/O time from ifs.out 'runtime output' (mean across tasks)")
        notes.append("Compute tasks are shared between IFS and FESOM in coupled mode")

        # Remove temporary keys from resource_metrics for calculate_metrics
        resource_metrics_clean = {
            "compute_tasks": resource_metrics["compute_tasks"],
            "io_tasks": resource_metrics["io_tasks"],
            "total_tasks": resource_metrics["total_tasks"],
        }

        # Add compute time for overhead calculation
        time_metrics["compute_time"] = ifs_compute_time + fesom_compute_time

        return self._calculate_metrics(
            time_metrics, resource_metrics_clean, components, notes
        )

    def _extract_time_metrics(self) -> Dict[str, float]:
        """
        Extract time metrics from pie.csv.

        Time calculation:
        - IFS time = sum(all components) - "I/O" - "NEMO" (from pie.csv)
        - IFS I/O time = "I/O" component (from pie.csv)
        - FESOM total time = "NEMO" component (from pie.csv — see note)
        - FESOM I/O time = "runtime output" (mean across tasks, from ifs.out)
        - FESOM compute time = FESOM total - FESOM I/O
        - Coupled total time = sum(all components from pie.csv)

        Note: IFS-FESOM writes the ocean-component row to pie.csv under the
        label "NEMO" (model-side bug — the IFS pie.csv writer hard-codes the
        ocean label regardless of which ocean model is coupled). We read
        "NEMO" here and report it as FESOM downstream.

        Args:
            None

        Returns:
            Dict[str, float]: Dictionary with timing data for IFS and FESOM.

        Raises:
            FileNotFoundError: If required files (pie.csv, ifs.out) are not found.
            ValueError: If required data cannot be extracted.
        """
        metrics: Dict[str, float] = {}

        # Parse component timing from pie.csv
        pie_csv_path = os.path.join(self.rundir_path, "pie.csv")
        if not os.path.exists(pie_csv_path):
            raise FileNotFoundError(f"pie.csv not found at {pie_csv_path}")

        component_times = self._parse_pie_csv(pie_csv_path)

        # Extract key components
        # IFS-FESOM mislabels the ocean component as "NEMO" in pie.csv
        # (model-side bug). Read "NEMO" and surface it as FESOM downstream.
        ifs_io_time = component_times.get("I/O", 0.0)
        fesom_total_time = component_times.get("NEMO", 0.0)
        total_time = sum(component_times.values())

        # Calculate IFS time: all components except I/O and the ocean row
        ifs_time = total_time - ifs_io_time - fesom_total_time

        if ifs_time < 0:
            raise ValueError(
                f"Calculated IFS time is negative ({ifs_time:.2f}s). "
                f"Total: {total_time:.2f}s, I/O: {ifs_io_time:.2f}s, "
                f"FESOM (labeled NEMO in pie.csv): {fesom_total_time:.2f}s"
            )

        # FESOM I/O time from ifs.out ("runtime output", mean across tasks),
        # mirroring how IFS-NEMO reads iom_put_p3d_dp from timing.output.
        fesom_io_time = self._extract_fesom_io_time()

        # FESOM compute time = ocean total (pie.csv) - FESOM I/O (ifs.out).
        fesom_compute_time = fesom_total_time - fesom_io_time

        if fesom_compute_time < 0:
            raise ValueError(
                f"Calculated FESOM compute time is negative "
                f"({fesom_compute_time:.2f}s). FESOM total: {fesom_total_time:.2f}s, "
                f"FESOM I/O: {fesom_io_time:.2f}s"
            )

        # Store metrics
        metrics["ifs_io_time"] = ifs_io_time
        metrics["ifs_total_time"] = ifs_time
        metrics["fesom_io_time"] = fesom_io_time
        metrics["fesom_compute_time"] = fesom_compute_time
        metrics["fesom_total_time"] = fesom_total_time
        metrics["coupled_total_time"] = total_time

        # Combined metrics
        metrics["io_time"] = ifs_io_time + fesom_io_time
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

        # Validate required components.
        # The ocean row is "NEMO" even under IFS-FESOM (model writer bug).
        required_components = {"I/O", "NEMO"}
        missing = required_components - set(component_times.keys())
        if missing:
            raise ValueError(
                f"pie.csv missing required components: {', '.join(missing)}"
            )

        return component_times

    def _extract_fesom_io_time(self) -> float:
        """
        Extract FESOM I/O time from ifs.out.

        At finalization FESOM prints a per-task runtime table:

            ___MODEL RUNTIME per task [seconds]___mean______min______max_
            ...
            runtime output:        0.0921     0.0824     0.0977

        We take the mean column (the first value) — the average across tasks —
        mirroring the IFS-NEMO parser, which reads the average-per-processor
        iom_put_p3d_dp time from timing.output.

        Args:
            None

        Returns:
            float: FESOM I/O (output) time in seconds (mean across tasks).

        Raises:
            FileNotFoundError: If ifs.out is not found.
            ValueError: If the 'runtime output' line cannot be found.
        """
        ifs_out_path = os.path.join(self.rundir_path, "ifs.out")
        if not os.path.exists(ifs_out_path):
            raise FileNotFoundError(f"ifs.out not found at {ifs_out_path}")

        with open(ifs_out_path, "r") as f:
            content = f.read()

        # Line: "  runtime output:   <mean>   <min>   <max>"; take the mean.
        match = re.search(r"runtime output:\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)", content)
        if not match:
            raise ValueError("Could not find 'runtime output' time in ifs.out")

        return float(match.group(1))

    def _extract_resource_metrics(self) -> Dict[str, Any]:
        """
        Extract resource allocation from configuration passed at initialization.

        Supports three I/O allocation modes:
        1. Task-based: Specific number of I/O tasks (ifs_io_tasks, fesom_io_tasks)
        2. Node-based: Full nodes dedicated to I/O (ifs_io_nodes, fesom_io_nodes with ppn)
        3. Auto-calculated: Only IFS_IO_NODES defined, FESOM uses half of IFS resources

        Detection logic:
        - If ifs_io_tasks > 0 or fesom_io_tasks > 0: Use task-based allocation
        - Else if ifs_io_nodes > 0 and fesom_io_nodes > 0: Use node-based allocation
        - Else if ifs_io_nodes > 0 and fesom_io_nodes == 0: Use auto-calculated mode
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
        task_based = self.ifs_io_tasks > 0 or self.fesom_io_tasks > 0
        node_based = self.ifs_io_nodes > 0 and self.fesom_io_nodes > 0
        auto_calculated = (
            self.ifs_io_nodes > 0
            and self.fesom_io_nodes == 0
            and self.fesom_io_tasks == 0
        )

        if task_based:
            # CASE 1: Task-based allocation mode
            notes.append(
                f"I/O allocation mode: task-based "
                f"(IFS I/O tasks: {self.ifs_io_tasks}, FESOM I/O tasks: {self.fesom_io_tasks})"
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
            fesom_io_tasks = self.fesom_io_tasks
            total_io_tasks = ifs_io_tasks + fesom_io_tasks

            # Compute tasks (shared between IFS and FESOM in coupled mode)
            compute_tasks = total_tasks - total_io_tasks

            if compute_tasks <= 0:
                raise ValueError(
                    f"Invalid compute tasks: total={total_tasks}, "
                    f"I/O={total_io_tasks} (IFS={ifs_io_tasks}, FESOM={fesom_io_tasks})"
                )

        elif node_based:
            # CASE 2: Node-based allocation mode
            notes.append(
                f"I/O allocation mode: node-based "
                f"(IFS I/O: {self.ifs_io_nodes} nodes × {self.ifs_io_ppn} ppn, "
                f"FESOM I/O: {self.fesom_io_nodes} nodes × {self.fesom_io_ppn} ppn)"
            )

            # Calculate I/O tasks from nodes
            ifs_io_tasks = self.ifs_io_nodes * self.ifs_io_ppn
            fesom_io_tasks = self.fesom_io_nodes * self.fesom_io_ppn
            total_io_tasks = ifs_io_tasks + fesom_io_tasks

            # Total tasks = compute nodes × tasks_per_node + I/O tasks
            # Compute nodes = total nodes - I/O nodes
            io_nodes = self.ifs_io_nodes + self.fesom_io_nodes
            compute_nodes = self.nodes - io_nodes

            if compute_nodes < 0:
                raise ValueError(
                    f"Invalid compute nodes: total_nodes={self.nodes}, "
                    f"I/O_nodes={io_nodes} (IFS={self.ifs_io_nodes}, FESOM={self.fesom_io_nodes})"
                )

            compute_tasks = compute_nodes * self.tasks_per_node
            total_tasks = compute_tasks + total_io_tasks

            notes.append(
                f"Physical distribution: {compute_nodes} compute nodes + "
                f"{self.ifs_io_nodes} IFS I/O nodes + {self.fesom_io_nodes} FESOM I/O nodes = "
                f"{self.nodes} total nodes"
            )

        elif auto_calculated:
            # CASE 3: Auto-calculated mode (only IFS_IO_NODES defined)
            # Calculate I/O tasks: IFS_IO_NODES * CPUS_ON_NODE / CPUS_PER_TASK / 2
            # Split evenly between IFS and FESOM

            # Calculate total CPUs per node from tasks_per_node and threads
            cpus_per_task = self.threads
            cpus_on_node = self.tasks_per_node * cpus_per_task

            # Total I/O tasks from IFS nodes, split in half
            total_io_tasks_from_nodes = (
                self.ifs_io_nodes * cpus_on_node // cpus_per_task
            )
            ifs_io_tasks = total_io_tasks_from_nodes // 2
            fesom_io_tasks = total_io_tasks_from_nodes // 2
            total_io_tasks = ifs_io_tasks + fesom_io_tasks

            notes.append(
                f"I/O allocation mode: auto-calculated "
                f"(IFS_IO_NODES={self.ifs_io_nodes}, split evenly: "
                f"IFS I/O tasks={ifs_io_tasks}, FESOM I/O tasks={fesom_io_tasks})"
            )

            # Compute nodes = total nodes - I/O nodes
            io_nodes = self.ifs_io_nodes
            compute_nodes = self.nodes - io_nodes

            if compute_nodes <= 0:
                raise ValueError(
                    f"Invalid compute nodes in auto-calculated mode: "
                    f"total_nodes={self.nodes}, I/O_nodes={io_nodes}"
                )

            compute_tasks = compute_nodes * self.tasks_per_node
            total_tasks = compute_tasks + total_io_tasks

            notes.append(
                f"Physical distribution: {compute_nodes} compute nodes + "
                f"{io_nodes} I/O nodes (auto) = {self.nodes} total nodes"
            )
            notes.append(
                f"Auto-calculated I/O distribution: "
                f"{cpus_on_node} CPUs/node, {cpus_per_task} CPUs/task → "
                f"{total_io_tasks_from_nodes} total I/O tasks split equally"
            )

        else:
            raise ValueError(
                "No I/O allocation configuration provided. "
                "Either set ifs_io_tasks/fesom_io_tasks (task-based), "
                "ifs_io_nodes/fesom_io_nodes with ifs_io_ppn/fesom_io_ppn (node-based), "
                "or just ifs_io_nodes (auto-calculated mode)"
            )

        # In coupled IFS-FESOM, compute tasks are shared between both models
        return {
            "compute_tasks": compute_tasks,
            "io_tasks": total_io_tasks,
            "total_tasks": total_tasks,
            "ifs_compute_tasks": compute_tasks,
            "fesom_compute_tasks": compute_tasks,
            "ifs_io_tasks": ifs_io_tasks,
            "fesom_io_tasks": fesom_io_tasks,
            "allocation_notes": notes,
        }
