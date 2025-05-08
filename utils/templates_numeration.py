#!/usr/bin/env python

import fileinput
import logging
import re
import sys
from argparse import ArgumentParser, ArgumentTypeError, Namespace
from pathlib import Path

from utils.logger import config_logger


"""
usage: templates_numeration.py [-h] [--fix]
Check and optionally fix variable definitions in templates.

options:
  -h, --help  show this help message and exit
  --fix       Fix incorrect variable definitions
"""


logger = logging.getLogger(__name__)


def fix_variable_definition(file_path):
    """
    Checks the variable definitions in a given file.
    This function reads a file line by line and checks for variable definitions
    within a specific header section marked by "# HEADER" and "# END_HEADER".
    The variable definitions are expected to follow a specific pattern:
    `variable_name=${variable_number:-%variable_value%}` where `variable_value`
    can be a single word, a word with one dot, or a word with two dots.

    If the numbers are not correct, updates the variable numbers sequentially.
    If an incorrect variable definition is found, it prints an error message and exits.

    Args:
        file_path (Path): The path to the file to be processed.

    Raises:
        ValueError: If an incorrect variable definition is found and cannot be fixed automatically.
    """
    in_header = False
    variable_number = 1
    diff = []
    with open(file_path, "r") as file:
        lines = file.readlines()
    for line in fileinput.input(file_path, inplace=True):
        line_stripped = line.strip()
        if line_stripped == "# HEADER":
            in_header = True
            print(line, end="")
        elif line_stripped == "# END_HEADER":
            in_header = False
            print(line, end="")
        elif not line_stripped or line_stripped.startswith("#"):
            print(line, end="")
        elif in_header:
            pattern = re.compile(r"(?!%)([^\.%]+?)(?:\.|%)")
            match = pattern.search(line)
            if match:
                new_line = re.sub(r"\$\{\d+:-", f"${{{variable_number}:-", line)
                print(new_line, end="")
                variable_number += 1
                if line != new_line:
                    diff.append((file_path, line, new_line))
            else:
                error_msg = (
                    "Incorrect variable definition in {file_path}: {line_stripped}. "
                    "Could not fix it automatically."
                )
                # Restore the original file content in case of error
                with open(file_path, "w") as original_file:
                    original_file.writelines(lines)
                raise ValueError(error_msg)
        else:
            print(line, end="")

    if diff:
        for file_path, line, new_line in diff:
            logger.info(f"Fixed incorrect variable definition in {file_path}")
            logger.info(f"< {line}")
            logger.info(f"> {new_line}")


def check_variable_definition(file_path):
    """
    Checks the variable definitions in a given file.
    This function reads a file line by line and checks for variable definitions
    within a specific header section marked by "# HEADER" and "# END_HEADER".
    The variable definitions are expected to follow a specific pattern:
    `variable_name=${variable_number:-%variable_value%}` where `variable_value`
    can be a single word, a word with one dot, or a word with two dots.
    Args:
        file_path (Path): The path to the file to be checked.
    Raises:
        ValueError: If an incorrect variable definition is found.
    """
    with open(file_path, "r") as file:
        in_header = False
        variable_number = 1
        for line in file:
            if line.strip() == "# HEADER":
                in_header = True
            elif line.strip() == "# END_HEADER":
                in_header = False
            elif not line.strip() or line.strip().startswith("#"):
                continue
            elif in_header:
                pattern = re.compile(rf"\w+=\$\{{{variable_number}:-%((\w+).)+%\}}")
                match = pattern.search(line)
                if match:
                    logger.debug(
                        f"Correct variable definition found in {file_path}: {line.strip()}"
                    )
                    variable_number += 1
                else:
                    error_msg = (
                        f"Incorrect variable definition in {file_path}: {line.strip()}"
                    )
                    raise ValueError(error_msg)


def _valid_dir_arg(value: str) -> Path:
    """Validate that the given value resolves to a valid and existing directory.

    Args:
        value: The given path.
    Returns:
        A pathlib.Path object.
    Raises:
        ArgumentTypeError: If the given value is not a directory.
    """
    path = Path(value)
    if not path.is_dir():
        raise ArgumentTypeError(
            f"Invalid templates folder {value}. Must be a directory."
        )
    return path


def _parse_args() -> Namespace:
    """Parse command line arguments."""
    parser = ArgumentParser(
        description="Check and optionally fix variable definitions in templates."
    )
    parser.add_argument(
        "--fix", action="store_true", help="Fix incorrect variable definitions"
    )
    parser.add_argument(
        "--templates",
        dest="templates",
        type=_valid_dir_arg,
        default="templates",
        help="Templates folder (absolute or relative)",
    )
    logging_levels = [
        logging.getLevelName(level)
        for level in [
            logging.DEBUG,
            logging.INFO,
            logging.WARNING,
            logging.ERROR,
            logging.CRITICAL,
        ]
    ]
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=logging_levels,
        help="Set the logging level",
    )
    return parser.parse_args()


def main():
    args = _parse_args()
    config_logger(args.log_level.upper())
    templates_folder = (
        args.templates
        if args.templates.is_absolute()
        else Path(__file__).parent.parent / args.templates
    )

    for shell_script in templates_folder.glob("**/*.sh"):
        # Temporal fix to avoid issues with wrappers
        if shell_script.name.startswith("sim_"):
            continue
        try:
            if args.fix:
                fix_variable_definition(shell_script)
            else:
                check_variable_definition(shell_script)
        except ValueError as e:
            logger.error(e)
            sys.exit(1)


if __name__ == "__main__":
    main()
