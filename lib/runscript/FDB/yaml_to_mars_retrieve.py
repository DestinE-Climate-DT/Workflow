import argparse
from shutil import copyfileobj

import pyfdb
import yaml
from gsv.requests.parser import parse_request

parser = argparse.ArgumentParser()
parser.add_argument("--file", help="Path to the YAML file")
parser.add_argument("--expid", help="Expid of the FDB")
parser.add_argument("--experiment", help="Experiment type")
parser.add_argument("--startdate", help="Start date of the request")
parser.add_argument("--enddate", help="End date of the request")
parser.add_argument("--chunk", help="Chunk number")
parser.add_argument("--model", help="Model")
parser.add_argument("--activity", help="Activity")

args = parser.parse_args()

profile = args.file

with open(profile, "r") as file:
    data = yaml.safe_load(file)

fdb = pyfdb.FDB()

print("ORIGINAL PROFILE: ")
print(data)
data["mars-keys"]["expver"] = args.expid
data["mars-keys"]["experiment"] = args.experiment
data["mars-keys"]["model"] = args.model
data["mars-keys"]["activity"] = args.activity
data["mars-keys"]["date"] = args.startdate + "/to/" + args.enddate

request = data["mars-keys"]

request = parse_request(request)

print("PROCESSED PROFILE: ")
print(request)

datareader = fdb.retrieve(request)

filename = profile.split("/")[-1].split(".")[0] + "_chunk_" + args.chunk + ".grb"

with open(filename, "wb") as f:
    copyfileobj(datareader, f)
