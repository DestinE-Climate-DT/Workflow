import argparse
from datetime import datetime
from shutil import copyfileobj
import typing as T

import pyfdb
import yaml
from gsv.requests.parser import parse_request


def parse_arguments(argv=None) -> argparse.Namespace:  # pragma: no cover
    """
    Parse command line arguments.

    Returns
    -------
    argparse.Namespace
        Arguments parsed from the command line.
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", help="Path to the YAML file")
    parser.add_argument("--expid", help="Expid of the FDB")
    parser.add_argument("--experiment", help="Experiment type")
    parser.add_argument("--startdate", help="Start date of the request")
    parser.add_argument("--enddate", help="End date of the request")
    parser.add_argument("--chunk", help="Chunk number")
    parser.add_argument("--model", help="Model")
    parser.add_argument("--activity", help="Activity")
    parser.add_argument("--realization", help="Realization")
    parser.add_argument("--generation", help="Generation key in FDB")
    parser.add_argument("--grib_file_name", help="Output GRIB file name")
    return parser.parse_args(argv)


def read_profile(profile_name: str) -> T.Dict[str, T.Any]:  # pragma: no cover
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
    Update content of request with values provided in args.

    Arguments
    ---------
    request: Dict[T.Any, str]
        MARS request with the default values in the profile file.
    args: argparse.Namespace
        Arguments parsed from the command line. It must contain
        expid, experiment, startdate, enddate, chunk, model and activity.
    """
    request["expver"] = args.expid
    request["experiment"] = args.experiment
    request["model"] = args.model
    request["activity"] = args.activity
    request["realization"] = args.realization
    request["generation"] = args.generation
    request["date"] = args.startdate + "/to/" + args.enddate

    # Ensure date has
    if "month" in request:  # Overwrite month/year if present
        del request["month"]
    if "year" in request:
        del request["year"]
    if "time" not in request:  # Set dummy time for monthly mean profiles
        request["time"] = "0000"

    return request


def get_month_and_year_to_retrieve(
    dates: T.List[T.Union[str, int]],
) -> T.Tuple[T.List[int], T.List[int]]:
    """
    Get the month and year to retrieve from the date list.

    Months and years are only retrieved if the first day of the month
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


def report_processed_request(request: T.Dict[str, T.Any]) -> None:  # pragma: no cover
    """
    Print the content of the request after it has been processed.

    Arguments
    ---------
    request: Dict[T.Any, str]
        MARS request with the default values in the profile file.
    """
    print("PROCESSED REQUEST:")
    print(request)


def retrieve_request(request: T.Dict[str, T.Any], grib_file_name: str) -> None:
    """
    Retrieve data from FDB and store it in a GRIB file.

    Arguments
    ---------
    request: Dict[T.Any, str]
        MARS request with the default values in the profile file.
    grib_file_name: str
        Name of the GRIB file to store the retrieved data.
    """
    # Print request sent to FDB
    report_processed_request(request)

    # Retrieve data from FDB
    fdb = pyfdb.FDB()
    datareader = fdb.retrieve(request)

    # Write data to GRIB file
    with open(grib_file_name, "wb") as grib_file:
        copyfileobj(datareader, grib_file)


def main(argv=None):
    """
    Main function to encapsulate the reading of data from a profile.

    The profile is read from a YAML file, and the request is updated
    with the values provided in the command line arguments. The updated
    values are 'expver', 'experiment', 'activity', 'model' and 'date'.

    A special treatment is considered for monthly profiles, where the request
    is transformed to 'month'/'year' format and it is only read if the
    first day of the month was present in the original list of dates.
    This ensures that monthly means are only retrieved once.
    """
    # Read profile
    args = parse_arguments(argv)
    profile = read_profile(args.file)
    grib_file_name = args.grib_file_name

    # Report original profile
    print("ORIGINAL PROFILE: ")
    print(profile)

    # Update profile request
    request = profile["mars-keys"]
    request = update_request(request, args)
    request = parse_request(request)  # Render start/to/end to date list

    if profile["date-format"] == "month":
        # For monthly profiles, only retrieve if the request is for the first day of the month
        month, year = get_month_and_year_to_retrieve(request["date"])
        if month and year:  # Ensure at least one month is present
            request["month"] = month
            request["year"] = year
            if "date" in request:
                del request["date"]
            if "time" in request:
                del request["time"]
            retrieve_request(request, grib_file_name)

    else:  # For hourly and daily profiles always retrieve
        retrieve_request(request, grib_file_name)


if __name__ == "__main__":
    main()
