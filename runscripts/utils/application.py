"""Utils module for Apps-workflow-related components."""

from argparse import ArgumentParser
from dataclasses import dataclass, field
from glob import glob
import os
import typing as T
import warnings
import yaml

from gsv.requests.parser import parse_request

__all__ = [
    "AppExperiment",
    "add_app_experiment_arguments",
    "get_app_experiment_parser",
    "read_requests",
]


@dataclass
class AppExperiment:
    """
    Data class representing an application experiment configuration.

    Attributes:
        chunk (int): Chunk number.
        split (int): Chunk split.
        expid (str): Experiment ID, e.g. a000.
        startdate (str): Simulation start date(s), e.g. 20160101
        member str: Member name, e.g. "fc0", "fc1", etc.
        realization (Optional[int]): Member number (default: None).
        app_names (List[str]): List of app names to be run (default: empty list).
        _request_prefix (str): Prefix for request files (default: "request_").
        _request_suffix (str): Suffix for request files (default: "").
    """

    chunk: int
    split: int
    expid: str
    startdate: str
    member: str
    realization: int = 1
    app_names: T.List[str] = field(default_factory=list)
    _request_prefix: str = "request_"
    _request_suffix: str = ""

    def __post_init__(self):
        # Lowercase app_names
        self.app_names = list(map(str.lower, self.app_names))

    @classmethod
    def from_argv(cls, argv, *, warn=False):
        """
        Create an AppExperiment instance from command-line arguments.

        Args:
            argv (list): List of command-line arguments.
            warn (bool): Whether to warn about unknown arguments (default: False).

        Returns:
            AppExperiment: An instance of AppExperiment populated from argv.
        """
        parser = get_app_experiment_parser()
        args, unknown_args = parser.parse_known_args(
            [arg for arg in argv if arg.startswith("--")]
        )
        if unknown_args and warn:
            warnings.warn(f"Unknown arguments: {', '.join(unknown_args)}.")
        return cls(
            chunk=args.chunk,
            split=args.split,
            expid=args.expid,
            startdate=args.startdate,
            member=args.member,
            app_names=args.app_names,
        )

    def get_requests(self, directory, split=True):
        """
        Read and parse request files from a directory for the experiment.

        The following structure is expected:

        directory/
            request_<app_name>_<start_date>_<member>_<chunk>_<split>.yml
            request_<app_name>_<start_date>_<member>_<chunk>_<split>.yml
            ...

        Each one of the requests are expected to have the following structure:

        APP_NAME:
            1:
                GSVREQUEST:
                    ...
                OPAREQUEST:
                    ...
            2:
                GSVREQUEST:
                    ...
                OPAREQUEST:
                    ...
            ...

        If split is True, the requests are returned as a dictionary with the following structure:
        {
            "app_name_A": [
                request_A_1,
                request_A_2,
                ...
            ],
            "app_name_B": [
                request_B_1,
                request_B_2,
                ...
            ],
            ...
        }

        where request_<x>_<i> stands for the i-th request for app_name_x. This structure is duplicated,
        one for GSV requests and one for OPA requests.

        If split is False, raise NotImplementedError.

        Args:
            directory (str): Directory containing request files.
            split (bool): Whether to split requests by app (default: True).

        Returns:
            tuple: (gsvrequests, oparequests) if split is True.

        Raises:
            NotImplementedError: If split is False.
            FileNotFoundError: If the directory does not exist.

        """

        request_files = self.get_request_files(directory)
        requests = {}
        empty_request_files = []
        for request_file in request_files:
            print(f"Reading request file: {request_file}")
            with open(request_file, "r", encoding="utf-8") as f:
                request_data = yaml.safe_load(f)
                if request_data is None:
                    empty_request_files.append(request_file)
                requests.update(request_data)
        if empty_request_files:
            warnings.warn(
                f"Empty request files encountered: {', '.join(empty_request_files)}."
            )
        if not split:
            raise NotImplementedError("split must be True.")
        return read_requests(requests, self.realization)

    def get_request_files(self, directory):
        """
        Get the list of request files in the specified directory
        matching the experiment configuration.

        Args:
            directory (str): Directory to search for request files.

        Returns:
            list: List of matching request file paths.

        Raises:
            FileNotFoundError: If the directory does not exist.
        """
        if not os.path.exists(directory):
            raise FileNotFoundError(f"Directory {directory} does not exist.")
        prefix = self._request_prefix if self._request_prefix else ""
        suffix = self._request_suffix if self._request_suffix else ""
        file_name = f"{prefix}*{self.startdate[0]}_{self.member}_{self.chunk}_{self.split}{suffix}"
        pattern = os.path.join(directory, file_name)
        request_files = glob(pattern)

        print(f"Request pattern: {pattern}")
        if self.app_names:
            request_files = list(
                filter(
                    lambda x: any(
                        app_name.lower() in x.lower() for app_name in self.app_names
                    ),
                    request_files,
                )
            )
        print(f"Request files: {', '.join(request_files)}")
        return request_files


def add_app_experiment_arguments(parser):
    """
    Add AppExperiment-related arguments to an ArgumentParser.

    Args:
        parser (ArgumentParser): The argument parser to add arguments to.

    Returns:
        ArgumentParser: The parser with added arguments.
    """
    group = parser.add_argument_group("AppExperiment")
    group.add_argument(
        "--chunk", type=int, required=True, help="Input chunk number for data notifier"
    )
    group.add_argument(
        "--split", type=int, required=True, help="Input split number data notifier"
    )
    group.add_argument("--expid", type=str, required=True, help="Experiment id")
    group.add_argument("--app_names", type=str, nargs="*", help="App(s) to be run")
    group.add_argument("--member", type=str, help="Member name", default="")
    group.add_argument("--realization", type=int, help="Member number", default=None)
    group.add_argument(
        "--startdate", type=str, nargs="*", help="Simulation start date(s)"
    )
    return parser


def get_app_experiment_parser():
    """
    Create and return an ArgumentParser for app experiments.

    Returns:
        ArgumentParser: Configured argument parser for app experiments.
    """
    parser = ArgumentParser("Simple parser for app experiments")
    add_app_experiment_arguments(parser)
    return parser


def _update_gsv_request(gsv_request, realization):
    # Override realization, if provided
    gsv_request["realization"] = (
        realization if realization is not None else gsv_request["realization"]
    )

    # Convert model and activity to lowercase (see Workflow issue 585)
    gsv_request["model"] = gsv_request["model"].lower()
    gsv_request["activity"] = gsv_request["activity"].lower()

    gsv_request = parse_request(gsv_request)

    # Do not rely on in-place changes
    return gsv_request


def read_requests(all_requests, realization):
    """
    Parse and update all GSV and OPA requests from the provided dictionary.

    Args:
        all_requests (dict): Dictionary of all requests grouped by app name.
        realization (int or None): Realization value to override in GSV requests.

    Returns:
        tuple: (gsvrequests, oparequests) lists of parsed requests.
    """

    gsvrequests = []
    oparequests = []

    for app_name, app_requests in all_requests.items():
        for _, request in app_requests.items():
            # check only apps that are requested
            print(f"Application being checked: {app_name}")
            print(f"Variables requested: {request['GSVREQUEST']['param']}")

            gsv_request = request["GSVREQUEST"]
            opa_request = request["OPAREQUEST"]

            # Replace and filling necessary fields
            gsv_request = _update_gsv_request(gsv_request, realization)

            oparequests.append(opa_request)
            gsvrequests.append(gsv_request)

    return gsvrequests, oparequests
