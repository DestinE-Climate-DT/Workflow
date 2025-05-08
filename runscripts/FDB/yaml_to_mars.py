import argparse
import os

import yaml

parser = argparse.ArgumentParser()
parser.add_argument("--file", help="Path to the YAML file")
parser.add_argument("--expid", help="Expid of the FDB")
parser.add_argument("--startdate", help="Start date of the request")
parser.add_argument("--enddate", help="End date of the request")
args = parser.parse_args()

file_path = args.file

with open(file_path, "r") as file:
    data = yaml.safe_load(file)

data["mars-keys"]["expver"] = args.expid
data["mars-keys"]["date"] = args.startdate + "/to/" + args.enddate

filename = file_path.split("/")[-1].split(".")[0] + str(".mars")

with open(filename, "w") as marsrq:
    marsrq.write("retrieve,\n")
    print(data["mars-keys"])
    for key in data["mars-keys"]:
        if isinstance(data["mars-keys"][key], list):
            concatenated_string = ""
            for element in data["mars-keys"][key]:
                concatenated_string += str(element)
                if element != data["mars-keys"][key][-1]:
                    concatenated_string += "/"
            marsrq.write("\t" + str(key) + "=" + concatenated_string + ",\n")
        else:
            marsrq.write("\t" + str(key) + "=" + str(data["mars-keys"][key]) + ",\n")


with open(filename, "rb+") as filehandle:
    filehandle.seek(-3, os.SEEK_END)
    filehandle.truncate()
