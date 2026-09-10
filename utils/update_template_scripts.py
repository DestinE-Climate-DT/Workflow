#!/usr/bin/env python

# Add function paths of the lib scripts as comment to the template scripts

import os
import sys
import re
from typing import List
from difflib import SequenceMatcher

DEBUG = False


def similarity_ratio(a, b):
    return SequenceMatcher(None, a, b).ratio()


class ScriptFunctions(object):
    def __init__(self, path: str):
        self.path = path
        self.functions = []
        self.functions_paths = []

    def extract_functions(self):
        self.functions.clear()
        # extract bash functions
        with open(self.path, "r") as f:
            lines = f.readlines()
            for line in lines:
                if re.match(r"^function", line):
                    # get function name without brackets
                    function_name = line.split()[1].split("(")[0]
                    self.functions.append(function_name)
        return self

    def create_function_paths(self, root_dir):
        self.functions_paths.clear()
        for function in self.functions:
            path = os.path.relpath(self.path, root_dir)
            self.functions_paths.append(
                f"# {path} ({function}) (auto generated comment)"
            )
        return self


class TargetScriptFunctionBlock(object):
    def __init__(self, target_script_path: str, function_name, function_path, block):
        self.target_script_path = target_script_path
        self.function_name = function_name
        self.function_paths = [function_path]
        self.block = block
        self.start = block[0]
        self.end = block[-1]
        self.modified = False

    def __repr__(self) -> str:
        return f"{self.target_script_path} {self.function_name} {self.function_paths} {self.block}"

    def __eq__(self, value: object) -> bool:
        if not isinstance(value, TargetScriptFunctionBlock):
            return False
        if self.target_script_path != value.target_script_path:
            return False
        if self.function_name != value.function_name:
            return False
        if self.start != value.start:
            return False
        if self.end != value.end:
            return False
        if len(self.block) != len(value.block):
            return False
        if self.function_paths != value.function_paths:
            return False
        return True

    def __ne__(self, value: object) -> bool:
        return not self.__eq__(value)

    def should_merge(self, other):
        if self.target_script_path != other.target_script_path:
            return False
        if self.function_name != other.function_name:
            return False
        if self.start != other.start:
            return False
        if self.end != other.end:
            return False
        return True

    def merge(self, other):
        assert self.target_script_path == other.target_script_path
        assert self.function_name == other.function_name
        assert self.start == other.start
        assert self.end == other.end
        assert len(self.block) == len(other.block)
        self.function_paths.extend(other.function_paths)

        return self

    def get_block_content(self, lines):
        return "".join([lines[idx] for idx in self.block])

    def get_line_indices_and_function_paths(self, lines):
        block = self.block
        block_lines = [lines[idx].strip() for idx in block]
        to_add = []
        out = []
        line_idx = self.end
        for function_path in self.function_paths:
            if function_path.strip() not in block_lines:
                to_add.append(function_path)
                out.append((line_idx, function_path, self.function_name))
        return out

    def add_comment(self, lines):
        block = self.block
        block_lines = [lines[idx].strip() for idx in block]
        to_add = []
        for function_path in self.function_paths:
            if function_path.strip() not in block_lines:
                to_add.append(function_path)

        block_content = [lines[idx] for idx in block]
        for function_path in to_add:
            block_content.insert(-1, f"{function_path}\n")
            self.modified = True
        return "".join(block_content)


