=============================
Available keys in request.yml
=============================


Important note: this applies only to WORKFLOW.TYPE: apps
--------------------------------------------------------

The ``request.yml`` allows the user to select simulation data. Normally, it is hidden from the user and created automatically during the execution of the githook. Still, it is important to know what the fields are in case the user wants to read from other simulations after the experiment has been created.

FDB structure
+++++++++++++

Example of an FDB entry:

`{class}:{dataset}:{activity}:{experiment}:1:{model}:1:{expver}:{stream}:{date}`

Keys for the different fields
+++++++++++++++++++++++++++++

**resolution**
  - **what is**: simulation resolution.
  - **options**: "high"/"standard".

**generation**
  - **what is**: model generation (internal to DestinE).
  - **option**: "1".

**realization**
  - **what is**: member number of the ensemble.
  - **option**: integer, starting from "1".

**experiment**
  - **what is**: type of experiment: historical, projection with different forcings, etc.
  - **options**: "cont"/"hist"/"SSPX-Y.Z" (see description `<https://github.com/ecmwf/eccodes/blob/9179608c8877ff78e2b3db1cb3357721bcfdd5d3/definitions/grib2/destine_experiment.table>`_).

**activity**
  - **what is**: related to *experiment* (cont: baseline) (hist: baseline) (SSPX-Y.Z: projections) (story-nudging: TBA).
  - **options**: "baseline", "projections". (see description `<https://github.com/ecmwf/eccodes/blob/9179608c8877ff78e2b3db1cb3357721bcfdd5d3/definitions/grib2/destine_activity.table>`_).

**model**
  - **what is**: used model.
  - **options**: "icon"/"ifs-nemo"/"ifs-fesom".

**expver**
  - **what is**: experiment ID for each experiment.
  - **options**: 0001 for production, Autosubmit experiment ID for the rest.

**FDB_HOME**
  - **what is** path where the fsb configuration is.
  - **options** `/gpfs/scratch/ehpc01/experiments/a1ym/fdb` (mn5), `/scratch/project_465000454/experiments/a1ym/fdb`(lumi)
  - important note: This is only valid to read from workflow RUN.TYPE: `test` and RUN.WORKFLOW: `apps`. 
