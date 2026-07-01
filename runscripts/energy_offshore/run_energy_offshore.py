import argparse
import sys
from energy_offshore import energy_offshore as eoff

print("Energy offshore runscript starting")


def _get_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Runscript for energy offshore job.")

    # Add positional arguments or
    # https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
    parser.add_argument("--expid", required=False, help="Experiment ID", default=None)
    parser.add_argument(
        "--app", required=False, help="Name of application run", default=""
    )
    parser.add_argument(
        "--datelist", required=False, help="List of dates ?", default=None
    )
    parser.add_argument(
        "--requestfile", required=True, help="Request file in question", default=1
    )
    parser.add_argument(
        "--hpcrootdir", required=True, help="Root directory on HPC side", default=None
    )
    parser.add_argument(
        "--app_outpath",
        required=True,
        help="Out directory for the application.",
        default=None,
    )
    parser.add_argument(
        "--opa_outpath",
        required=True,
        help="In directory, data from streaming is there",
        default=None,
    )
    parser.add_argument("--start_year", required=True, help="Input start year ")
    parser.add_argument("--start_month", required=True, help="Input start month ")
    parser.add_argument("--start_day", required=True, help="Input start day ")
    parser.add_argument("--end_year", required=True, help="Input end year ")
    parser.add_argument("--end_month", required=True, help="Input end month ")
    parser.add_argument("--end_day", required=True, help="Input end day ")
    parser.add_argument(
        "--chunk", required=True, help="Input file data notifier", default=1
    )
    parser.add_argument(
        "--chunksize", required=False, help="Input file data notifier", default=1
    )
    parser.add_argument(
        "--compute_icing",
        required=True,
        help="boolean, if True compute icing, if False skip icing calculation",
        default=False,
    )
    return parser


def _normalize_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() == "true"
    raise TypeError("value should be either str or bool.")


def main():
    args = _get_parser().parse_args()

    # APP_OUTDIR=args.app_outpath
    appdir = args.hpcrootdir + "/git_project/energy_offshore"

    sys.path.append(appdir)

    print("Calling handledays()")

    compute_icing = _normalize_bool(args.compute_icing)

    # Assume reduce portfolio is in place when not computing icing
    reduced_portfolio = not compute_icing

    # Interface with Energy Offshore v0.4.9 via handledays function of said version
    eoff.handledays(
        start=[args.start_year, args.start_month, args.start_day],
        end=[args.end_year, args.end_month, args.end_day],
        chunk=args.chunk,
        HPCROOTDIR=args.hpcrootdir,
        appdir="",  # Unused argument, kept in interface for clarity
        outdir=args.app_outpath,
        inputdir=args.opa_outpath,
        compute_icing=compute_icing,
        reduced_portfolio=reduced_portfolio,
    )


if __name__ == "__main__":
    main()
