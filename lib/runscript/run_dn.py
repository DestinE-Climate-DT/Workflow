import argparse
import yaml

from gsv import GSVRetriever
from gsv.requests.parser import parse_request
from gsv.requests.utils import convert_to_step_format
import time

# DOC --> https://docs.python.org/3/library/argparse.html

# First step, create a parser:
parser = argparse.ArgumentParser(description="Runscript for data notifier job.")

# Second step, add positional arguments or
# https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
parser.add_argument('-request', required=True, help="Input file data notifier", default=1)
parser.add_argument('-chunk', required=True, help="Input chunk number for data notifier", default=2)
parser.add_argument('-split_day', required=True, help="Input split date data notifier", default=3)
parser.add_argument('-split', required=True, help="Input split number data notifier", default=4)

# Third step, parse arguments.
# The default args list is taken from sys.args
args= parser.parse_args()

# GSV data request
request_file = args.request

#get chunk number
chunk = args.chunk

# get_split number
split = args.split

# get day
split_day = args.split_day

# Now, you can get the arguments with:
print('-request_file: ', args.request)
print('-chunk: ', args.chunk)
print('-split: ', args.split)
print('-split_day', args.split_day)


# Extract GSV request from YAML file
with open(request_file, 'r') as f:
    all_requests = yaml.safe_load(f)
    data_requests = all_requests["DATA"]

# retry if not data:
# GSV Req data checker
def request_data_with_retry(gsvrequests, retry_delay=2, max_retries=5):
    retry_count = 0
    while retry_count < max_retries:
        try:
            print("GSV data listening is in process...")
            for gsvrequest in gsvrequests:
                gsv.check_messages_in_fdb(gsvrequest)
                print(f'Data with these required specifications are there!{gsvrequest}')
            retry_count = max_retries + 1
        except Exception as e:
            retry_count += 1
            print(f"Attempt {retry_count}: Not all data is yet there. Reason: {str(e)}")
            if retry_count < max_retries:
                print(f"Retrying after delay...")
                time.sleep(retry_delay)
        if retry_count == max_retries:
            raise Exception("Maximum number of retries reached. Failed to retrieve GSV data.")

# Get hour of the day from the split number in mars format. (hhmm)
def get_hour_from_split(split):
   hour = str((int(split) -1) % 24)
   if len(hour) < 2:
       hour = "0" + hour +"00"
   elif len(hour) == 2:
       hour = hour + "00"
   return hour

# Check messages in FDB using gsv>=0.4.2
gsv = GSVRetriever()
gsvrequests_i = {}
oparequests_i = {}
gsvrequests = list()
oparequests = list()
hour = get_hour_from_split(split)
start_date = "19900101"  # Hard-coded for 4 year FDB
start_time = "0000"  # Hard-coded for 4-year FDB
for idx, request_i in data_requests.items():
    gsvrequest_i = request_i['GSVREQUEST']
    oparequest_i = request_i['OPAREQUEST']
    # Replace and filling necessary fields
    oparequest_i['var'] = gsvrequest_i['param']
    gsvrequest_i['date'] = str(split_day)
    gsvrequest_i = parse_request(gsvrequest_i)
    if any(hour == element for element in gsvrequest_i['time']):
        print(f'Hour {hour} found in the request for {gsvrequest_i}.')
        gsvrequest_ii = gsvrequest_i # avoid overwriting bugs
        oparequest_ii = oparequest_i
        gsvrequest_ii['time'] = hour # keep only one timestep
        # Process steps (go from days to model steps) #TODO: this will not be used in production runs.
        gsvrequest_ii = convert_to_step_format(gsvrequest_ii, start_date, start_time)
        #gsvrequest_ii = convert_to_step_format(gsvrequest_ii, start_date, start_time)
        gsvrequests.append(gsvrequest_ii)
        oparequests.append(oparequest_ii)
    else:
        print(f'Hour {hour} NOT requested for {gsvrequest_i}')

# launch data listening.
request_data_with_retry(gsvrequests, retry_delay=5, max_retries=200) # TODO: can we parallelise this? Max tries only in development phase.

# write smaller requests that contain gsv and opa requests for every opa instance.
# this has to be optimised, as every DN is writhing this file.
for i in range(1,len(oparequests)+1):
    var = oparequests[i-1]['var']
    stat = oparequests[i-1]['stat']
    freq = oparequests[i-1]['stat_freq']
    filename = f'request_{split_day}_{hour}_{var}_{stat}_{freq}.yml'  # Generates the file name dynamically
    with open(filename, 'w') as outfile:
        yaml.dump(dict(GSVREQUEST=gsvrequests[i-1], OPAREQUEST=oparequests[i-1]), outfile, default_flow_style=False)

