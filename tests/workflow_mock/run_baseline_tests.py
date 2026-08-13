from wf_mock.path import Path
from wf_mock.logger import logger
from wf_mock.extractor import Extractor
from wf_mock.runner import Runner
from argparse import ArgumentParser
import csv
import sys
from wf_mock.directory_compare import DirectoryCompare
import os
from colorama import Fore

EXPS_HOME_DIR = Path("/app/autosubmit/experiments/")


def read_created_exps(file_path) -> list:
    """Read the rows create_exp_template.sh appends: expid, date, template, HPC."""
    with open(file_path, "r") as f:
        return [row for row in csv.reader(f) if row]


def build_exp_path(expid: str, root_dir=EXPS_HOME_DIR) -> Path:
    return root_dir.copy().join(expid).join("tmp")


def format_exp_name(template_path: str, hpc: str) -> str:
    return (
        f"{os.linesep} {Fore.BLUE} File name: {Path(template_path).file_name()}"
        f" {Fore.RESET} {os.linesep} {Fore.MAGENTA} HPC: {hpc}" + Fore.RESET
    )


def create_exps(branch: str, branch_type: str):
    simulation_configs_dir = Path.cwd().join("simulation_configs")
    autosubmit_configs_dir = Path.cwd().join("autosubmit_configs")
    create_exp_template_path = Path.cwd().join("create_exp_template.sh")
    extractor = Extractor(
        simulation_configs_root_dir=simulation_configs_dir,
        autosubmit_configs_root_dir=autosubmit_configs_dir,
    )
    extractor = extractor.extract_paths()
    runner = Runner(extractor=extractor, branch=branch, branch_type=branch_type)
    runner.run(
        create_exp_template_path=create_exp_template_path, exps_home_dir=EXPS_HOME_DIR
    )
    branch = branch.replace("/", "_")
    return Path("output", f"created_experiments_{branch}_{branch_type}.csv")


def run():
    parser = ArgumentParser(description="Compare two directories")
    # Add argument for running branch name: the branch, where the pipeline is running
    parser.add_argument(
        "--running_branch",
        help="Running branch name, e.g. main",
        required=True,
        type=str,
    )
    # Add argument for source branch name
    parser.add_argument(
        "--source_branch", help="Source branch name, e.g. main", required=True, type=str
    )

    # Add argument for comparison branch name
    parser.add_argument(
        "--target_branch",
        required=True,
        help="Comparison branch name, e.g. dev",
        type=str,
    )
    parser.add_argument(
        "--extensions",
        help="Extensions to compare, e.g. cmd. Empty (the default) compares every extension",
        nargs="+",
        default=[],
    )
    parser.add_argument("--recursive", help="Recursive comparison", action="store_true")
    parser.add_argument(
        "--expected_scripts",
        help="Substrings a file name must contain to be compared."
        " Empty (the default) compares every file",
        nargs="+",
        default=[],
    )
    args = parser.parse_args()

    extensions = args.extensions
    recursive = args.recursive

    source_branch = args.source_branch
    target_branch = args.target_branch
    running_branch = args.running_branch
    logger.info(f"Running branch: {running_branch}")

    # Empty MR branches ⇒ not a merge-request pipeline; fall back to base=main.
    if source_branch == "" and target_branch == "":
        logger.warning(
            "No merge-request branches provided: comparing base=main vs "
            f"target={running_branch}. This is NOT a real MR target; run inside a "
            "merge-request pipeline for a baseline diff against the MR target."
        )
        source_branch = "main"
        target_branch = running_branch

    logger.info(
        f"Comparing base branch '{source_branch}' vs target branch '{target_branch}'"
    )

    base_exps = create_exps(source_branch, branch_type="base")
    target_exps = create_exps(target_branch, branch_type="target")
    base_created = read_created_exps(base_exps.path)
    target_created = read_created_exps(target_exps.path)

    if len(base_created) != len(target_created):
        logger.error(
            f"Number of experiments is"
            f" different between source={source_branch}"
            f"and target={target_branch} branches"
        )
        sys.exit(1)

    if len(base_created) == 0:
        logger.error("No experiments found!")
        sys.exit(1)

    diff_count = 0
    for base_row, target_row in zip(base_created, target_created):
        base_expid, _, base_template, base_hpc = base_row
        target_expid, _, target_template, target_hpc = target_row
        if (base_template, base_hpc) != (target_template, target_hpc):
            logger.error(
                f"Experiments are not paired: base ran {base_template} on {base_hpc}"
                f" while target ran {target_template} on {target_hpc}"
            )
            sys.exit(1)
        base_exp_path = build_exp_path(base_expid)
        target_exp_path = build_exp_path(target_expid)
        directory_compare = DirectoryCompare(
            dir1=base_exp_path,
            dir2=target_exp_path,
            extensions=extensions,
            recursive=recursive,
            expected_scripts=args.expected_scripts,
            exps_home_dir=EXPS_HOME_DIR,
        )
        logger.info(format_exp_name(base_template, base_hpc))
        directory_compare.check_dirs().check_files()
        if directory_compare.diff_count > 0:
            logger.error(
                f"Found {directory_compare.diff_count} differences between {base_exp_path} and {target_exp_path}"
            )
            # logger.error("Aborting!")
            # sys.exit(1)
            diff_count += 1
        elif directory_compare.diff_count == -1:
            # sys.exit(1)
            diff_count += 1
            pass
        else:
            logger.info(
                f"No differences found between {base_exp_path} and {target_exp_path}"
            )

    if diff_count > 0:
        logger.error(
            f"Found {diff_count} differences between {source_branch} and {target_branch}"
        )
        sys.exit(1)


def test_directory_compare(dir1, dir2):
    extensions = ["cmd"]
    recursive = True
    directory_compare = DirectoryCompare(
        dir1=dir1, dir2=dir2, extensions=extensions, recursive=recursive
    )
    directory_compare.check_dirs().check_files()
    if directory_compare.diff_count > 0:
        logger.error(
            f"Found {directory_compare.diff_count} differences between {dir1} and {dir2}"
        )
        sys.exit(1)
    elif directory_compare.diff_count == -1:
        sys.exit(1)
    else:
        logger.info(f"No differences found between {dir1} and {dir2}")


if __name__ == "__main__":
    run()
    # test_directory_compare(
    #    dir1=Path("dir1"),
    #    dir2=Path("dir2"),
    # )
