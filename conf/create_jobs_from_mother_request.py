import argparse
import copy
import sys
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List

from ruamel.yaml import YAML

yaml = YAML()

"""This creates the jobs.yml from the mother request coming from all the applications."""


class WorkflowType(str, Enum):
    """Valid workflow types."""

    END_TO_END = "end-to-end"
    APPS = "apps"

    @staticmethod
    def list():
        return list(map(lambda c: c.value, WorkflowType))


def write_files(output_path: Path, jobs: Dict, main_yml: Dict) -> None:
    """
    Gets the jobs dictionary and creates the jobs lists given the details in main.yml.
    """
    if main_yml["RUN"]["WORKFLOW"] == WorkflowType.END_TO_END:
        # Output a new jobs file
        out_filename = output_path / "jobs_end-to-end.yml"
        with open(out_filename, "w") as outfile:
            yaml.dump(jobs, outfile)

        with open(out_filename, "r") as file:
            content = file.read()
            final_content = content.replace("\"'", '"')
            final_content = final_content.replace("'\"", '"')

        # FIXME: we can probably do this in one go, without open/write/close multiple times.
        # Writing the modified content back to the file
        with open(out_filename, "w") as file:
            file.write(final_content)
        print("jobs_end-to-end.yml has been created.")

    elif main_yml["RUN"]["WORKFLOW"] == WorkflowType.APPS:
        # write apps jobs file (no ini, no sim):
        jobs_apps = copy.deepcopy(jobs)

        del jobs_apps["JOBS"]["SIM"]
        del jobs_apps["JOBS"]["INI"]
        # del jobs_apps['JOBS']['DQC']

        out_filename = output_path / "jobs_apps.yml"
        with open(out_filename, "w") as outfile:
            yaml.dump(jobs_apps, outfile)

        with open(out_filename, "r") as file:
            content = file.read()
            final_content = content.replace("\"'", '"')
            final_content = final_content.replace("'\"", '"')

        # FIXME: we can probably do this in one go, without open/write/close multiple times.
        with open(out_filename, "w") as file:
            file.write(final_content)
        print("jobs_apps.yml has been created.")

    # TODO: the if/else above can probably be removed by modifying the function signature...


def _parse_args(args) -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(prog="create_jobs_from_mother_request")
    parser.add_argument(
        "-p",
        "--path-to-conf",
        dest="path_to_conf",
        required=True,
        type=Path,
        help="Path to configuration files",
    )
    parser.add_argument(
        "-m",
        "--main",
        dest="main",
        required=True,
        type=Path,
        help="Main configuration file (main.yml/main.yaml)",
    )
    parser.add_argument(
        "-o",
        "--output-path",
        dest="output_path",
        type=Path,
        default=".",
        help="The output path to write files to. Defaults to the CWD.",
    )
    return parser.parse_args(args)


def _load_yaml(yaml_file: Path) -> Any:
    """Load a YAML file."""
    with open(yaml_file, "r") as f:
        yaml = YAML(typ="safe", pure=True)
        return yaml.load(f)


def _validate_main_yaml(main_yaml: Dict) -> None:
    """Validate main.yaml contents."""

    if "APP" in main_yaml and "NAMES" not in main_yaml["APP"]:
        print(
            "No 'APP.NAME' found in main.yml. This means "
            "that you want to run a model without applications "
            "or that you did a mistake."
        )
        sys.exit(0)

    # These are the valid workflow types to create a mother-request from.
    if main_yaml["RUN"]["WORKFLOW"] not in WorkflowType.list():
        raise ValueError("RUN.WORKFLOW in main.yml is not apps nor end-to-end")


def _check_elements_in_list(app_requested: List[str], app_available: List[str]) -> None:
    """Check that all requested apps have a request defined in ``mother_request.yml``."""
    if not app_requested:
        raise ValueError(
            "You should at least request one application. Check your <expid>/conf/main.yml"
        )

    if not all(element in app_available for element in app_requested):
        missing_elements = [
            element for element in app_requested if element not in app_available
        ]
        raise ValueError(
            f"Not all requested applications {app_requested} are currently able to run. Check the current ones in {app_available}. Missing apps: {missing_elements}"
        )


# TODO check if this is really needed after #801
def _get_opa_names(app_requested: List[str], all_requests: Dict) -> List[str]:
    """Fill OPA fields."""
    opa_names: List[str] = list()
    for app in app_requested:
        num_var = len(all_requests[str(app)])
        opa_names.append(f"{app.lower()}")
    return opa_names


def _get_opa_dependencies(opa_names: List[str]) -> List[Dict]:
    """Get the OPA dependencies."""
    jobs_opa_for_dependencies: List[Dict] = list()
    for opa in list(opa_names):
        num_var = 1

        tmp_dict = None
        for i in range(1, num_var + 1):
            tmp_dict = [
                {
                    "DN": {
                        "SPLITS_FROM": {
                            "all": {"SPLITS_TO": '"[1:%JOBS.DN.SPLITS%]*\\\\1"'}
                        }
                    },
                    f"OPA_{opa.upper()}": {
                        "SPLITS_FROM": {
                            "all": {"SPLITS_TO": "previous", "STATUS": "FAILED"}
                        }
                    },
                }
            ]

        result_dict = {key: value for d in tmp_dict for key, value in d.items()}
        jobs_opa_for_dependencies.append(result_dict)
    return jobs_opa_for_dependencies


