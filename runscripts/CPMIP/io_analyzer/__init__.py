"""
Climate Model I/O Analyzer

A package for analyzing I/O performance of climate models.
"""

import os

from .parsers import IOMetrics, ModelParser, IFSNEMOParser, IFSFESOMParser

# Registry of available parsers
PARSERS = {
    "ifs-nemo": IFSNEMOParser,
    "ifs-fesom": IFSFESOMParser,
}


def analyze_io(
    rundir_path: str,
    model_name: str,
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
) -> IOMetrics:
    """
    Analyze I/O performance of a climate model run.

    Args:
        rundir_path: Path to the run directory containing output files.
        model_name: Name of the climate model to analyze (e.g., 'ifs-nemo', 'ifs-fesom').
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

    # Parse the output files and return metrics
    return parser.parse()


__all__ = ["analyze_io", "IOMetrics", "ModelParser", "IFSNEMOParser", "IFSFESOMParser"]
