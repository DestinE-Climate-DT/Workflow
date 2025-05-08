from wf_mock.path import Path
from wf_mock.logger import logger
from wf_mock.extractor import Extractor
from wf_mock.runner import Runner
from argparse import ArgumentParser
import csv
import sys
from wf_mock.directory_compare import DirectoryCompare
import yaml
import re
import os
from colorama import Fore

EXPS_HOME_DIR = Path("/app/autosubmit/experiments/")


def read_expids(file_path) -> list:
    out = []
    with open(file_path, "r") as f:
        reader = csv.reader(f)
        for row in reader:
            out.append(row[0])

    return out


def build_exp_path(expid: str, root_dir=EXPS_HOME_DIR) -> Path:
    return root_dir.copy().join(expid).join("tmp")


def get_exp_names():
    simulation_configs_dir = Path.cwd().join("simulation_configs")
    autosubmit_configs_dir = Path.cwd().join("autosubmit_configs")
    extractor = Extractor(
        simulation_configs_root_dir=simulation_configs_dir,
        autosubmit_configs_root_dir=autosubmit_configs_dir,
    )
    extractor = extractor.extract_paths()
    sim_config_paths = extractor.extracted_sim_config_paths
    as_config_paths = extractor.extracted_as_config_paths
    for template_path, as_config_path in zip(sim_config_paths, as_config_paths):
        with open(as_config_path, "r") as f:
            as_config = yaml.safe_load(f)
            for key in as_config.keys():
                if re.match(r"EXP\d+", key):
                    file_name = Path(template_path).file_name()
                    create_config = as_config[key]["CREATE"]
                    # log the file name and the create config in a beutiful way
                    msg = (
                        f"{os.linesep} {Fore.BLUE} File name: {file_name} {Fore.RESET} {os.linesep} {Fore.MAGENTA} Create config: {create_config}"
                        + Fore.RESET
                    )
                    yield msg


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
    # Add argument for base branch name
    parser.add_argument(
        "--base_branch", help="Base branch name, e.g. main", default="main", type=str
    )
    # Add argument for comparison branch name
    parser.add_argument(
        "--target_branch",
        required=True,
        help="Comparison branch name, e.g. dev",
        type=str,
    )
    parser.add_argument(
        "--extensions", help="Extensions to compare", nargs="+", default=["cmd"]
    )
    parser.add_argument("--recursive", help="Recursive comparison", action="store_true")
    parser.add_argument(
        "--expected_scripts",
        help="Expected scripts to compare",
        nargs="+",
        default=[
            "DQC_BASIC",
            "DQC_FULL",
            "fc0_1_SIM",
            "fc0_INI",
            "LOCAL_SETUP",
            "REMOTE_SETUP",
            "SYNCHRONIZE",
        ],
    )
    args = parser.parse_args()

    extensions = args.extensions
    recursive = args.recursive
    logger.info(f"Base branch: {args.base_branch}")
    logger.info(f"Target branch: {args.target_branch}")

    base_exps = create_exps(args.base_branch, branch_type="base")
    target_exps = create_exps(args.target_branch, branch_type="target")
    base_expids = read_expids(base_exps.path)
    target_expids = read_expids(target_exps.path)

    if len(base_expids) != len(target_expids):
        logger.error(
            f"Number of experiments is"
            f" different between base={args.base_branch}"
            f"and target={args.target_branch} branches"
        )
        sys.exit(1)

    if len(base_expids) == 0:
        logger.error(f"No experiments found!")
        sys.exit(1)

    exp_names = list(get_exp_names())
    exp_name_idx = 0
    diff_count = 0
    for base_expid, target_expid in zip(base_expids, target_expids):
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
        logger.info(exp_names[exp_name_idx])
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

        exp_name_idx += 1
    if diff_count > 0:
        logger.error(
            f"Found {diff_count} differences between {args.base_branch} and {args.target_branch}"
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
    # get_exp_names()
    run()
    # test_directory_compare(
    #    dir1=Path("dir1"),
    #    dir2=Path("dir2"),
    # )
