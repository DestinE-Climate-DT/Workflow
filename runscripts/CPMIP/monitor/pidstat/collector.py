"""Collector for pidstat node statistics.

This module handles execution of pidstat on SLURM nodes and collection of
per-process statistics.
"""

import json
from typing import Any, Dict, Optional

from ..types.pidstat import NodeStats
from .builder import (
    build_node_general_info,
    build_node_summary,
    build_process_entries,
    update_summary_utilization_percentages,
)
from .parser import filter_kernel_process, parse_pidstat_output


def build_node_stats_from_sections(
    cpu_section: str,
    load_section: str,
    mem_section: str,
    pidstat_output: str,
    threads_per_core: int = 1,
    job_mem_limit_bytes: int = 0,
) -> NodeStats:
    """
    Build a NodeStats from the already-captured text sections of one sample.

    Used by the persistent streaming sampler in resource_monitor: the per-node
    srun loop streams lscpu / uptime / free / pidstat text back, and each
    sample is turned into a NodeStats here.

    Args:
        cpu_section: Raw lscpu output (topology; may be cached/streamed once).
        load_section: Raw uptime output.
        mem_section: Raw 'free -k' output.
        pidstat_output: Raw 'pidstat -urwh 1 1' output.
        threads_per_core: TPC for physical-core normalization.
        job_mem_limit_bytes: Job memory limit for Memory_Percent_Of_Job_Limit.

    Returns:
        NodeStats: Summary, Processes, Node_General_Info.
    """
    # Parse pidstat output using dedicated parser function (returns raw dicts)
    raw_processes = parse_pidstat_output(pidstat_output=pidstat_output)

    # Build ProcessEntry TypedDicts from raw data (applies all normalizations)
    processes = build_process_entries(
        raw_processes, threads_per_core, job_mem_limit_bytes
    )
    # Filter out processes with zero CPU usage
    processes = [p for p in processes if p["Cpu_Related"]["Cpu_Physical_Cores"] > 0.0]

    # Count filtered kernel processes
    filtered_kernel = sum(1 for p in processes if filter_kernel_process(p["Command"]))

    # Build node summary using builder
    summary = build_node_summary(processes, filtered_kernel)

    # Build node general info using builder
    node_info = build_node_general_info(cpu_section, mem_section, load_section)

    # Update summary with utilization percentages
    update_summary_utilization_percentages(summary, node_info, job_mem_limit_bytes)

    return NodeStats(Summary=summary, Processes=processes, Node_General_Info=node_info)


def build_sampler_script(
    pidstat_path: str,
    frequency_seconds: int,
    container_sif: Optional[str] = None,
    rocm_smi_path: Optional[str] = None,
) -> str:
    """
    Build the bash sampling loop run by the persistent per-node srun step.

    The script emits lscpu ONCE (topology is invariant), then repeats a sample
    block every ``frequency_seconds``. Each block is delimited so the monitor's
    reader thread can parse complete samples as they stream in:

        <lscpu...>
        __TOPO_END__
        __SAMPLE__
        <epoch>
        <uptime...>
        __SPLIT__
        <free -k...>
        __SPLIT__
        <pidstat...>
        __SPLIT__                 (only when rocm_smi_path is set)
        <rocm-smi --json...>
        __SAMPLE_END__
        ... (repeats)

    Args:
        pidstat_path: Path to pidstat binary (host or in-container).
        frequency_seconds: Seconds to sleep between samples.
        container_sif: If set, pidstat runs via 'singularity exec'.
        rocm_smi_path: If set, also sample GPUs each tick by running
            '<rocm_smi_path> --showuse --showmemuse --showmeminfo vram
            --showpower --showbw --json' on the HOST (not in the container —
            rocm-smi needs the GPU driver). Emitted as an extra __SPLIT__
            section. The caller gates this on GPU runs (ICON); on a non-GPU node
            the '|| echo' fallback keeps the loop alive.

    Returns:
        A bash script string suitable for 'bash -c'.
    """
    if container_sif:
        pidstat_inv = (
            f"singularity exec --no-home --cleanenv {container_sif} "
            f"{pidstat_path} -urwh 1 1"
        )
    else:
        pidstat_inv = f"{pidstat_path} -urwh 1 1"

    # rocm-smi runs natively on the host (GPU driver access); its '|| echo'
    # keeps the sampling loop alive on non-GPU nodes.
    gpu_lines = ""
    if rocm_smi_path:
        gpu_lines = (
            '  echo "__SPLIT__"\n'
            f"  {{ {rocm_smi_path} --showuse --showmemuse --showmeminfo vram "
            f"--showpower --showbw --json || echo ROCM_SMI_ERROR; }}\n"
        )

    freq = max(1, int(frequency_seconds))
    return (
        "{ lscpu || echo CPU_ERROR; }\n"
        'echo "__TOPO_END__"\n'
        "while true; do\n"
        '  echo "__SAMPLE__"\n'
        "  date +%s\n"
        "  { uptime || echo LOAD_ERROR; }\n"
        '  echo "__SPLIT__"\n'
        "  { free -k || echo MEM_ERROR; }\n"
        '  echo "__SPLIT__"\n'
        f"  {{ {pidstat_inv} || echo PIDSTAT_ERROR; }}\n"
        f"{gpu_lines}"
        '  echo "__SAMPLE_END__"\n'
        f"  sleep {freq}\n"
        "done\n"
    )


def _coerce_number(value: Any) -> Any:
    """Return float(value) when it parses as a number, else the original value."""
    try:
        return float(value)
    except (TypeError, ValueError):
        return value


def parse_rocm_smi_json(rocm_output: str) -> Dict[str, Dict[str, Any]]:
    """
    Parse 'rocm-smi --json' output into {card: {metric: value}}.

    Numeric-looking values are coerced to float; non-numeric values (e.g.
    'N/A') are kept as their original string. Returns {} when the text is not
    valid JSON — e.g. the ROCM_SMI_ERROR marker emitted on a non-GPU node, or a
    rocm-smi build that does not support --json.

    Args:
        rocm_output: Raw stdout of 'rocm-smi --showuse --showpower --json'.

    Returns:
        Dict[str, Dict[str, Any]]: {card_id: {metric_name: float | str}} per
        GPU; {} if the output is empty or not parseable as a JSON object.
    """
    text = (rocm_output or "").strip()
    if not text:
        return {}
    try:
        data = json.loads(text)
    except (ValueError, TypeError):
        return {}
    if not isinstance(data, dict):
        return {}

    parsed: Dict[str, Dict[str, Any]] = {}
    for card, metrics in data.items():
        if not isinstance(metrics, dict):
            continue
        parsed[card] = {key: _coerce_number(value) for key, value in metrics.items()}
    return parsed
