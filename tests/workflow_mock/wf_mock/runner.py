from typing import List
import os
from .logger import logger
from .extractor import Extractor
import yaml
from .path import Path
from .utils import convert_dict_to_flags
import re


class Runner(object):
    def __init__(self, extractor: Extractor, branch: str, branch_type: str):
        self.extractor = extractor
        self.branch = branch
        self.branch_type = branch_type

    def run(self, create_exp_template_path: Path, exps_home_dir: Path):
        sim_config_paths = self.extractor.extracted_sim_config_paths
        as_config_paths = self.extractor.extracted_as_config_paths
        for template_path, as_config_path in zip(sim_config_paths, as_config_paths):
            if not Path(as_config_path).exists():
                logger.error(f"Autosubmit config file not found: {as_config_path}")
                raise Exception(f"Autosubmit config file not found: {as_config_path}")
            if not Path(template_path).exists():
                logger.error(f"Template file not found: {template_path}")
                raise Exception(f"Template file not found: {template_path}")
            with open(as_config_path, "r") as f:
                as_config = yaml.safe_load(f)
            for key in as_config.keys():
                # check if key has the format EXP{number}
                if re.match(r"EXP\d+", key):
                    as_config[key]["CREATE"]["GIT_BRANCH"] = self.branch
                    create_flags = convert_dict_to_flags(as_config[key]["CREATE"])
                    create_flags += f" --template_path {template_path}"
                    create_flags += f" --exps_home_dir {exps_home_dir}"
                    create_flags += f" --branch_type {self.branch_type}"
                    command = f"{create_exp_template_path} {create_flags}"
                    logger.info(f"Running command: {command}")
                    os.system(command)
                else:
                    msg = f"Invalid key in autosubmit config file: {key}, {as_config_path}"
                    logger.error(msg)
                    raise Exception(msg)


__all__ = ["Runner"]
