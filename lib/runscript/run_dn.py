import argparse
import time

import yaml
from gsv import GSVRetriever
from gsv.requests.parser import parse_request

# First step, create a parser:
parser = argparse.ArgumentParser(description="Runscript for data notifier job.")

# Second step, add positional arguments or
# https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
parser.add_argument(
    "-request", required=True, help="Input file data notifier", default=1
)
parser.add_argument(
    "-chunk", required=True, help="Input chunk number for data notifier", default=2
)
parser.add_argument(
    "-split_day", required=True, help="Input split date data notifier", default=3
)
parser.add_argument(
    "-split", required=True, help="Input split number data notifier", default=4
)
parser.add_argument("-expid", required=True, help="Experiment id", default=5)
parser.add_argument("-app_names", help="app(s) to be run", default=6)
parser.add_argument("-model", help="Model", default=None)
parser.add_argument("-activity", help="Activity", default=None)
parser.add_argument("-experiment", help="Experiment type", default=None)

# Third step, parse arguments.
# The default args list is taken from sys.args
args = parser.parse_args()

# GSV data request
request_file = args.request

# get chunk number
chunk = args.chunk

# get_split number
split = args.split

# get day
split_day = args.split_day

# get day
app_names = args.app_names

# get expid
expid = args.expid

# get experiment
experiment = args.experiment

# get activity
activity = args.activity

# get model
model = args.model


# Now, you can get the arguments with:
print("-request_file: ", args.request)
print("-chunk: ", args.chunk)
print("-split: ", args.split)
print("-split_day", args.split_day)
print("-expid", args.expid)
print("-model", args.model)
print("-activity", args.activity)
print("-experiment", args.experiment)


# Extract GSV request from YAML file
with open(request_file, "r") as f:
    all_requests = yaml.safe_load(f)

# Initialise gsv
gsv = GSVRetriever()


# retry if not data:
# GSV Req data checker
def request_data_with_retry(gsvrequests, retry_delay=1, max_retries=1):
    retry_count = 0
    while retry_count < max_retries:
        try:
            print("GSV data listening is in process...", flush=True)
            for gsvrequest in gsvrequests:
                gsv.check_messages_in_fdb(gsvrequest)
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
            raise Exception(
                "Maximum number of retries reached. Failed to retrieve GSV data."
            )


def main():
    """
    Executes the data listening mechanism (DN).

    """

    # Check messages in FDB using gsv>=0.4.2
    gsvrequests = list()
    oparequests = list()

    for app in all_requests.items():
        for idx, request_i in app[1].items():
            # check only apps that are requested
            pattern_to_find = app[0]
            if pattern_to_find in app_names:
                print(f"Application being checked: {app[0]}")
                print(f'Variables requested: {request_i["GSVREQUEST"]["param"]}')

                gsvrequest_i = request_i["GSVREQUEST"]
                oparequest_i = request_i["OPAREQUEST"]
                # Replace and filling necessary fields
                oparequest_i["var"] = gsvrequest_i["param"]
                gsvrequest_i["date"] = str(split_day)
                gsvrequest_i["expver"] = expid

                gsvrequest_i["experiment"] = (
                    experiment if experiment is not None else gsvrequest_i["experiment"]
                )
                gsvrequest_i["activity"] = (
                    activity if activity is not None else gsvrequest_i["activity"]
                )
                gsvrequest_i["model"] = (
                    model if model is not None else gsvrequest_i["model"]
                )

                gsvrequest_i = parse_request(gsvrequest_i)

                oparequests.append(oparequest_i)
                gsvrequests.append(gsvrequest_i)
            else:
                print(f"Skipped application (not requested): {app[0]}")

    # launch data listening.
    request_data_with_retry(
        gsvrequests, retry_delay=10, max_retries=2400
    )  # TODO: make infinite loop in production phase.

    # write requests that contain gsv and opa requests for every opa instance.
    for app in all_requests.items():
        for idx, request_i in app[1].items():
            filename = f"request_{split_day}_{chunk}_{split}_OPA_{app[0]}_{idx}.yml"
            with open(filename, "w") as outfile:
                yaml.dump(
                    dict(
                        GSVREQUEST=request_i["GSVREQUEST"],
                        OPAREQUEST=request_i["OPAREQUEST"],
                    ),
                    outfile,
                    default_flow_style=False,
                )


if __name__ == "__main__":
    main()