def update_dict_recursively(base_dict, new_dict):
    for key, value in new_dict.items():
        if (
            isinstance(value, dict)
            and key in base_dict
            and isinstance(base_dict[key], dict)
        ):
            update_dict_recursively(base_dict[key], value)
        else:
            base_dict[key] = value


def main(args=None):
    """
    Given request file with the information relevant to run the applications and a jobs template file, it dynamically creates a
    jobs.yml file which can be run as application workflow.
    """
    args = _parse_args(args)
    path_to_conf: Path = args.path_to_conf

    # Open files
    file_mother_request: Path = path_to_conf / "mother_request.yml"
    file_jobs: Path = path_to_conf / "jobs_template.yml_tmp"
    app_list_source = args.main  # "../../../conf/main.yml"

    output_path = args.output_path

    # TODO: Here we can probably have a single function that returns the three files
    #       already validated, e.g. ``all, jobs, main = _load_yamls(args.main, args....)``
    #       where ``_load_yamls`` would take care to load, in order, and validate all,
    #       finally returning a tuple or dataclass. Easier to isolate and test too.
    # Get data from inside:
    all_requests: Dict = _load_yaml(file_mother_request)

    # Extract GSV request from YAML file
    jobs: Dict = _load_yaml(file_jobs)

    # Get list of apps that we want to run:
    main_yml: Dict = _load_yaml(app_list_source)

    _validate_main_yaml(main_yml)

    # Modify jobs accordingly to mother req

    app_requested: List[str] = main_yml["APP"]["NAMES"]
    app_available: List[str] = list(
        all_requests.keys()
    )  # apps available in the mother request
    _check_elements_in_list(app_requested, app_available)

    # replace app names
    jobs["RUN"]["APP_NAMES"] = app_requested

    # OPA names.
    opa_names: List = _get_opa_names(app_requested, all_requests)
    jobs["RUN"]["OPA_NAMES"] = opa_names
    jobs["JOBS"]["OPA"]["FOR"]["SPLITS"] = str(
        [jobs["JOBS"]["DN"]["SPLITS"]] * len(app_requested)
    )

    # OPA dependencies.
    jobs_opa_for_dependencies: List[Dict] = _get_opa_dependencies(opa_names)
    jobs["JOBS"]["OPA"]["FOR"]["DEPENDENCIES"] = jobs_opa_for_dependencies

    # Splits
    jobs["JOBS"]["APP"]["FOR"]["SPLITS"] = str(
        [jobs["JOBS"]["DN"]["SPLITS"]] * len(app_requested)
    )

    # App dependencies
    jobs_app_for_dependencies = list()
    for app in list(app_requested):
        num_var = len(all_requests[str(app)])
        jobs_app_for_dependencies_tmp = list()
        for i in range(1, len(app_requested) + 1):
            jobs_app_for_dependencies_tmp.append(
                {
                    f"OPA_{app.upper()}": {
                        "SPLITS_FROM": {
                            "all": {
                                "SPLITS_TO": '"[1:%JOBS.DN.SPLITS%]*\\\\1"',
                                "STATUS": "FAILED",
                            }
                        }
                    }
                }
            )
        jobs_app_for_dependencies_tmp.append(
            {
                f"APP_{app.upper()}": {
                    "SPLITS_FROM": {
                        "all": {"SPLITS_TO": "previous", "STATUS": "FAILED"}
                    }
                }
            }
        )
        # TODO: \\1 is the frequency app runs (1=1 day, 2=2 days). Possibly some other modifications needed.
        list_of_dicts = jobs_app_for_dependencies_tmp
        result_dict = {key: value for d in list_of_dicts for key, value in d.items()}
        jobs_app_for_dependencies.append(result_dict)

    # Put everything in a jobs.yml
    jobs["JOBS"]["APP"]["FOR"]["DEPENDENCIES"] = jobs_app_for_dependencies

    # DN dependecnies
    jobs_dn_dependencies = {}

    # add only SIM dependency if end to end
    for app in list(app_requested):
        if main_yml["RUN"]["WORKFLOW"] == WorkflowType.END_TO_END:
            tmp_dict = {
                "SIM": {"STATUS": "RUNNING"},
                "DN": {"SPLITS_FROM": {"all": {"SPLITS_TO": "previous"}}},
                f"APP_{app.upper()}-1": {"STATUS": "FAILED"},
            }
        if main_yml["RUN"]["WORKFLOW"] == WorkflowType.APPS:
            tmp_dict = {
                "REMOTE_SETUP": {"STATUS": "COMPLETED"},
                "DN": {"SPLITS_FROM": {"all": {"SPLITS_TO": "previous"}}},
                f"APP_{app.upper()}-1": {"STATUS": "FAILED"},
            }
        update_dict_recursively(jobs_dn_dependencies, tmp_dict)

    # put everything in a jobs.yml
    jobs["JOBS"]["DN"]["DEPENDENCIES"] = jobs_dn_dependencies

    # create jobs_XXX.yml:
    write_files(output_path, jobs, main_yml)


if __name__ == "__main__":
    main()
