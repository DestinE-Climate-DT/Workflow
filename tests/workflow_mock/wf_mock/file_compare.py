from .path import Path
from .logger import logger
import difflib
from enum import Enum
from colorama import Fore
import re

import os


def color_diff(diff):
    """
    Adds color to text from a diff:
    - Green for lines starting with ``+``
    - Red for lines starting with ``-``
    - Blue for lines starting with ``^``

    Parameters
    ----------
    diff : iterable object of strings to be colored
    """
    for line in diff:
        if line.startswith("+"):
            yield Fore.GREEN + line + Fore.RESET
        elif line.startswith("-"):
            yield Fore.RED + line + Fore.RESET
        elif line.startswith("^"):
            yield Fore.BLUE + line + Fore.RESET
        else:
            yield line


class FileCompare(object):
    def __init__(self, file1: Path, file2: Path, exps_home_dir: Path):
        self.file1 = file1
        self.file2 = file2
        self.exps_home_dir = exps_home_dir
        self.diff_count = 0

    def compare(self):
        self.diff_count = 0
        with open(self.file1.path) as f1:
            f1_content = f1.read().strip().splitlines()
        with open(self.file2.path) as f2:
            f2_content = f2.read().strip().splitlines()

        fromfile = self.file1.file_name()
        tofile = self.file2.file_name()
        logger.dashed_line()
        logger.info(f"Comparing {self.file1} with {self.file2}")
        exp1_id = self.file1.relative_path(self.exps_home_dir.path).split(os.sep)[0]
        exp2_id = self.file2.relative_path(self.exps_home_dir.path).split(os.sep)[0]

        f1_content = [line.replace(exp1_id, "expid") for line in f1_content]
        f2_content = [line.replace(exp2_id, "expid") for line in f2_content]

        diff = difflib.unified_diff(f1_content, f2_content)
        diff = list(diff)
        if len(diff) == 0:
            logger.info("Files are identical")

        pdifferences = "\n"
        for line in color_diff(diff):
            self.diff_count += 1
            pdifferences += f"\t\t{line}\n"

        if self.diff_count > 0:
            logger.error(pdifferences)
            logger.error(f"Found {self.diff_count} differences")
        logger.dashed_line()
        return self


__all__ = ["FileCompare"]
