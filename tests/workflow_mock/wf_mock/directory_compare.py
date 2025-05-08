from .file_compare import FileCompare
from .path import Path
from .logger import logger
from enum import Enum
from functools import partial


def walk_callback(
    root,
    subdirs,
    files,
    root_dir,
    extensions: list,
    paths_map: dict,
    paths: list,
    expected_scripts: list,
):
    root_dir_name = root_dir.file_name()
    for f in files:
        file_abs_path = Path(root, f)
        file_parent_dir = Path(file_abs_path.dirname()).relative_path(root_dir.path)
        if extensions is not None:
            if file_abs_path.extension() not in extensions:
                continue

        found = False
        if expected_scripts is not None:
            for e in expected_scripts:
                if e in f:
                    found = True
                    break
        if not found:
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


class DirectoryCompare(object):
    def __init__(
        self,
        dir1: Path,
        dir2: Path,
        extensions=["cmd"],
        recursive=True,
        expected_scripts=[],
        exps_home_dir: Path = None,
    ):
        self.dir1 = dir1
        self.dir2 = dir2
        self.extensions = extensions
        self.recursive = recursive
        self.expected_scripts = expected_scripts
        self.dir1_paths_map = {}
        self.dir2_paths_map = {}
        self.dir1_paths = []
        self.dir2_paths = []
        self.diff_count = 0
        self.exps_home_dir = exps_home_dir

    def check_dirs(self):
        self.diff_count = 0
        if not self.dir1.is_dir():
            logger.error(f"{self.dir1.path} is not a directory")
            self.diff_count = -1
            return self
        if not self.dir2.is_dir():
            logger.error(f"{self.dir2.path} is not a directory")
            self.diff_count = -1
            return self
        self.dir1_paths_map.clear()
        self.dir2_paths_map.clear()
        self.dir1_paths.clear()
        self.dir2_paths.clear()
        self.diff_count = 0
        callback = partial(
            walk_callback,
            root_dir=self.dir1,
            extensions=self.extensions,
            paths_map=self.dir1_paths_map,
            expected_scripts=self.expected_scripts,
            paths=self.dir1_paths,
        )
        self.dir1.walk(callback=callback, recursive=self.recursive)
        callback = partial(
            walk_callback,
            root_dir=self.dir2,
            extensions=self.extensions,
            paths_map=self.dir2_paths_map,
            expected_scripts=self.expected_scripts,
            paths=self.dir2_paths,
        )
        self.dir2.walk(callback=callback, recursive=self.recursive)

        self.dir1_paths = list(
            sorted(self.dir1_paths, key=lambda x: Path(x).file_name())
        )
        self.dir2_paths = list(
            sorted(self.dir2_paths, key=lambda x: Path(x).file_name())
        )
        logger.info(f"Found {len(self.dir1_paths)} scripts in {self.dir1.path}")
        logger.info(f"Found {len(self.dir2_paths)} scripts in {self.dir2.path}")

        return self

    def check_files(self):
        if len(self.dir1_paths) != len(self.dir2_paths):
            logger.error(
                f"Number of files in {self.dir1.path}: {len(self.dir1_paths)} and {self.dir2.path}: {len(self.dir2_paths)} are different"
            )
            logger.error(f"Files in {self.dir1.path}")
            file_names = [Path(p).file_name() for p in self.dir1_paths]
            logger.error(file_names)
            logger.error(f"Files in {self.dir2.path}")
            file_names = [Path(p).file_name() for p in self.dir2_paths]
            logger.error(file_names)
            self.diff_count += 1
            return self

        for i in range(len(self.dir1_paths)):
            file1 = Path(self.dir1_paths[i])
            file2 = Path(self.dir2_paths[i])
            file_compare = FileCompare(
                file1, file2, exps_home_dir=self.exps_home_dir
            ).compare()
            self.diff_count += file_compare.diff_count

        return self
