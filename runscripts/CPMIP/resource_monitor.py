import argparse
import os
import signal
import subprocess
import threading
import time
from datetime import datetime
from typing import Dict, Optional, List

# Import from new modular monitor package
from .monitor import (
    collect_job_metadata,
    collect_sstat_steps,
    aggregate_sstat_steps,
    build_node_stats_from_sections,
    build_sampler_script,
    parse_rocm_smi_json,
    now_timestamp,
    save_json_gz,
)
from .monitor.utils.subprocess_helpers import build_srun_command


# --------------------------------------------------------------------------------------
# Monitor class
# --------------------------------------------------------------------------------------


class ResourceMonitor:
    """
    Main monitor loop for a single job. Uses TPC from the FIRST allocated node only.

    pidstat is collected by ONE persistent ``srun --overlap`` step per node,
    launched at monitor start, that runs a sampling loop and streams samples
    back. This replaces the previous one-srun-per-tick design: it creates N
    long-lived steps (one per node) for the whole chunk instead of N×ticks
    transient steps, so it no longer floods sacct with housekeeping rows.
    sstat is polled separately on the monitor node on its own cadence.

    The sstat/pidstat snapshots are diagnostic-only. Chunk attribution for the
    performance metrics is done downstream from sacct, scoped to the chunk by
    the Autosubmit SIM_STAT [start, end] window — the monitor no longer records
    step IDs for that purpose.
    """

    def __init__(
        self,
        job_id: str,
        frequency_seconds: int,
        slurm_frequency_seconds: int,
        output_dir: str,
        pidstat_path: str,
        container_sif: Optional[str] = None,
        stop_file: Optional[str] = None,
        rocm_smi_path: Optional[str] = None,
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
            stop_file: Optional path to a per-chunk completion marker. The SIM
                creates it when its compute finishes; the monitor exits cleanly
                once it appears. This is the chunk-scoped stop signal under a
                wrapper, where the shared SLURM job stays active across all
                chunks of the allocation and therefore cannot bound a single
                chunk.
            rocm_smi_path: Optional path to the rocm-smi binary. When set, each
                per-node sample also runs 'rocm-smi --showuse --showmemuse
                --showmeminfo vram --showpower --showbw --json' on the host and
                stores the parsed per-GPU metrics. The caller (monitor template)
                only sets this for GPU runs (ICON).
        Returns:
            None
        """
        self.job_id = job_id
        self.frequency_seconds = max(5, int(frequency_seconds))
        self.slurm_frequency_seconds = max(60, int(slurm_frequency_seconds))
        self.output_dir = output_dir
        self.pidstat_path = pidstat_path
        self.container_sif = container_sif
        self.stop_file = stop_file
        self.rocm_smi_path = rocm_smi_path

        self.metadata_dir = os.path.join(self.output_dir, "metadata")
        # Each sstat tick gets its own self-contained folder: sstat/<iso>/, holding
        # one <step_id>.json.gz per step plus aggregated.json.gz for that tick.
        self.sstat_dir = os.path.join(self.output_dir, "sstat")
        self.pidstat_nodes_dir = os.path.join(self.output_dir, "pidstat", "nodes")

        self.node_list: List[str] = []
        self.threads_per_core: int = 1
        self.account: str = ""
        self.job_mem_limit_bytes: int = 0  # Job memory limit from SLURM metadata
        # Persistent per-node sampler processes (srun --overlap running a loop)
        # and their reader threads. Populated by _start_node_samplers.
        self._samplers: Dict[str, "subprocess.Popen"] = {}
        self._reader_threads: List[threading.Thread] = []
        self._stop_event = threading.Event()

    # ------------------------------- lifecycle ---------------------------------

    def _write_metadata(self) -> None:
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

            # Extract TPC, account, and memory limit from job-level metadata
            self.threads_per_core = metadata.get("Threads_Per_Core_Count", 1)
            self.account = metadata.get("Account", "")
            tres_allocated = metadata.get("Tres_Allocated", {})
            self.job_mem_limit_bytes = tres_allocated.get("Mem_Bytes", 0)
            self.node_list = metadata.get("Allocated_Node_List", {}).get("Nodes", [])

            ts_epoch, ts_iso = now_timestamp()
            payload = {
                "Timestamp_Epoch": ts_epoch,
                "Timestamp_ISO_Local": ts_iso,
                "Job_Metadata": metadata,
            }

            save_json_gz(os.path.join(self.metadata_dir, "metadata.json.gz"), payload)
        except Exception as e:
            print(f"WARNING: Failed to collect metadata - {e}")

    def _start_node_samplers(self) -> None:
        """
        Launch one persistent ``srun --overlap`` step per node, each running a
        bash sampling loop that streams lscpu (once) + uptime/free/pidstat
        samples back over stdout. A reader thread per node parses complete
        samples and writes them as pidstat/nodes/<node>/<iso>.json.gz.

        Best-effort: a node that fails to launch is logged and skipped.
        """
        if not self.pidstat_path or not self.node_list:
            return

        script = build_sampler_script(
            pidstat_path=self.pidstat_path,
            frequency_seconds=self.frequency_seconds,
            container_sif=self.container_sif,
            rocm_smi_path=self.rocm_smi_path,
        )

        for node in self.node_list:
            argv = build_srun_command(
                command=["bash", "-c", script],
                jobid=self.job_id,
                node=node,
                account=self.account if self.account else None,
                step_name="sampler",
            )
            try:
                popen = subprocess.Popen(
                    argv,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                )
            except Exception as e:
                print(f"WARNING: failed to start sampler on {node} - {e}")
                continue

            self._samplers[node] = popen
            t = threading.Thread(
                target=self._reader_loop, args=(node, popen), daemon=True
            )
            t.start()
            self._reader_threads.append(t)

        print(
            f"INFO: started {len(self._samplers)} persistent node sampler(s) "
            f"(one srun --overlap step per node, sampling every "
            f"{self.frequency_seconds}s)"
        )

    def _reader_loop(self, node: str, popen: "subprocess.Popen") -> None:
        """
        Consume one node sampler's stdout stream, parsing complete sample
        blocks delimited by __SAMPLE__/__SAMPLE_END__ (see build_sampler_script)
        and writing each as a pidstat snapshot. Topology (lscpu) precedes the
        first sample and is cached for reuse across this node's samples.

        Never raises — a parse error on one sample is logged and skipped so the
        stream keeps flowing.
        """
        cpu_section = ""
        in_topo = True
        topo_buf: List[str] = []
        sample_buf: List[str] = []
        in_sample = False
        try:
            if popen.stdout is None:
                return
            for raw in popen.stdout:
                if self._stop_event.is_set():
                    break
                line = raw.rstrip("\n")
                if in_topo:
                    if line == "__TOPO_END__":
                        cpu_section = "\n".join(topo_buf)
                        topo_buf = []
                        in_topo = False
                    else:
                        topo_buf.append(line)
                    continue
                if line == "__SAMPLE__":
                    in_sample = True
                    sample_buf = []
                    continue
                if line == "__SAMPLE_END__":
                    in_sample = False
                    self._process_sample(node, cpu_section, sample_buf)
                    continue
                if in_sample:
                    sample_buf.append(line)
        except Exception as e:
            print(f"WARNING: sampler reader for {node} stopped - {e}")

    def _process_sample(self, node: str, cpu_section: str, lines: List[str]) -> None:
        """
        Parse one streamed sample block and write it as a node pidstat snapshot.

        Block layout (lines): <epoch>, <uptime...>, __SPLIT__, <free...>,
        __SPLIT__, <pidstat...>[, __SPLIT__, <rocm-smi --json...>]. The node-
        emitted epoch is used as the authoritative timestamp. The 4th section is
        present only on GPU runs (rocm_smi_path set).
        """
        if not lines:
            return
        try:
            epoch = int(lines[0].strip())
        except (ValueError, IndexError):
            epoch = int(time.time())

        body = "\n".join(lines[1:])
        parts = body.split("__SPLIT__")
        if len(parts) < 3:
            return
        load_section, mem_section, pidstat_output = parts[0], parts[1], parts[2]
        gpu_section = parts[3] if len(parts) > 3 else ""

        try:
            node_stats = build_node_stats_from_sections(
                cpu_section=cpu_section,
                load_section=load_section,
                mem_section=mem_section,
                pidstat_output=pidstat_output,
                threads_per_core=self.threads_per_core,
                job_mem_limit_bytes=self.job_mem_limit_bytes,
            )
        except Exception as e:
            print(f"WARNING: failed to parse sample from {node} - {e}")
            return

        ts_iso = datetime.fromtimestamp(epoch).isoformat()
        node_dir = os.path.join(self.pidstat_nodes_dir, node)
        os.makedirs(node_dir, exist_ok=True)
        payload = {
            "Job_Id": self.job_id,
            "Node": node,
            "Threads_Per_Core_Count": self.threads_per_core,
            "Timestamp_Epoch": epoch,
            "Timestamp_ISO_Local": ts_iso,
            "Node_Statistics": node_stats,
        }
        # GPU runs (ICON) stream a rocm-smi --json section; attach the parsed
        # per-GPU metrics when present (empty on non-GPU nodes / parse errors).
        gpu_stats = parse_rocm_smi_json(gpu_section)
        if gpu_stats:
            payload["Gpu_Statistics"] = gpu_stats
        save_json_gz(os.path.join(node_dir, f"{ts_iso}.json.gz"), payload)

    def _stop_node_samplers(self) -> None:
        """
        Terminate the persistent sampler steps. SIGTERM to each srun propagates
        to the remote bash loop, ending the step; the reader threads then hit
        EOF and exit.
        """
        self._stop_event.set()
        for node, popen in self._samplers.items():
            try:
                popen.terminate()
            except Exception:
                pass
        for popen in self._samplers.values():
            try:
                popen.wait(timeout=10)
            except Exception:
                try:
                    popen.kill()
                except Exception:
                    pass

    # ------------------------------- sampling ----------------------------------

    def _write_sstat_snapshot(self) -> None:
        """
        Collect sstat for all steps and write one self-contained snapshot folder.

        Each tick writes to sstat/<iso>/:
        1. Collect raw sstat data
        2. Process each step into ProcessedStepStats (normalized types/units)
        3. Save each processed step as <step_id>.json.gz in the tick folder
        4. Aggregate all steps into summary metrics
        5. Save aggregated.json.gz in the same tick folder

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

        # One self-contained folder per tick: sstat/<iso>/ (save_json_gz creates it).
        snapshot_dir = os.path.join(self.sstat_dir, ts_iso)

        # Save each processed step individually (timestamp is the folder name).
        for step_id, step_stats in processed_steps.items():
            step_payload = {
                "Job_Id": self.job_id,
                "Step_Id": step_id,
                "Timestamp_Epoch": ts_epoch,
                "Timestamp_ISO_Local": ts_iso,
                "Threads_Per_Core_Count": self.threads_per_core,
                "Step_Statistics": step_stats,
            }
            save_json_gz(os.path.join(snapshot_dir, f"{step_id}.json.gz"), step_payload)

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
            save_json_gz(
                os.path.join(snapshot_dir, "aggregated.json.gz"), aggregated_payload
            )
        except Exception as e:
            print(f"WARNING: Failed to calculate aggregated metrics - {e}")

    # ------------------------------- main loop ---------------------------------

    def run(self) -> None:
        """
        Start the persistent per-node pidstat samplers, then poll sstat on the
        monitor node every slurm_frequency_seconds. pidstat sampling runs
        autonomously inside the per-node srun steps (reader threads write the
        snapshots), so the main loop only drives the sstat cadence.

        Termination: the monitor stops when the SIM writes the per-chunk
        ``stop_file`` marker (signal_performance_done) at the end of its
        compute. This is the chunk-scoped stop signal that works under a
        wrapper, where every chunk shares one SLURM_JOB_ID — so job liveness
        cannot bound a single chunk. Exiting here lets PERFORMANCE_METRICS for
        this chunk start while later chunks keep running, instead of looping
        until the monitor job is SIGKILLed at its own wallclock.

        A SIGTERM (manual cancel / wallclock grace) sets the stop event so the
        loop unwinds and the finally block still runs cleanup.

        Cleanup always runs in the finally block: stop the sampler steps so they
        don't linger past the chunk. sstat counters vanish the moment a step
        ends, so we deliberately do NOT depend on a final sstat read — sacct
        retains finalized per-step data and is the authoritative source
        downstream.

        Args:
            None
        Returns:
            None
        """

        def _handle_sigterm(signum, frame):
            print("INFO: received SIGTERM; finishing monitor")
            self._stop_event.set()

        signal.signal(signal.SIGTERM, _handle_sigterm)

        self._write_metadata()
        self._start_node_samplers()

        # Trigger sstat on the first loop iteration.
        last_sstat = 0.0
        try:
            while not self._stop_event.is_set():
                now = time.time()
                if now - last_sstat >= self.slurm_frequency_seconds:
                    self._write_sstat_snapshot()
                    last_sstat = time.time()

                # Chunk-scoped stop: the SIM finished this chunk's compute.
                if self.stop_file and os.path.exists(self.stop_file):
                    print(
                        f"INFO: completion marker {self.stop_file} present; "
                        f"finishing monitor for this chunk"
                    )
                    break

                # Sleep until the next sstat tick, but wake early on stop so a
                # SIGTERM / job-end is acted on within a few seconds rather than
                # after a full slurm_frequency_seconds interval.
                next_due = (last_sstat + self.slurm_frequency_seconds) - time.time()
                self._stop_event.wait(timeout=max(0.5, min(5.0, next_due)))
        finally:
            self._stop_node_samplers()


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
    p.add_argument(
        "--stop-file",
        type=str,
        default=None,
        help="Per-chunk completion marker written by the SIM when its compute "
        "finishes. The monitor exits cleanly once it appears — the only "
        "chunk-scoped stop signal under a wrapper (shared SLURM_JOB_ID).",
    )
    p.add_argument(
        "--rocm-smi-path",
        type=str,
        default=None,
        help="Path to the rocm-smi binary. When set, each per-node sample also "
        "runs 'rocm-smi --showuse --showmemuse --showmeminfo vram --showpower "
        "--showbw --json' on the host and stores the parsed per-GPU metrics. "
        "Only set this for GPU runs (ICON).",
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
        stop_file=args.stop_file,
        rocm_smi_path=args.rocm_smi_path,
    )

    container_msg = (
        f" (using container {args.container_sif})"
        if args.container_sif
        else " (no container)"
    )
    if args.rocm_smi_path:
        container_msg += f"; GPU sampling via {args.rocm_smi_path}"
    print(
        f"INFO: Starting monitor for job {args.jobid} "
        f"(pidstat every {args.frequency}s, sstat every {args.slurm_frequency}s){container_msg}"
    )
    monitor.run()


if __name__ == "__main__":
    main()
