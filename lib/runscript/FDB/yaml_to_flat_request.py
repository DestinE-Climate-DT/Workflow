import yaml
import argparse
import os

from gsv.requests.parser import parse_request


parser = argparse.ArgumentParser()
parser.add_argument("--file", help="Path to the YAML file")
parser.add_argument("--expver", help="Expid of the FDB")
parser.add_argument("--experiment", help="MultIO experiment name")
parser.add_argument("--activity", help="MultIO activity name")
parser.add_argument("--model", help="Model name")
parser.add_argument("--startdate", help="Start date of the request")
parser.add_argument("--enddate", help="End date of the request")
parser.add_argument("--chunk", help="Chunk number")
parser.add_argument(
    "--omit-keys", required=False, help="Keys to be omitted in the resulting request"
)
args = parser.parse_args()

file_path = args.file

with open(file_path, "r") as file:
    data = yaml.safe_load(file)

data["mars-keys"]["expver"] = args.expver
data["mars-keys"]["date"] = args.startdate + "/to/" + args.enddate
data["mars-keys"]["experiment"] = args.experiment
data["mars-keys"]["activity"] = args.activity
data["mars-keys"]["model"] = args.model

request = parse_request(data["mars-keys"])

# Remove keys if necessary
if args.omit_keys is not None:
    keys_to_omit = args.omit_keys.split(",")
    for key in keys_to_omit:
        if key in data["mars-keys"]:
            del data["mars-keys"][key]

filename = file_path.split("/")[-1].split(".")[0] + f"_{args.chunk}_request.flat"

with open(filename, "w") as marsrq:
    print(request)
    for key in request:
        if not isinstance(request[key], list):
            marsrq.write(str(key) + "=" + str(request[key]) + ",")
        else:
            concatenated_string = ""
            for element in request[key]:
                concatenated_string += str(element)
                if element != request[key][-1]:
                    concatenated_string += "/"

            marsrq.write(str(key) + "=" + concatenated_string + ",")


with open(filename, "rb+") as filehandle:
    filehandle.seek(-1, os.SEEK_END)
    filehandle.truncate()
