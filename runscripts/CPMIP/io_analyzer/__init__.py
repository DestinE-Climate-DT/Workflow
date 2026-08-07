"""
Climate Model I/O Analyzer

A package for analyzing I/O performance of climate models.
"""

import os
from typing import Dict, Optional

from .parsers import IOMetrics, ModelParser, IFSNEMOParser, IFSFESOMParser, ICONParser

# Registry of available parsers
PARSERS = {
    "ifs-nemo": IFSNEMOParser,
    "ifs-fesom": IFSFESOMParser,
    "icon": ICONParser,
}


def analyze_io(
    rundir_path: str,
    model_name: str,
    nodes: int = 0,
    tasks_per_node: int = 0,
    threads: int = 1,
    threads_per_core: int = 1,
    io_config: Optional[Dict[str, Dict[str, int]]] = None,
) -> IOMetrics:
    """
    Analyze I/O performance of a climate model run.

    Args:
        rundir_path: Path to the run directory containing output files.
        model_name: Name of the climate model to analyze (e.g., 'ifs-nemo', 'ifs-fesom').
        nodes: Total number of compute nodes allocated.
        tasks_per_node: Number of tasks per node.
        threads: Number of OpenMP threads per task.
        threads_per_core: Number of hardware threads per physical core (hyperthreading).
        io_config: I/O layout bundled per component, forwarded to the parser,
            which expands it (see ModelParser):
            {"IFS"|"NEMO"|"FESOM": {"tasks","nodes","ppn"},
             "ICON": {"atm_compute_tasks","oce_tasks","yaco_tasks"}}.

    Returns:
        IOMetrics: Object with analysis results.

    Raises:
        FileNotFoundError: If run directory or required files are not found.
        ValueError: If model is not supported or data is invalid.
    """
    # Validate run directory
    if not os.path.exists(rundir_path):
        raise FileNotFoundError(f"Run directory not found: {rundir_path}")

    if not os.path.isdir(rundir_path):
        raise ValueError(f"Path is not a directory: {rundir_path}")

    # Get the appropriate parser
    model_name = model_name.lower()
    if model_name not in PARSERS:
        available = ", ".join(PARSERS.keys())
        raise ValueError(
            f"Model '{model_name}' is not supported. Available models: {available}"
        )

    parser_class = PARSERS[model_name]
    parser = parser_class(
        rundir_path=rundir_path,
        nodes=nodes,
        tasks_per_node=tasks_per_node,
        threads=threads,
        threads_per_core=threads_per_core,
        io_config=io_config,
    )

    # Parse the output files and return metrics
    return parser.parse()


__all__ = [
    "analyze_io",
    "IOMetrics",
    "ModelParser",
    "IFSNEMOParser",
    "IFSFESOMParser",
    "ICONParser",
]
