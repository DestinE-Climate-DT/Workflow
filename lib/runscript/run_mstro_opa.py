#
#  MSTRO_OPA job script
#
#  Similar to a merger of DN + OPA jobs in the operational workflow.
#
#  Listens for data events from Maestro, the data itself typically residing in
#  the models or the Librarians memory, and immediately transfers the data --
#  alleviating the model -- to a local stream buffer, to be passed along to GSV
#  Interface and OPA.
#

import argparse
import yaml
import time
import os
from gsv import GSVRetriever
from gsv.requests.utils import convert_to_step_format
from one_pass.opa import Opa
from datetime import datetime, timedelta
import maestro_core as M


# DOC --> https://docs.python.org/3/library/argparse.html

# First step, create a parser:
parser = argparse.ArgumentParser(description="Runscript for data notifier job.")

# Second step, add positional arguments or
# https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
parser.add_argument(
    "-request", required=True, help="Input file data notifier", default=1
)
parser.add_argument("-chunk", required=True, help="Chunk number", default=2)
parser.add_argument(
    "-start_date", required=True, help="Start date of the chunk", default=3
)
parser.add_argument("-end_date", required=True, help="End date of the chunk", default=0)
parser.add_argument("-split", required=True, help="Split ID", default=0)
parser.add_argument("-hpcrootdir", required=True, help="HPC root directory", default=0)
parser.add_argument("-expid", required=True, help="Experiment ID", default=0)
parser.add_argument(
    "-static", required=True, help="Indicates static 4y FDB or not", default=False
)
parser.add_argument(
    "-librarianfile", required=True, help="File to write the MARS request in", default=0
)

# Third step, parse arguments.
# The default args list is taken from sys.args
args = parser.parse_args()

request_file = args.request
chunk = args.chunk
start_date = args.start_date
end_date = args.end_date
split = args.split
hpcrootdir = args.hpcrootdir
expid = args.expid
static = args.static
librarianfile = args.librarianfile

print("mstro_opa -request: ", request_file)
print("mstro_opa -chunk: ", chunk)
print("mstro_opa -start_date: ", start_date)
print("mstro_opa -end_date: ", end_date)
print("mstro_opa -split: ", split)
print("mstro_opa -hpcrootdir: ", hpcrootdir)
print("mstro_opa -expid: ", expid)
print("mstro_opa -static: ", static)
print("mstro_opa -librarianfile: ", librarianfile)

if int(split) == -1:
    split = "1"

# Extract DB of params
param_db_file = os.getenv("PARAMDB")
print("PARAMDB path: ", param_db_file)
with open(param_db_file, "r") as f:
    vardb = yaml.safe_load(f)

# Extract GSV request from YAML file
with open(request_file, "r") as f:
    master_request = yaml.safe_load(f)
    oparequest = master_request["OPAREQUEST"][int(split)]
    gsvrequest = master_request["GSVREQUEST"]

# Setting the right `param` for this instance to listen to
found = False
split_param = gsvrequest["param"][int(split) - 1]
print("Looking in DB for `", split_param, "`")
for k in vardb.keys():
    print(vardb[k])
    if vardb[k]["short_name"] == split_param:
        print(k)
        gsvrequest["param"] = k
        found = True
        break
if not found:
    raise Exception("Key (param from gsvrequest) not found in DB")

# We have three use-cases here: static+Librarian, non-static+Librarian, (non-static+)model
# There is nothing much to do in case of a model producer, `step` is not used
# anymore. We need to prepare `steps` for the Librarian MARS request, which
# depends on static or not static FDB, knowing that GSV Interface will need
# some translation to python
gsvrequest["date"] = str(start_date) + "/to/" + str(end_date)
if librarianfile != "":
    steps_py = gsvrequest["step"]
    if static:
        # Let's accomodate the static FDB (fixed base date/time + old data governance?)
        fixed_date = "20200120"
        fixed_time = "0000"
        tmp_date = start_date
        tmp_steps = []
        while int(tmp_date) < int(end_date):
            print("tmp_date = ", tmp_date)
            gsvrequest["date"] = tmp_date
            tmp_request = convert_to_step_format(gsvrequest, fixed_date, fixed_time)
            # get the next date in the suitable format
            tmp_date = (
                datetime.strptime(f"{tmp_date}", "%Y%m%d") + timedelta(days=1)
            ).strftime("%Y%m%d")
            tmp_steps.extend(tmp_request["step"])
        # Reestablish the right date range format
        gsvrequest["date"] = fixed_date  # str(start_date) + "/to/" + str(end_date)
        steps_py = tmp_steps
        print("steps_py:", steps_py)

    # Write proper MARS-style list of steps (if applicable) for the Librarian
    # Librarian is waiting for it
    steps = "/".join(steps_py)
    gsvrequest["step"] = steps
    print("librarian request file name: ", librarianfile)
    with open(librarianfile, "w") as outfile:
        yaml.dump(
            dict(
                GSVREQUEST=gsvrequest,
            ),
            outfile,
            default_flow_style=False,
        )
# Need to reestablish python-style array notation (if applicable), as
# GSVInterface does not handle MARS-style lists
if librarianfile != "" and static:
    gsvrequest["step"] = steps_py


