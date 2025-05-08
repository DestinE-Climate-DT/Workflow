import argparse
from copy import deepcopy
import typing as T
import yaml


def parse_arguments(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", help="Path to the YAML file", required=True)
    parser.add_argument(
        "--data_start_date", help="Updated start date of the experiment"
    )
    parser.add_argument("--data_end_date", help="Updated end date of the experiment")
    parser.add_argument("--bridge_start_date", help="Updated start date of the bridge")
    parser.add_argument("--bridge_end_date", help="Updated end date of the bridge")
    parser.add_argument("--expver", help="Expver of the FDB")
    parser.add_argument("--bridge_expver", help="Expver of data in the bridge")
    parser.add_argument("--create", help="Create a new YAML file", action="store_true")
    parser.add_argument(
        "--bridge_end_hour", default="2300", help="End hour of the data in the bridge"
    )
    parser.add_argument(
        "--bridge_start_hour",
        default="0000",
        help="Start hour of the data in the bridge",
    )
    parser.add_argument(
        "--data_end_hour", default="2300", help="End hour of the data in the HPC"
    )
    parser.add_argument(
        "--data_start_hour", default="0000", help="Start hour of the data in the HPC"
    )
    return parser.parse_args(argv)


def load_yaml(file_path: str) -> T.Dict[str, T.Any]:
    with open(file_path, "r") as file:
        return yaml.safe_load(file)


def save_yaml(file_path: str, data: T.Dict[str, T.Any]):
    with open(file_path, "w") as file:
        yaml.safe_dump(data, file)


def update_dictionary(
    data: T.Dict[str, T.Any], updates: T.Dict[str, str], hours: T.Dict[str, str]
) -> T.Dict[str, T.Any]:
    """
    Update the content of data dictionary with the values from updates.

    Keys with dots on the update dictionary are split into nested
    keys in the target dictionary.

    Example:
    data = {}
    updates = {"data.data_start_date": "2020-01-01"}
    udpate_dictionary(data, updates)
    # returns {"data": {"data_start_date": "2020-01-01"}}

    Args:
    data: Dictionary to be updated
    updates: Dictionary with the updates

    Returns:
    Updated dictionary
    """
    updated_data = deepcopy(data)
    for key, value in updates.items():
        # Don't process the hour argument
        if key.endswith("hour"):
            continue
        if value is not None:
            # If value is a date, add the hour to it
            if key.endswith("date") and value:
                value = date_with_hour(value, hours[key.replace("date", "hour")])
            section, sub_key = key.split(".")
            updated_data.setdefault(section, {})[sub_key] = value
    return updated_data


def update_yaml_file(
    file_path: str, updates: T.Dict[str, str], hours: T.Dict[str, str]
):
    """
    Update the content of a exisint YAML file with the values from updates.

    Keys with dots on the update dictionary are split into nested
    keys in the target dictionary.

    Args:
    file_path: Path to the YAML file
    updates: Dictionary with the updates
    """
    data = load_yaml(file_path)
    data = update_dictionary(data, updates, hours)
    save_yaml(file_path, data)


def create_yaml_file(
    file_path: str, updates: T.Dict[str, str], hours: T.Dict[str, str]
):
    """
    Create a YAML file and dump the content of updates dictionary there.

    Keys with dots on the update dictionary are split into nested
    keys in the target dictionary.

    Args:
    file_path: Path to the YAML file
    updates: Dictionary with the updates
    """
    data = {}
    data = update_dictionary(data, updates, hours)
    save_yaml(file_path, data)


def date_with_hour(date: str, hour: str) -> str:
    return f"{date}T{hour}"


def main(argv=None):
    args = parse_arguments(argv)
    updates = {
        "data.data_start_date": args.data_start_date,
        "data.data_end_date": args.data_end_date,
        "bridge.bridge_start_date": args.bridge_start_date,
        "bridge.bridge_end_date": args.bridge_end_date,
        "data.expver": args.expver,
        "bridge.expver": args.bridge_expver,
    }
    hours = {
        "bridge.bridge_end_hour": args.bridge_end_hour,
        "bridge.bridge_start_hour": args.bridge_start_hour,
        "data.data_end_hour": args.data_end_hour,
        "data.data_start_hour": args.data_start_hour,
    }
    if args.create:
        create_yaml_file(args.file, updates, hours)
    else:
        update_yaml_file(args.file, updates, hours)


if __name__ == "__main__":
    main()
