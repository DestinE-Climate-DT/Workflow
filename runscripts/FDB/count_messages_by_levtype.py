import argparse
import json
from pathlib import Path
import typing as T

from runscripts.FDB.count_expected_messages import main as count_expected_messages


LEVTYPES = ["sfc", "pl", "o2d", "o3d", "hl", "sol"]


def parse_arguments(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-p",
        "--profiles-path",
        required=True,
        help="Path to the profiles directory to be checked.",
    )
    parser.add_argument("--expver", help="Expid of the FDB")
    parser.add_argument("--experiment", help="MultIO experiment name")
    parser.add_argument("--activity", help="MultIO activity name")
    parser.add_argument("--generation", help="Generation key in FDB")
    parser.add_argument("--realization", help="Realization key in FDB")
    parser.add_argument("--model", help="Model name")
    parser.add_argument("--startdate", help="Start date of the request")
    parser.add_argument("--enddate", help="End date of the request")
    return parser.parse_args(argv)


def count_messages_in_file(file: str, args: argparse.Namespace) -> int:
    """ "
    Count the expected number of GRIB messages from a request file.

    Calculation is done by parsing the file and additional args
    to the count_messages_in_file function.

    If the result of the calculation is None, an error is raised. This
    scenario happens when a monthly profile is used with a submonthly
    chunk.

    Arguments
    ---------
    file: str
        Path to the request profile file.
    args: argparse.Namespace
        Additional arguments used to update the profile request.

    Returns
    -------
        int: The expected number of GRIB messages.
    """
    argv = [
        "--file",
        file,
        "--expver",
        args.expver,
        "--experiment",
        args.experiment,
        "--activity",
        args.activity,
        "--generation",
        args.generation,
        "--realization",
        args.realization,
        "--model",
        args.model,
        "--startdate",
        args.startdate,
        "--enddate",
        args.enddate,
    ]
    result = count_expected_messages(argv)
    if result is None:
        raise ValueError(
            "Submonthly chunks not allowed"
        )  # Substitute for custom exception
    return result


def get_counting_fn(args: argparse.Namespace) -> T.Callable[[T.Union[str, Path]], int]:
    """
    Return function that counts messages in a file using provided args.


    This is a wrapper around count_messages_in_file to allow partial
    application of the args parameter.

    Arguments
    ---------
    args : argparse.Namespace
        args: Arguments needed for counting messages.

    Returns
    -------
    Callable[[Union[str, Path]], int]: Function that takes a file
                                       path and returns the expected
                                       number of GRIB messages.
    """

    def f(file):
        return count_messages_in_file(str(file), args)

    return f


def get_levtype(file: str) -> str:
    """
    Get levtype from the filename.

    Arguments
    ---------
    file : str
        Path to the request profile file.

    Returns
    -------
        str: Levtype extracted from the filename.
    """
    return Path(file).name.split("_")[0]


def get_frequency(file: str) -> str:
    """
    Get frequencdy from the filename.

    Arguments
    ---------
    file : str
        Path to the request profile file.

    Returns
    -------
        str: Frequency extracted from the filename.
    """
    return Path(file).name.split("_")[-3]


def is_monthly(file: str) -> bool:
    """
    Check if the file corresponds to a monthly frequency.

    Arguments
    ---------
    file : str
        Path to the request profile file.

    Returns
    -------
        bool: True if the frequency is monthly, False otherwise.
    """
    return get_frequency(file) == "monthly"


def group_by_levtype(
    profiles: T.List[T.Union[str, Path]],
) -> T.Dict[str, T.List[T.Union[str, Path]]]:
    """
    Group profiles by their levtype.

    Arguments
    ---------
    profiles : List[Union[str, Path]]
        List of paths to the request profile files.

    Returns
    -------
        Dict[str, List[Union[str, Path]]]: Dictionary mapping levtypes
                                           to lists of profile files.
    """
    profiles_by_levtype = {}
    for profile in profiles:
        levtype = get_levtype(profile)

        if levtype not in profiles_by_levtype:
            profiles_by_levtype[levtype] = []

        profiles_by_levtype[levtype].append(profile)

    return profiles_by_levtype


def main(argv=None):
    """
    Main function to count expected GRIB messages by levtype and stream.

    Considered LEVTYPES are defined at the top of the script. The script
    will always return a count for each levtype. If no profiles match
    a given levtype, the count will default to zero.

    The counts for clte and clmn are returned separately. A total number
    of messages across all levtype is also provided for each stream.

    Arguments
    ---------
    argv : List[str], optional
        Command line arguments. If None, defaults to sys.argv.

    Returns
    -------
        Dict[str, Dict[str, int]]: Dictionary with counts of expected
                                   GRIB messages by stream and levtype.
    """
    args = parse_arguments(argv)
    profiles = list(Path(args.profiles_path).glob("*.yaml"))
    profiles_by_levtype = group_by_levtype(profiles)

    # Get message count by levtype and stream
    counting_fn = get_counting_fn(args)
    n_clte_messages_by_levtype = {
        levtype: sum(map(counting_fn, filter(lambda x: not is_monthly(x), profiles)))
        for levtype, profiles in profiles_by_levtype.items()
    }
    n_clmn_messages_by_levtype = {
        levtype: sum(map(counting_fn, filter(is_monthly, profiles)))
        for levtype, profiles in profiles_by_levtype.items()
    }

    n_clte_messages_by_levtype["total"] = sum(n_clte_messages_by_levtype.values())
    n_clmn_messages_by_levtype["total"] = sum(n_clmn_messages_by_levtype.values())

    return {"clte": n_clte_messages_by_levtype, "clmn": n_clmn_messages_by_levtype}


if __name__ == "__main__":
    print(json.dumps(main()))  # Json output for easier parsing
