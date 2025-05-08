from .path import Path
from functools import partial
from .logger import logger


def walk_callback(
    root, subdirs, files, root_dir, paths_map, paths, only_include, only_exclude
):
    root_dir_name = root_dir.file_name()
    for f in files:
        file_abs_path = Path(root, f)
        file_parent_dir = Path(file_abs_path.dirname()).relative_path(root_dir.path)
        if only_include is not None:
            if f not in only_include:
                continue
        if only_exclude is not None:
            if f in only_exclude:
                continue
        if file_parent_dir == ".":
            file_parent_dir = root_dir_name
        parts = Path(file_parent_dir).split()
        if parts[0] not in paths_map.keys():
            paths_map[parts[0]] = {}
        for i in range(1, len(parts)):
            if parts[i] not in paths_map[parts[i - 1]].keys():
                paths_map[parts[i - 1]][parts[i]] = {}
        chunk = paths_map
        for part in parts:
            chunk = chunk[part]
        chunk[file_abs_path.file_name()] = file_abs_path.path
        paths.append(file_abs_path.path)


class Extractor(object):
    def __init__(
        self, simulation_configs_root_dir: Path, autosubmit_configs_root_dir: Path
    ):
        self.simulation_configs_root_dir = simulation_configs_root_dir
        self.autosubmit_configs_root_dir = autosubmit_configs_root_dir
        self.extracted_sim_config_paths = []
        self.extracted_sim_config_map = {}
        self.extracted_as_config_paths = []
        self.extracted_as_config_map = {}
        self.template_scripts = []

    def extract_paths(self, only_include: list = None, only_exclude: list = None):
        self.extracted_as_config_map.clear()
        self.extracted_sim_config_map.clear()
        self.extracted_sim_config_paths.clear()
        self.extracted_as_config_paths.clear()

        callback = partial(
            walk_callback,
            root_dir=self.simulation_configs_root_dir,
            paths_map=self.extracted_sim_config_map,
            paths=self.extracted_sim_config_paths,
            only_include=only_include,
            only_exclude=only_exclude,
        )
        self.simulation_configs_root_dir.walk(callback=callback, recursive=True)
        callback = partial(
            walk_callback,
            root_dir=self.autosubmit_configs_root_dir,
            paths_map=self.extracted_as_config_map,
            paths=self.extracted_as_config_paths,
            only_include=only_include,
            only_exclude=only_exclude,
        )
        self.autosubmit_configs_root_dir.walk(callback=callback, recursive=True)
        self.extracted_sim_config_paths = list(
            sorted(self.extracted_sim_config_paths, key=lambda x: Path(x).file_name())
        )
        self.extracted_as_config_paths = list(
            sorted(self.extracted_as_config_paths, key=lambda x: Path(x).file_name())
        )

        # check if both extracted paths are same
        if len(self.extracted_sim_config_paths) != len(self.extracted_as_config_paths):
            msg = "Found different number of simulation and autosubmit config files"
            logger.error(msg)
            raise Exception(msg)

        for p1, p2 in zip(
            self.extracted_sim_config_paths, self.extracted_as_config_paths
        ):
            p1 = Path(p1)
            p2 = Path(p2)
            if p1.file_name() != p2.file_name():
                msg = "Simulation and autosubmit config filenames are not the same"
                logger.error(msg)
                logger.error(f"Simulation config file: {p1.file_name()}")
                logger.error(f"Autosubmit config file: {p2.file_name()}")
                raise Exception(msg)
        return self

    def filter(self, extension: str):
        self.extracted_sim_config_paths = [
            p
            for p in self.extracted_sim_config_paths
            if Path(p).extension() == extension
        ]
        self.extracted_as_config_paths = [
            p
            for p in self.extracted_as_config_paths
            if Path(p).extension() == extension
        ]
        return self


__all__ = ["Extractor"]