class TargetScriptBlocks(object):
    blocks: List[TargetScriptFunctionBlock]

    def __init__(self, path: str, scripts_functions: List[ScriptFunctions]):
        self.path = path
        self.scripts_functions = scripts_functions
        self.blocks = []

    def get_current_line_indices_and_function_paths(
        self, line_idx, line_indices_and_function_paths
    ):
        for chunk in line_indices_and_function_paths:
            for idx, function_path, function_name in chunk:
                if line_idx == idx:
                    return chunk
        return None

    def modify_content(self):
        self.blocks.clear()
        with open(self.path, "r") as f:
            lines = f.readlines()

        for script_functions in self.scripts_functions:
            # Commented because it is not used
            # script_path = script_functions.path
            function_paths = script_functions.functions_paths
            for function_idx, function_path in enumerate(function_paths):
                function_name = script_functions.functions[function_idx]

                # regex to match function name and all the comments above it
                function_name_regex = r"(?P<function_name>\b" + function_name + r"\b)"
                function_match_indices = []

                for line_idx, line in enumerate(lines):
                    if line.strip().startswith("#"):
                        continue
                    if re.search(function_name_regex, line):
                        function_match_indices.append(line_idx)

                for function_match_idx in function_match_indices:
                    lines_indices_to_modify_range = []
                    lines_indices_to_modify_range.append(function_match_idx)
                    prev_line_idx = function_match_idx - 1
                    while True:
                        if prev_line_idx < 0:
                            break
                        if lines[prev_line_idx].strip().startswith("#"):
                            lines_indices_to_modify_range.append(prev_line_idx)
                        else:
                            break
                        prev_line_idx -= 1

                    lines_indices_to_modify_range = list(
                        sorted(lines_indices_to_modify_range)
                    )
                    self.blocks.append(
                        TargetScriptFunctionBlock(
                            target_script_path=self.path,
                            function_name=function_name,
                            function_path=function_path,
                            block=lines_indices_to_modify_range,
                        )
                    )
        # sort blocks by line number
        self.blocks = sorted(self.blocks, key=lambda x: x.block[0])
        new_blocks = []
        for i, block_out in enumerate(self.blocks):
            for block_in in self.blocks[i + 1 :]:
                if block_in != block_out:
                    if block_out.should_merge(block_in):
                        block_out.merge(block_in)
                        # remove block_in from self.blocks
                        self.blocks.remove(block_in)
            new_blocks.append(block_out)

        # self.blocks = [block for i, block in enumerate(new_blocks) if block not in new_blocks[:i]]

        indices_and_function_paths = []
        for block in self.blocks:
            # print("\033[92m" + str(block) + "\033[0m")
            # Commented since its not used
            # maybe_modified_block = block.add_comment(lines)
            if block.modified:
                # print("\033[91m======Modified=======\033[0m")
                # print(maybe_modified_block)
                # print("====================================")
                # print(block.get_block_content(lines))
                # print("\033[91m======Modified=======\033[0m")
                pass
            # print("====================================")
            line_indices_and_function_paths = block.get_line_indices_and_function_paths(
                lines
            )
            indices_and_function_paths.append(line_indices_and_function_paths)
            # print(line_indices_and_function_paths)

        new_lines = []
        for line_idx, line in enumerate(lines):
            # check if line_idx is in indices_and_function_paths
            chunk = self.get_current_line_indices_and_function_paths(
                line_idx=line_idx,
                line_indices_and_function_paths=indices_and_function_paths,
            )
            if chunk is not None:
                for _, function_path, function_name in chunk:
                    function_name_regex = r"\b" + function_name + r"\b"
                    extracted_function_name = re.search(function_name_regex, line)
                    if not extracted_function_name:
                        continue
                    extracted_function_name = extracted_function_name.group(0)
                    if extracted_function_name != function_name:
                        continue
                    if DEBUG:
                        new_lines.append(f"\033[92m{function_path}\033[0m\n")
                    else:
                        new_lines.append(f"{function_path}\n")

            new_lines.append(line)
        # check comment blocks and remove duplicates appearing in the same block

        content = "".join(new_lines)
        return content


class TargetScript(object):
    """
    Represents a target script that needs to be updated.
    """

    SIMILARITY_RATIO_THRESHHOLD = 1.0

    def __init__(self, path: str, scripts_functions: List[ScriptFunctions]):
        """
        Initializes a TargetScript object.

        Args:
            path (str): The path to the target script file.
            scripts_functions (List[ScriptFunctions]): A list of ScriptFunctions objects.
        """
        self.path = path
        self.scripts_functions = scripts_functions
        self.content = ""

    def update_content(self):
        """
        Updates the content of the target script based on the specified script functions.

        Returns:
            TargetScript: The updated TargetScript object.
        """
        self.content = TargetScriptBlocks(
            path=self.path, scripts_functions=self.scripts_functions
        ).modify_content()
        return self

    def overwrite(self):
        """
        Overwrites the target script file with the updated content.

        Returns:
            TargetScript: The updated TargetScript object.
        """

        if not isinstance(self.content, str):
            print(f"Content of {self.path} is not a string", file=sys.stderr)
            # sys.exit(1)
            return self
        if self.content == "":
            print(f"Content of {self.path} is empty", file=sys.stderr)
            sys.exit(1)
            return self

        original_content = ""
        with open(self.path, "r") as f:
            original_content = f.read()
        if original_content == self.content:
            print(f"Content of {self.path} is the same, skipping")
            return self
        if not DEBUG:
            print(f"Overwriting {self.path}")
            with open(self.path, "w+") as f:
                f.write(self.content)
        else:
            print(f"Changes made to {self.path}")
            lines = self.content.split("\n")
            new_lines = []
            for idx, line in enumerate(lines):
                new_lines.append(f"[{idx}] {line} \n")
            content = "".join(new_lines)
            print(content)
            # print(self.content)

        return self


def extract_paths_from_dir(
    dir_path: str, extension: str = ".sh", recursive: bool = True
):
    paths = []
    if recursive:
        for root, dirs, files in os.walk(dir_path):
            for file in files:
                paths.append(os.path.join(root, file))
    else:
        paths = os.listdir(dir_path)
    # filter paths by extension
    paths = [path for path in paths if path.endswith(extension)]
    return paths


def run():
    root_dir = os.getcwd()
    common_paths = extract_paths_from_dir(dir_path=f"{root_dir}/lib/common")
    lumi_paths = extract_paths_from_dir(dir_path=f"{root_dir}/lib/LUMI")
    mn5_paths = extract_paths_from_dir(dir_path=f"{root_dir}/lib/MARENOSTRUM5")
    paths = common_paths + lumi_paths + mn5_paths

    scripts_functions = [
        ScriptFunctions(path)
        .extract_functions()
        .create_function_paths(root_dir=root_dir)
        for path in paths
    ]
    target_paths = extract_paths_from_dir(
        dir_path=f"{root_dir}/templates", extension=".sh", recursive=True
    )
    target_scripts = [
        TargetScript(path, scripts_functions).update_content() for path in target_paths
    ]
    for t in target_scripts:
        t.overwrite()

    if DEBUG:
        print("\033[91mDebug mode is on. Changes are not overwritten!!\033[0m")


if __name__ == "__main__":
    run()
