import argparse

# load OPA and other libs
import yaml
from gsv import GSVRetriever

from one_pass.opa import Opa

# DOC --> https://docs.python.org/3/library/argparse.html

# First step, create a parser:
parser = argparse.ArgumentParser(description="Runscript for data notifier job.")

# Second step, add positional arguments or
# https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
parser.add_argument("-request", required=True, help="Input file one pass", default=1)
parser.add_argument(
    "-read_from_databridge", required=True, help="Read from databridge", default=False
)

# Thirs step, parse arguments.
# The default args list is taken from sys.args
args = parser.parse_args()

# Now, you can get the arguments with:
print("-request: ", args.request)

# gsv data request
request_file = args.request
read_from_databridge = args.read_from_databridge

gsv = GSVRetriever()

with open(request_file) as f:
    request = yaml.safe_load(f)
    oparequest = request["OPAREQUEST"]
    gsvrequest = request["GSVREQUEST"]

# get data from gsv
data = gsv.request_data(gsvrequest, use_stream_iterator=read_from_databridge)

# run Opa
some_stats = Opa(oparequest)
some_stats.compute(data)
