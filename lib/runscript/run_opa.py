import argparse
#DOC --> https://docs.python.org/3/library/argparse.html

#First step, create a parser:
parser = argparse.ArgumentParser(description="Runscript for data notifier job.")

#Second step, add positional arguments or
#https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
parser.add_argument('-request', required=True, help="Input file one pass", default=1)

#Thirs step, parse arguments. 
#The default args list is taken from sys.args
args= parser.parse_args()

#Now, you can get the arguments with:
print('-request: ', args.request)

#gsv data request
request_file = args.request

# load OPA and other libs
import yaml

from gsv import GSVRetriever
from one_pass.opa import *
from one_pass.opa import Opa

gsv = GSVRetriever()

with open(request_file) as f:
    request = yaml.safe_load(f)
    oparequest = request["OPAREQUEST"]
    gsvrequest = request["GSVREQUEST"]

step = gsvrequest['step']

# create list to be retreived
ini_step = gsvrequest['step'][0]
end_step = int(ini_step) + 23

time_step_in_h = int(int(oparequest['time_step'])/60)

gsvrequest['step'] = f'{ini_step}/to/{int(end_step)}/by/{time_step_in_h}'

#get data from gsv
data = gsv.request_data(gsvrequest)

#run Opa
some_stats=Opa(oparequest)
some_stats.compute(data)

