Restarted runs
--------------

It's common to want to restart a model run from a previous experiment. This is possible in the workflow, but requires some configuration.

To restart a run from a previous experiment, you need to set the following parameters in your `main.yml` configuration file:

- `RUN.RESTARTED_RUN`: This should be set to `true` to indicate that you want to restart a run.

- `RUN.RESTART_FROM`: This should be set to the experiment ID (EXP_ID) of the run you want to restart from. This tells the workflow where to look for the restart files.

- `CONFIGURATION.IFS.START_DATE`: This should be set to the start date of the run you want to restart from, in the format `YYYYMMDD`. This is used to pass the correct information to IFS.

- (optional) `MODEL.RESTART_FROM_PATH`: This can be set to the specific path where the restart files are located. If not set, the workflow will assume a default path based on the `RUN.RESTART_FROM` and your user and project directories.

When you set these parameters, the workflow will copy the necessary restart files from the specified experiment to a new directory for the current run. The model will then use these files to restart from the specified point.
