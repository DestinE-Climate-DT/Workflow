import argparse
import sys
from energy_offshore import energy_offshore as eoff

print("Energy offshore runscript starting")

parser = argparse.ArgumentParser(description="Runscript for energy offshore job.")

# Add positional arguments or
# https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
parser.add_argument("--expid", required=False, help="Experiment ID", default=None)
parser.add_argument("--app", required=False, help="Name of application run", default="")
parser.add_argument("--datelist", required=False, help="List of dates ?", default=None)
parser.add_argument(
    "--requestfile", required=True, help="Request file in question", default=1
)
parser.add_argument(
    "--hpcrootdir", required=True, help="Root directory on HPC side", default=None
)
parser.add_argument(
    "--projdest",
    required=True,
    help="Destination directory for unpacking project files",
    default=None,
)
parser.add_argument(
    "--app_outpath",
    required=True,
    help="In and out directory. Data from streaming is there",
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

args = parser.parse_args()
# APP_OUTDIR=args.app_outpath
APPDIR = args.hpcrootdir + "/git_project/energy_offshore"

sys.path.append(APPDIR)

print("Calling handledays()")

eoff.handledays(
    HPCROOTDIR=args.hpcrootdir,
    outdir=args.app_outpath,
    start=[args.start_year, args.start_month, args.start_day],
    end=[args.end_year, args.end_month, args.end_day],
    chunk=args.chunk,
)
