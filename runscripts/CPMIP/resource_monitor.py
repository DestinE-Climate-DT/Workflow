import argparse
import os
import time
from typing import Optional, List

# Import from new modular monitor package
from .monitor import (
    collect_job_metadata,
    collect_node_stats,
    collect_sstat_steps,
    aggregate_sstat_steps,
    now_timestamp,
    save_json_gz,
    job_is_active,
)


# --------------------------------------------------------------------------------------
# Monitor class
# --------------------------------------------------------------------------------------


class ResourceMonitor:
    """
    Main monitor loop for a single job. Uses TPC from the FIRST allocated node only.
    pidstat and sstat are collected on independent schedules.
    """

    def __init__(
        self,
        job_id: str,
        frequency_seconds: int,
        slurm_frequency_seconds: int,
        output_dir: str,
        pidstat_path: str,
        container_sif: Optional[str] = None,
    ) -> None:
        """
        Initialize ResourceMonitor instance.
        Args:
            job_id: SLURM job ID to monitor.
            frequency_seconds: Pidstat sampling frequency in seconds.
            slurm_frequency_seconds: Sstat sampling frequency in seconds.
            output_dir: Directory for output files.
            pidstat_path: Path to pidstat binary.
            container_sif: Optional path to Singularity container SIF file.
        Returns:
            None
        """
        self.job_id = job_id
        self.frequency_seconds = max(5, int(frequency_seconds))
        self.slurm_frequency_seconds = max(60, int(slurm_frequency_seconds))
        self.output_dir = output_dir
        self.pidstat_path = pidstat_path
        self.container_sif = container_sif

        self.metadata_dir = os.path.join(self.output_dir, "metadata")
        self.sstat_steps_dir = os.path.join(self.output_dir, "sstat", "steps")
        self.sstat_aggregated_dir = os.path.join(self.output_dir, "sstat", "aggregated")
        self.pidstat_nodes_dir = os.path.join(self.output_dir, "pidstat", "nodes")

        self.node_list: List[str] = []
        self.threads_per_core: int = 1
        self.account: str = ""
        self.job_mem_limit_bytes: int = 0  # Job memory limit from SLURM metadata

    # ------------------------------- lifecycle ---------------------------------

    def _write_metadata_start(self) -> None:
        """
        Read scontrol once using collect_job_metadata from monitor module.
        Auto-detects TPC and extracts job memory limit for pidstat calculations.
        Args:
            None
        Returns:
            None
        """

        try:
            metadata = collect_job_metadata(self.job_id, threads_per_core=None)

            # Extract node list, TPC, account, and memory limit
            self.node_list = metadata.get("Allocated_Node_List", {}).get("Nodes", [])
            self.threads_per_core = metadata.get("Threads_Per_Core_Count", 1)
            self.account = metadata.get("Account", "")

            # Extract job memory limit from TRES_Allocated (if available)
            tres_allocated = metadata.get("Tres_Allocated", {})
            self.job_mem_limit_bytes = tres_allocated.get("Mem_Bytes", 0)

            ts_epoch, ts_iso = now_timestamp()
            start = {
                "Timestamp_Epoch": ts_epoch,
                "Timestamp_ISO_Local": ts_iso,
                "Job_Metadata": metadata,
            }

            save_json_gz(os.path.join(self.metadata_dir, "start.json.gz"), start)
        except Exception as e:
            print(f"WARNING: Failed to collect start metadata - {e}")

    def _write_metadata_end(self) -> None:
        """
        Read scontrol once more when finishing using collect_job_metadata from monitor module.
        Args:
            None
        Returns:
            None
        """

        try:
            metadata = collect_job_metadata(
                self.job_id, threads_per_core=self.threads_per_core
            )

            ts_epoch, ts_iso = now_timestamp()
            end = {
                "Timestamp_Epoch": ts_epoch,
                "Timestamp_ISO_Local": ts_iso,
                "Job_Metadata": metadata,
            }
            save_json_gz(os.path.join(self.metadata_dir, "end.json.gz"), end)
        except Exception as e:
            print(f"WARNING: Failed to collect end metadata - {e}")

    # ------------------------------- sampling ----------------------------------

    def _write_sstat_snapshot(self) -> None:
        """
        Collect sstat for all steps, save processed steps, and save aggregated metrics.

        Follows the legacy flow:
        1. Collect raw sstat data
        2. Process each step into ProcessedStepStats (normalized types/units)
        3. Save each processed step individually
        4. Aggregate all steps into summary metrics
        5. Save aggregated metrics

        Args:
            None
        Returns:
            None
        """
        # Collect and process all steps (returns ProcessedStepStats for each)
        processed_steps = collect_sstat_steps(self.job_id)
        if not processed_steps:
            return

        ts_epoch, ts_iso = now_timestamp()

        # Save each processed step individually
        for step_id, step_stats in processed_steps.items():
            step_payload = {
                "Job_Id": self.job_id,
                "Step_Id": step_id,
                "Timestamp_Epoch": ts_epoch,
                "Timestamp_ISO_Local": ts_iso,
                "Threads_Per_Core_Count": self.threads_per_core,
                "Step_Statistics": step_stats,
            }
            step_path = os.path.join(
                self.sstat_steps_dir, f"{step_id}_{ts_iso}.json.gz"
            )
            save_json_gz(step_path, step_payload)

        # Calculate aggregated metrics using monitor module
        try:
            aggregated_stats = aggregate_sstat_steps(processed_steps, self.job_id)
            aggregated_payload = {
                "Job_Id": self.job_id,
                "Timestamp_Epoch": ts_epoch,
                "Timestamp_ISO_Local": ts_iso,
                "Threads_Per_Core_Count": self.threads_per_core,
                "Total_Steps": len(processed_steps),
                "Aggregated_Metrics": aggregated_stats,
            }

            agg_path = os.path.join(
                self.sstat_aggregated_dir, f"aggregated_{ts_iso}.json.gz"
            )
            save_json_gz(agg_path, aggregated_payload)
        except Exception as e:
            print(f"WARNING: Failed to calculate aggregated metrics - {e}")

    def _write_pidstat_snapshots(self) -> None:
        """
        Best-effort pidstat capture per node using collect_node_stats from monitor module.
        Uses srun --overlap --jobid for accurate per-node statistics.
        Each node gets its own subdirectory: pidstat/nodes/{node_name}/{timestamp}.json.gz
        Job memory limit is passed from metadata to enable Memory_Percent_Of_Job_Limit calculation.
        If container_sif is provided, pidstat will be executed inside the container.
        Args:
            None
        Returns:
            None
        """
        if not self.pidstat_path or not self.node_list:
            return

        ts_epoch, ts_iso = now_timestamp()

        try:
            # Use the robust collection function from monitor module
            all_node_stats = collect_node_stats(
                node_list=self.node_list,
                pidstat_path=self.pidstat_path,
                jobid=self.job_id,
                account=self.account if self.account else None,
                job_mem_limit_bytes=self.job_mem_limit_bytes,
                threads_per_core=self.threads_per_core,
                container_sif=self.container_sif,
            )

            # Save each node's statistics in its own subdirectory
            for node, node_stats in all_node_stats.items():
                # Create node-specific directory
                node_dir = os.path.join(self.pidstat_nodes_dir, node)
                os.makedirs(node_dir, exist_ok=True)

                # Save with timestamp filename only (node is in the directory path)
                out_path = os.path.join(node_dir, f"{ts_iso}.json.gz")
                payload = {
                    "Job_Id": self.job_id,
                    "Node": node,
                    "Threads_Per_Core_Count": self.threads_per_core,
                    "Timestamp_Epoch": ts_epoch,
                    "Timestamp_ISO_Local": ts_iso,
                    "Node_Statistics": node_stats,
                }
                save_json_gz(out_path, payload)
        except Exception as e:
            print(f"WARNING: Failed to collect pidstat data - {e}")

    # ------------------------------- main loop ---------------------------------

    def run(self) -> None:
        """
        Main long-running loop with two independent schedules.
        Collects sstat every slurm_frequency_seconds and pidstat every frequency_seconds.
        Pre-checks the job before any sampling cycle; if the job is finished, finalizes and exits.
        Args:
            None
        Returns:
            None
        """
        self._write_metadata_start()

        # Trigger both on the first loop iteration
        last_pidstat = 0.0
        last_sstat = 0.0

        while True:
            # Pre-check: if job is finished, finalize and exit
            if not job_is_active(self.job_id):
                self._write_metadata_end()
                return

            now = time.time()
            did_work = False

            # sstat cadence
            if now - last_sstat >= self.slurm_frequency_seconds:
                self._write_sstat_snapshot()
                last_sstat = time.time()
                did_work = True

            # pidstat cadence
            if now - last_pidstat >= self.frequency_seconds:
                self._write_pidstat_snapshots()
                last_pidstat = time.time()
                did_work = True

            if did_work:
                # Small sleep to avoid hot loop when both fired in the same tick
                time.sleep(0.5)
                continue

            # Sleep until the next due time (at least 0.5s)
            next_due = min(
                (last_sstat + self.slurm_frequency_seconds) - now,
                (last_pidstat + self.frequency_seconds) - now,
            )
            time.sleep(max(0.5, next_due))


