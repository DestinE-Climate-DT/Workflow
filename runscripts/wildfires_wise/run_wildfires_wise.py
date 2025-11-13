"""Runscript for Wildfires WISE application."""

import argparse
from wise.run_wise import run_wise


def _get_parser():
    parser = argparse.ArgumentParser(description="Runscript for data notifier job.")

    parser.add_argument("--in_path", required=True, help="Input path")
    parser.add_argument("--out_path", required=True, help="Output path")
    parser.add_argument(
        "--year_start", required=True, help="Starting year, format 'YYYY'"
    )
    parser.add_argument(
        "--month_start", required=True, help="Starting month, format 'MM'"
    )
    parser.add_argument("--day_start", required=True, help="Starting day, format 'DD'")
    parser.add_argument("--year_end", required=True, help="Ending year, format 'YYYY'")
    parser.add_argument("--month_end", required=True, help="Ending month, format 'MM'")
    parser.add_argument("--day_end", required=True, help="Ending day, format 'DD'")

    return parser


def main():
    # defining file input / output paths
    args = _get_parser().parse_args()

    run_wise(
        args.in_path,
        args.out_path,
        args.year_start,
        args.month_start,
        args.day_start,
        args.year_end,
        args.month_end,
        args.day_end,
    )


if __name__ == "__main__":
    main()
