import argparse
from datetime import datetime
import typing as T
import yaml

from gsv import GSVRetriever
from gsv.requests.parser import parse_request
from gsv.requests.utils import count_combinations


def parse_arguments(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", help="Path to the YAML file")
    parser.add_argument("--expver", help="Expid of the FDB")
    parser.add_argument("--experiment", help="MultIO experiment name")
    parser.add_argument("--activity", help="MultIO activity name")
    parser.add_argument("--generation", help="Generation key in FDB")
    parser.add_argument("--realization", help="Realization key in FDB")
    parser.add_argument("--model", help="Model name")
    parser.add_argument("--startdate", help="Start date of the request")
    parser.add_argument("--enddate", help="End date of the request")
    parser.add_argument("--chunk", help="Chunk number")
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
    request["expver"] = args.expver
    request["date"] = args.startdate + "/to/" + args.enddate
    request["experiment"] = args.experiment
    request["activity"] = args.activity
    request["model"] = args.model
    request["generation"] = args.generation
    request["realization"] = args.realization

    # Ensure date has
    if "month" in request:  # Overwrite month/year if present
        del request["month"]
    if "year" in request:
        del request["year"]
    if "time" not in request:  # Set dummy time for monthly mean profiles
        request["time"] = "0000"

    return request


def get_month_and_year_to_check(
    dates: T.List[T.Union[str, int]],
) -> T.Tuple[T.List[int], T.List[int]]:
    """

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


def main(argv=None):
    # Get arguments
    args = parse_arguments(argv)
    profile = read_profile(args.file)

    # Update dynamic MARS keys
    request = profile["mars-keys"]
    request = update_request(request, args)
    request = parse_request(profile["mars-keys"])

    if profile["date-format"] == "month":
        # Update comment
        month, year = get_month_and_year_to_check(request["date"])
        if month and year:  # Ensure at least one month is present
            request["month"] = month
            request["year"] = year
            if "date" in request:
                del request["date"]
            if "time" in request:
                del request["time"]
            n_expected_messages = count_combinations(request, GSVRetriever.MARS_KEYS)
        else:
            n_expected_messages = None

    else:  # For hourly and daily profiles always retrieve
        n_expected_messages = count_combinations(request, GSVRetriever.MARS_KEYS)

    # Print result to capture output
    print(n_expected_messages)


if __name__ == "__main__":
    main()
