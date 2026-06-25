import argparse
from functools import partial
import time

from gsv import GSVRetriever

try:
    from runscripts.utils import add_app_experiment_arguments, AppExperiment
except ImportError:
    # Fallback: running as a script, not as an installed package
    from pathlib import Path
    import sys

    # Add the parent of 'dn' (i.e., 'runscripts') to sys.path
    sys.path.append(str(Path(__file__).parent.parent.resolve()))
    from utils import add_app_experiment_arguments, AppExperiment


def _get_parser():
    parser = argparse.ArgumentParser(description="Runscript for data notifier job.")
    parser.add_argument(
        "--request_dir", required=True, help="Input directory data notifier", default=1
    )
    # Validated in local_setup.sh
    parser.add_argument(
        "--run_type",
        required=True,
        type=str,
        help="Workflow run type. See lib/common/checkers.sh",
    )
    add_app_experiment_arguments(parser)
    return parser


DnAppExperiment = partial(AppExperiment, _request_suffix="_DN")


# retry if not data:
# GSV Req data checker
def request_data_with_retry(gsvrequests, retry_delay=1, max_retries=1):
    gsv = GSVRetriever()

    retry_count = 0
    while retry_count < max_retries:
        try:
            print("GSV data listening is in process...", flush=True)
            for gsvrequest in gsvrequests:
                gsv.check_messages_in_fdb(gsvrequest, process_derived_variables=True)
                print(
                    f"Data with these required specifications are there!{gsvrequest}",
                    flush=True,
                )
            retry_count = max_retries + 1
        except Exception as e:
            retry_count += 1
            print(
                f"Attempt {retry_count}: Not all data is yet there. Reason: {str(e)}",
                flush=True,
            )
            if retry_count < max_retries:
                print(f"Retrying after {retry_delay} seconds...", flush=True)
                time.sleep(retry_delay)
        if retry_count == max_retries:
            # TODO: Specify exception
            raise Exception(
                "Maximum number of retries reached. Failed to retrieve GSV data."
            )


def main():
    """Executes the data listening mechanism (DN)."""

    args = _get_parser().parse_args()

    request_dir = args.request_dir
    chunk = args.chunk
    split = args.split
    app_names = args.app_names
    expid = args.expid
    run_type = args.run_type
    realization = args.realization
    member = args.member
    startdate = args.startdate

    print("--request_dir: ", args.request_dir)
    print("--run_type", args.run_type)
    print("--chunk: ", args.chunk)
    print("--split: ", args.split)
    print("--expid", args.expid)
    print("--app_names", args.app_names)
    # Use either member or realization, not both
    print("--member", member)
    print("--realization", realization)
    print("--startdate", args.startdate)

    if run_type in {"production", "operational"}:
        retry_delay = 60
        max_retries = 2400
    else:  # 30 min
        retry_delay = 15
        max_retries = 120

    app_experiment = DnAppExperiment(
        chunk=chunk,
        split=split,
        expid=expid,
        member=member,
        realization=realization,
        app_names=app_names,
        startdate=startdate,
    )

    gsvrequests, _ = app_experiment.get_requests(request_dir)

    # Launch data listening.
    # TODO: make infinite loop in production phase.
    request_data_with_retry(
        gsvrequests, retry_delay=retry_delay, max_retries=max_retries
    )


if __name__ == "__main__":
    main()
