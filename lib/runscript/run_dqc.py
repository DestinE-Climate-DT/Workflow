import argparse

from gsv.dqc.dqc_wrapper import DQCWrapper

parser = argparse.ArgumentParser(description="Runscript for Data Quality Checker.")

parser.add_argument("-expver", required=True)
parser.add_argument("-date", required=True)
parser.add_argument("-profile_path", required=True)
parser.add_argument("-model", required=True)
parser.add_argument("-experiment", required=True)
parser.add_argument("-activity", required=True)
parser.add_argument("-realization", required=False)

# Not used
parser.add_argument("-time", required=False, default=None)
parser.add_argument("-start_date", required=False, default=None)
parser.add_argument("-start_time", required=False, default="0000")

args = parser.parse_args()

# Get arguments from parser
expver = args.expver
date = args.date
profile_path = args.profile_path
model = args.model
experiment = args.experiment
activity = args.activity
realization = args.realization
# time=args.time
# start_date=args.start_date
# start_time=args.start_time

dqc = DQCWrapper(
    profile_path=profile_path,
    expver=expver,
    date=date,
    model=model,
    experiment=experiment,
    realization=realization,
    activity=activity,
    logging_level="INFO",
    halt_mode="end",
)

dqc.run_dqc()
