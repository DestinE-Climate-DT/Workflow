import argparse
import concurrent.futures
from contextlib import redirect_stderr
import sys

from gsv.dqc.dqc_wrapper import DQCWrapper
from gsv.dqc.report.dqc_report import main as dqc_report


def bool_from_str(string):
    if string.lower() == "true":
        return True
    elif string.lower() == "false":
        return False
    else:
        raise ValueError


parser = argparse.ArgumentParser(description="Runscript for Data Quality Checker.")

parser.add_argument("--expver", required=True)
parser.add_argument("--date", required=False, default=None)
parser.add_argument("--profile_path", required=True)
parser.add_argument("--model", required=True)
parser.add_argument("--experiment", required=True)
parser.add_argument("--activity", required=True)
parser.add_argument("--realization", required=False)
parser.add_argument("--generation", required=False)
parser.add_argument("--n_proc", required=False, default=1, type=int)

parser.add_argument(
    "--check_standard_compliance", required=True, default=True, type=bool_from_str
)
parser.add_argument(
    "--check_spatial_completeness", required=True, default=True, type=bool_from_str
)
parser.add_argument(
    "--check_spatial_consistency", required=True, default=True, type=bool_from_str
)
parser.add_argument(
    "--check_physical_plausibility", required=True, default=True, type=bool_from_str
)
parser.add_argument("--dqc_output_file", required=True, type=str)

args = parser.parse_args()

# Get arguments from parser
expver = args.expver
date = args.date
profile_path = args.profile_path
model = args.model
experiment = args.experiment
activity = args.activity
realization = args.realization
generation = args.generation
n_proc = args.n_proc
dqc_output_file = args.dqc_output_file

check_standard_compliance = bool(args.check_standard_compliance)
check_spatial_completeness = bool(args.check_spatial_completeness)
check_spatial_consistency = bool(args.check_spatial_consistency)
check_physical_plausibility = bool(args.check_physical_plausibility)


def run_dqc(proc_id):
    dqc = DQCWrapper(
        profile_path=profile_path,
        expver=expver,
        date=date,
        model=model,
        experiment=experiment,
        realization=realization,
        activity=activity,
        generation=generation,
        logging_level="INFO",
        halt_mode="end",
        check_standard_compliance=check_standard_compliance,
        check_spatial_completeness=check_spatial_completeness,
        check_spatial_consistency=check_spatial_consistency,
        check_physical_plausibility=check_physical_plausibility,
        n_proc=n_proc,
        proc_id=proc_id,
    )

    dqc.run_dqc()


if __name__ == "__main__":
    with open(dqc_output_file, "w") as f:
        with redirect_stderr(f):
            with concurrent.futures.ProcessPoolExecutor() as executor:
                futures = executor.map(run_dqc, range(n_proc))

    # Run DQC report and output to log file
    print(f"Full DQC output can be found in: {dqc_output_file}.\n")
    print("####### DQC REPORT #######\n")
    sys.argv = ["", dqc_output_file, "-a"]
    dqc_report()

    # Iterate through futures to force raising any caught exceptions
    list(futures)