# --------------------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------------------


def _parse_args() -> argparse.Namespace:
    """
    Parse command-line arguments for the resource monitor.
    Args:
        None
    Returns:
        Parsed arguments as argparse.Namespace.
    """
    p = argparse.ArgumentParser(
        description="SLURM resource monitor (TPC from FIRST node; independent cadences for pidstat and sstat)."
    )
    p.add_argument(
        "--jobid", type=str, required=True, help="SLURM Job ID (no .step suffix)"
    )
    p.add_argument(
        "--frequency",
        type=int,
        default=10,
        help="PID snapshots frequency in seconds (>=1, default 10)",
    )
    p.add_argument(
        "--slurm_frequency",
        type=int,
        default=60,
        help="sstat snapshots frequency in seconds (>=1, default 60)",
    )
    p.add_argument(
        "--output-dir",
        type=str,
        required=True,
        help="Output directory (JSON GZIP files)",
    )
    p.add_argument(
        "--pidstat-path", type=str, default="pidstat", help="Path to pidstat binary"
    )
    p.add_argument(
        "--container-sif",
        type=str,
        default=None,
        help="Path to Singularity SIF container. If provided, pidstat will be executed inside the container via srun + singularity exec",
    )
    return p.parse_args()


def main() -> None:
    """
    Main entry point for the resource monitor.
    Parses arguments, validates inputs, creates monitor instance, and starts monitoring.
    Args:
        None
    Returns:
        None
    """
    args = _parse_args()

    if args.frequency < 1 or args.slurm_frequency < 1:
        raise SystemExit("ERROR: --frequency and --slurm_frequency must be >= 1")

    if not os.path.isdir(args.output_dir):
        os.makedirs(args.output_dir, exist_ok=True)

    monitor = ResourceMonitor(
        job_id=args.jobid,
        frequency_seconds=args.frequency,
        slurm_frequency_seconds=args.slurm_frequency,
        output_dir=args.output_dir,
        pidstat_path=args.pidstat_path,
        container_sif=args.container_sif,
    )

    container_msg = (
        f" (using container {args.container_sif})"
        if args.container_sif
        else " (no container)"
    )
    print(
        f"INFO: Starting monitor for job {args.jobid} "
        f"(pidstat every {args.frequency}s, sstat every {args.slurm_frequency}s){container_msg}"
    )
    monitor.run()


if __name__ == "__main__":
    main()
