import argparse
import yaml

from gsv import GSVRetriever
from gsv.requests.parser import parse_request
from gsv.requests.utils import count_combinations


def parse_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", help="Path to the YAML file")
    parser.add_argument("--expver", help="Expid of the FDB")
    parser.add_argument("--experiment", help="MultIO experiment name")
    parser.add_argument("--activity", help="MultIO activity name")
    parser.add_argument("--model", help="Model name")
    parser.add_argument("--startdate", help="Start date of the request")
    parser.add_argument("--enddate", help="End date of the request")
    parser.add_argument("--chunk", help="Chunk number")
    return parser.parse_args()


def main():
    # Get arguments
    args = parse_arguments()

    # Open data profile
    file_path = args.file
    with open(file_path, "r") as file:
        data = yaml.safe_load(file)

    # Update dynamic MARS keys
    data["mars-keys"]["expver"] = args.expver
    data["mars-keys"]["date"] = args.startdate + "/to/" + args.enddate
    data["mars-keys"]["experiment"] = args.experiment
    data["mars-keys"]["activity"] = args.activity
    data["mars-keys"]["model"] = args.model

    # Render implicit requests
    request = parse_request(data["mars-keys"])

    # Get number of combinations
    n_expected_messages = count_combinations(request, GSVRetriever.MARS_KEYS)

    # Print result to capture output
    print(n_expected_messages)


if __name__ == "__main__":
    main()
