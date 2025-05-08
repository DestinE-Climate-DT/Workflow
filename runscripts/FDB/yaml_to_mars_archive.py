import argparse
from datetime import datetime
import os
from pathlib import Path
import typing as T

import yaml

from gsv.requests.parser import parse_request


def parse_arguments(argv=None) -> argparse.Namespace:
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
    parser.add_argument(
        "--realization", default="1", help="Realization number for ensemble members"
    )
    parser.add_argument("--generation", help="Generation key in FDB")
    parser.add_argument("--grib_file_name", help="Output GRIB file name")
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
    Update content of request with values provided in args.

    Additionally, the database key is set to databridge-fdb, since
    the request is intended to be used for archiving in the databridge.

    Arguments
    ---------
    request: Dict[T.Any, str]
        MARS request with the default values in the profile file.
    args: argparse.Namespace
        Arguments parsed from the command line. It must contain
        expid, experiment, startdate, enddate, chunk, model, activity
        and grib_file_name
    """
    request["database"] = "databridge-fdb"
    request["expver"] = args.expid
    request["experiment"] = args.experiment
    request["model"] = args.model
    request["activity"] = args.activity
    request["realization"] = args.realization
    request["date"] = args.startdate + "/to/" + args.enddate
    request["generation"] = args.generation
    request["source"] = args.grib_file_name

    # Ensure date has
    if "month" in request:  # Overwrite month/year if present
        del request["month"]
    if "year" in request:
        del request["year"]
    if "time" not in request:  # Set dummy time for monthly mean profiles
        request["time"] = "0000"

    return request


def get_month_and_year_to_archive(
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


def write_archiving_mars_request(
    request: T.Dict[str, T.Any], mars_request_filename: str
) -> None:
    """
    Writes the content of the requets to a MARS file for archiving.

    The resulting file will be used to archive the data in the databridge
    using the MARS client.

    Request values are written in the format key=value, separated by commas.
    List must be represented as a string, joined by a slash

    At the end of the file, the comma after the last key must be removed
    and the file must end with a new line.

    Arguments
    ---------
    request: Dict[str, Any]
        MARS request to be written to the file.
    mars_request_filename: str
        Name of the file to write the request.
    """
    # Write the MARS request to a file
    with open(mars_request_filename, "w") as marsrq:
        marsrq.write("archive,\n")
        print(request)
        for key in request:
            if not isinstance(request[key], list):
                marsrq.write("\t" + str(key) + "=" + str(request[key]) + ",\n")
            else:
                marsrq.write(
                    "\t" + str(key) + "=" + ("/").join(map(str, request[key])) + ",\n"
                )

    # Remove last two characters (,\n) and add a new line
    with open(mars_request_filename, "rb+") as filehandle:
        filehandle.seek(-2, os.SEEK_END)
        filehandle.truncate()

    with open(mars_request_filename, "a+") as filehandle:
        filehandle.write("\n")


def main(argv=None):
    """
    Main function for the creation of archival MARS request for a profile.

    The profile is read from a YAML file, and the request is updated
    with the values provided in the command line arguments. The updated
    values are 'expver', 'experiment', 'activity', 'model' and 'date'.

    Additional keys are added to the MARS request. These are:
     - databridge: databridge-fdb
     - source: <path-to-grib-file>

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
    request = parse_request(request)

    # Get name of archiving MARS request file
    mars_request_filename = Path(args.grib_file_name).with_suffix(".mars")

    if profile["date-format"] == "month":
        # For monthly profiles, only retrieve if the request is for the first day of the month
        month, year = get_month_and_year_to_archive(request["date"])
        if month and year:  # Ensure at least one month is present
            request["month"] = month
            request["year"] = year
            if "date" in request:
                del request["date"]
            if "time" in request:
                del request["time"]
            write_archiving_mars_request(request, mars_request_filename)

    else:  # For hourly and daily profiles always retrieve
        write_archiving_mars_request(request, mars_request_filename)


if __name__ == "__main__":
    main()
