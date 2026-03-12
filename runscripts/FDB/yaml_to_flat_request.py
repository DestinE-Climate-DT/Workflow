import argparse
from datetime import datetime
import os
import typing as T

import yaml

from gsv.requests.parser import parse_request


def parse_arguments(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", help="Path to the YAML file")
    parser.add_argument("--expver", help="Expid of the FDB")
    parser.add_argument("--experiment", help="MultIO experiment name")
    parser.add_argument("--activity", help="MultIO activity name")
    parser.add_argument("--model", help="Model name")
    parser.add_argument("--generation", help="Generation key in FDB")
    parser.add_argument("--realization", help="Realization key in FDB")
    parser.add_argument("--startdate", help="Start date of the request")
    parser.add_argument("--enddate", help="End date of the request")
    parser.add_argument("--chunk", help="Chunk number")
    parser.add_argument(
        "--omit-keys",
        required=False,
        help="Keys to be omitted in the resulting request",
    )
    parser.add_argument("--request_name", help="Name of the request")
    return parser.parse_args(argv)


def read_profile(profile_name: str) -> T.Dict[str, T.Any]:
    """
    Read a YAML file and return its content as a dictionary.

    Arguments
    ---------
    profile_name: str
        Path to the YAML file.

    Returns
    -------
    str
        A dictionary with the content of the YAML file.
    """
    with open(profile_name, "r") as file:
        data = yaml.safe_load(file)
    return data


def update_request(request, args: argparse.Namespace) -> T.Dict[str, T.Any]:
    """
    Update the request with the arguments provided in the command line.

    Updated keys are expver, experient, activity, model, generation,
    realization, and date.

    The request is always transformed to a date/time, regardless
    of the original format. The monthly profiles are handled later
    in the script.

    Arguments
    ---------
    request: Dict[str, Any]
        Original request from the profile.
    args: argparse.Namespace
        Arguments from the command line.

    Returns
    -------
    Dict[str, Any]
        Updated request.
    """
    request["expver"] = args.expver
    request["date"] = args.startdate + "/to/" + args.enddate
    request["experiment"] = args.experiment
    request["activity"] = args.activity
    request["model"] = args.model
    request["generation"] = args.generation
    request["realization"] = args.realization

    # Ensure date is always is in date/time format
    if "month" in request:  # Overwrite month/year if present
        del request["month"]
    if "year" in request:
        del request["year"]
    if "time" not in request:  # Set dummy time for monthly mean profiles
        request["time"] = "0000"

    return request


def get_month_and_year_to_wipe(
    dates: T.List[T.Union[str, int]],
) -> T.Tuple[T.List[int], T.List[int]]:
    """
    Get the month and year to wipe (or check) from the date list.

    Months and years are only considered if the first day of the month
    is in the original list of dates.

    Note: this approach can lead to undesired results in some edge cases,
    like dates spanning multiple over multiple months and crossing new
    years eve. For the moment, it is assumed that this requests will not
    be provided, as this script is meant to only be launched by the
    workflow.

    Arguments
    ---------
    dates: List[str | int]
        List of dates in the format YYYYMMDD.

    Returns
    -------
    List[int]
        List of months to retrieve.
    List[int]
        List of years to retrieve.
    """
    dates_dt = list(
        map(lambda x: datetime.strptime(str(x), "%Y%m%d"), dates)
    )  # Convert str dates to datetime objects
    months_to_retrieve = sorted(
        list({str(date.month) for date in dates_dt if date.day == 1})
    )
    years_to_retrieve = sorted(
        list({str(date.year) for date in dates_dt if date.day == 1})
    )
    return months_to_retrieve, years_to_retrieve


def write_wiping_flat_request(
    request: T.Dict[str, T.Any], flat_request_filename: str
) -> None:
    """
    Writes the content of the request to a .flat (flattened MARS keys).

    Request values are written in the format key=value, separated by commas.
    List must be represented as a string, joined by a slash

    At the end of the file, the comma after the last key must be removed.

    Arguments
    ---------
    request: Dict[str, Any]
        MARS request to be written to the file.
    flat_request_filename: str
        Name of the file to write the request.
    """

    with open(flat_request_filename, "w") as marsrq:
        for key in request:
            if not isinstance(request[key], list):
                marsrq.write(str(key) + "=" + str(request[key]) + ",")
            else:
                marsrq.write(str(key) + "=" + "/".join(request[key]) + ",")

    with open(flat_request_filename, "rb+") as filehandle:
        filehandle.seek(-1, os.SEEK_END)
        filehandle.truncate()


def main(argv=None):
    """
    Main function for the creation of a flat MARS request from a profile.

    The flat request is just a concatennation of the keys and values for
    a MARS request in a FDB-like syntax. This can be directly parsed as
    argument for an fdb-list or fdb-wipe command.

    The profile is read from a YAML file, and the request is updated
    with the values provided in the command line arguments. The updated
    values are 'expver', 'experiment', 'activity', 'model', 'generation',
    'realization' and 'date'.

    A special treatment is considered for monthly profiles, where the request
    is transformed to 'month'/'year' format and it is only read if the
    first day of the month was present in the original list of dates.
    This ensures that monthly means are only retrieved once.
    """
    args = parse_arguments(argv)
    profile = read_profile(args.file)

    # Update profile request
    request = profile["mars-keys"]
    request = update_request(request, args)
    request = parse_request(profile["mars-keys"])

    # Write the MARS request to a file
    flat_request_filename = args.request_name
    if profile["date-format"] == "month":
        # For monthly profiles, only generate flat request if the first day of the month is present
        month, year = get_month_and_year_to_wipe(request["date"])
        if month and year:  # Ensure at least one month is present
            request["month"] = month
            request["year"] = year
            if "date" in request:
                del request["date"]
            if "time" in request:
                del request["time"]

    # For hourly and daily profiles always retrieve
    # Remove keys if necessary
    if args.omit_keys is not None:
        keys_to_omit = args.omit_keys.split(",")
        for key in keys_to_omit:
            if key in profile["mars-keys"]:
                del profile["mars-keys"][key]

    write_wiping_flat_request(request, flat_request_filename)


if __name__ == "__main__":
    main()