# Starting up Maestro client
workflow_name = os.getenv("MSTRO_WORKFLOW_NAME")
component_name = os.getenv("MSTRO_COMPONENT_NAME")
print("Trying to mstro_init with (" + workflow_name + "," + component_name + ")")
prefix = "[MSTRO_OPA][" + split + "] "
print(prefix + "started")
M.mstro_init(None, None, 0)
print(prefix + " mstro init done")
pm_info = os.getenv("MSTRO_POOL_MANAGER_INFO")
print("[consumer] PM_INFO: ", pm_info)

# Event subscriptions
# app_sub = M.mstro_subscribe(None, M.MSTRO_POOL_EVENT_APP_LEAVE, False)
print("[consumer] subscribed to app events")
param_cdo_predicate = "(.maestro.gsv.param = " + str(gsvrequest["param"]) + ")"
if "levelist" in gsvrequest:
    levelist_cdo_predicate = (
        "(.maestro.gsv.levelist = " + str(gsvrequest["levelist"]) + ")"
    )
    cdo_predicate = "(and " + param_cdo_predicate + levelist_cdo_predicate + ")"
else:
    cdo_predicate = param_cdo_predicate
print(prefix + "predicate: " + cdo_predicate)
cdo_sel = M.mstro_cdo_selector_create(None, None, cdo_predicate)
print(prefix + "selector created")
cdo_sub = M.mstro_subscribe(
    cdo_sel,
    M.MSTRO_POOL_EVENT_OFFER,
    M.MSTRO_SUBSCRIPTION_OPTS_REQUIRE_ACK | M.MSTRO_SUBSCRIPTION_OPTS_NO_LOCAL_EVENTS,
)

# Get the string param version back for GSV/OPA
gsvrequest["param"] = split_param

# Workflow sync
os.close(os.open(f"{hpcrootdir}/LOG_{expid}/opa_{chunk}_{split}_mstrodep", os.O_CREAT))

# Poll events loop
cdo_table = {}
done = False
times = []
sizes = []
starttime = M.mstro_clock()
while not done:
    # Poll app join/leave
    # FIXME pack component_name string into protobuf
    # e = M.mstro_subscription_poll(app_sub)
    # if e:
    #    for sub_e in e:
    #        if sub_e.kind == M.MSTRO_POOL_EVENT_APP_LEAVE :
    #            print(prefix+"app "+ str(sub_e.payload.leave.appid)+ " (" +str(sub_e.payload.leave.component_name) + ") left.")
    #            if (str(sub_e.payload.leave.component_name) == f"Librarian_{split}" or str(sub_e.payload.leave.component_name) == "IFS-Nemo"):
    #                done = True
    #    continue
    if os.path.isfile(
        f"{hpcrootdir}/LOG_{expid}/producer_{chunk}_{split}_mstrodep"
    ) or os.path.isfile(f"{hpcrootdir}/LOG_{expid}/producer_{chunk}_mstrodep"):
        done = True

    # Poll cdo subscription
    e = M.mstro_subscription_poll(cdo_sub)
    if e:
        for sub_e in e:
            event_name = M.mstro_pool_event_description(sub_e.kind)
            if sub_e.kind == M.MSTRO_POOL_EVENT_OFFER:
                cdo_name = sub_e.payload.offer.cdo_name
                print(prefix + "CDO event for: `" + cdo_name + "`")
                # check if we have already seen the cdo
                if cdo_name not in cdo_table.keys():
                    cdo_e = {}
                    cdo_e = M.mstro_cdo_declare(cdo_name, None)
                    cdo_table[cdo_name] = cdo_e
                    # Reserving the CDO
                    M.mstro_cdo_require(cdo_e)
                    # [buffering use-case] demand the CDO
                    start = time.time()
                    M.mstro_cdo_demand(cdo_e)
                    end = time.time()
                    times.append(end - start)
                    sizes.append(
                        M.mstro_cdo_attribute_get(
                            cdo_e, M.MSTRO_ATTR_CORE_CDO_SCOPE_LOCAL_SIZE, None
                        )
                    )
                    M.mstro_cdo_attributes_print(cdo_e)

        # Acknowledge all
        M.mstro_subscription_ack(cdo_sub, e)
        continue

assert cdo_table != {}
avg_t = sum(times) / len(times)
avg_s = sum(sizes) / len(sizes)
print(times)
print(prefix + "average demand time is " + str(avg_t))
print(prefix + "average size is" + str(avg_s))
print(prefix + "bandwidth is " + str(avg_s / avg_t / 1000 / 1000 / 1000))

# Run GSV Interface and OPA
gsv = GSVRetriever()
data_maestro = gsv.request_data(
    request=gsvrequest, engine="maestro", cdos=cdo_table.values()
)
print(prefix + "GSV data_handle received (daily)")

oparequest["checkpoint_filepath"] = f"{hpcrootdir}/LOG_{expid}/"
oparequest["save_filepath"] = f"{hpcrootdir}/LOG_{expid}/"
some_stats = Opa(oparequest)
some_stats.compute(data_maestro)
print(prefix + "OPA stats computed (daily)")

# Clean up
for cdo_e in cdo_table.values():
    M.mstro_cdo_dispose(cdo_e)
print(prefix + "cleanup done")

M.mstro_finalize()
print(prefix + "done")
