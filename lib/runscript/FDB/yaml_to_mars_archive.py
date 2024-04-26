import argparse
import os

import yaml

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

data["mars-keys"]["database"] = "databridge-fdb"
data["mars-keys"]["expver"] = args.expid
data["mars-keys"]["experiment"] = args.experiment
data["mars-keys"]["model"] = args.model
data["mars-keys"]["activity"] = args.activity
data["mars-keys"]["date"] = args.startdate + "/to/" + args.enddate
data["mars-keys"]["source"] = (
    profile.split("/")[-1].split(".")[0] + "_chunk_" + args.chunk + ".grb"
)

filename = (
    profile.split("/")[-1].split(".")[0] + "_chunk_" + str(args.chunk) + str(".mars")
)

with open(filename, "w") as marsrq:
    marsrq.write("archive,\n")
    print(data["mars-keys"])
    for key in data["mars-keys"]:
        if not isinstance(data["mars-keys"][key], list):
            marsrq.write("\t" + str(key) + "=" + str(data["mars-keys"][key]) + ",\n")
        else:
            concatenated_string = ""
            for element in data["mars-keys"][key]:
                concatenated_string += str(element)
                if element != data["mars-keys"][key][-1]:
                    concatenated_string += "/"

            marsrq.write("\t" + str(key) + "=" + concatenated_string + ",\n")


with open(filename, "rb+") as filehandle:
    filehandle.seek(-2, os.SEEK_END)
    filehandle.truncate()

with open(filename, "a+") as filehandle:
    filehandle.write("\n")
