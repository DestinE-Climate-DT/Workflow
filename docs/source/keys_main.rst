==========================
Available keys in main.yml
==========================

RUN:
++++

Minimum set of parameters that define an experiment.

WORKFLOW:
----------

- **Intention:** select the workflow type.
- **Options:** `end-to-end`, `model`, `apps`
- **Usage:** selects the job list. This key is used in `conf/bootstrap/include.yml <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/blob/main/conf/bootstrap/include.yml>`_ to load the joblist file. It will load `jobs_apps.yml <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/blob/main/conf/jobs_apps.yml>`_, `jobs_model.yml <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/blob/main/conf/jobs_model.yml>`_ or `jobs_end-to-end.yml <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/blob/main/conf/jobs_end-to-end.yml>`_

ENVIRONMENT:
-------------

- **Intention:** to select the environment being used. Generally `cray` for `LUMI` and `intel`, `openmp`... for Marenostrum.
- **Options:** In LUMI, `cray`. 
- **What it sets:** It sets the environment to use with the pre-compiled binaries. Check the models' pre-compiled directory to see which environments are supported. 
- **Usage:** as a switch and as a variable in the workflow.

PROCESSOR_UNIT:
---------------

- **Intention:** To select the processor unit being used. 
- **Options:** `cpu` for `ifs-nemo` & `icon` (r2b4 only), `gpu` for `ifs-nemo` and `gpu_gpu` for `icon` (hetjobs for r2b8 and r2b9).
- **What it sets:** It sets the processor_unit variable, which is used to load specific environment settings, runscripts or general configuration for running on the different options.
- **Usage:** as a switch and as a variable in the workflow.

PRODUCTION:
-----------

- **Intention:** To mark the experiment as a production experiment. 
- **Options:** `true` or `false` (only applies when it's `true`).
- **What it sets:** The experiment writes the data using 0001 expver instead of the expid provided by Autosubmit. It writes in the HPC-FDB instead of in a local FDB. 

MODEL:
++++++

Only if WORKFLOW: `end-to-end` or `model`.

NAME:
-----

- **Intention:** to select which model runs. 
- **Options:** `icon`, `ifs-nemo`, `ifs-fesom`.
- **What it sets:** Select which SIM template will run. Select `the directory <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/blob/main/conf/model/>`_ to load the grid-specific parameters.
- **Usage:** as a switch and as a variable in the workflow. 

GRID_ATM:
---------

- **Intention:** to select the resolution (grid) of the atmosphere.
- **Options:** depend on the model. For ICON: `r2b4` (test), `r2b8` (development) & `r2b9` (production). For IFS-NEMO: `tco79l137` (test), `tco1279l137` (development), `tco2559l137` (production).
- **What it sets:** Selects which file of the `model directory <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/tree/main/conf/model/ifs-nemo>`_ will be loaded. In IFS-based models, it sets keys related to the inputs: `GTYPE` (tco), `EXPVER` (experiment ID of the inputs), `RESOL` (resolution), `LEVELS` (pressure levels) and `LABEL`. 
- **Usage:** as a switch and as a variable in the workflow. 

GRID_OCE:
---------

- **Intention:** to select the resolution (grid) of the ocean.
- **Options:** depends on the model. For ICON: `r2b4` (test), `r2b8` (development) & `r2b9` (production). For IFS-NEMO: `eORCA1_Z75`, `eORCA12_Z75`
- **Usage:** as a variable in the workflow. 

VERSION:
--------------

- **Intention:** to select model pre-compiled binaries to run.
- **Options:** depends on the model. All model versions are stored in `/projappl/project_465000454/models/{icon,ifs-nemo,ifs-fesom}`.
- **What it sets:** It sets the pre-compiled binaries of the model version to run, and the default inputs used.
- **Usage:** as a switch and as a variable in the workflow.


SIMULATION:
-----------

- **Intention:** to set the keys that characterize a type of simulation. 
- **Options:** All the files of `the simulation directory <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/tree/main/conf/simulation>`_.
- **What it sets:** `EXPERIMENT` keys (date, chunk length), default `PARTITION` and `MAX_WALLCLOCK` for each platform, default `WALLCLOCK` of the `SIM` step, default number of retrials in the `SIM` step. 
- **IFS-NEMO:** type of `RAPS_EXPERIMET`, and only in some `MODEL_VERSIONS` the selection of the MultIO plans.
- **Usage:** switch. Not used as a variable in the workflow.

APP:
+++++

NAMES:
------

- **Intention:** to select the applications that will run in a simulation. 
- **Options:** 
- **What it sets:** 
- **Usage:** 

OUTPATH:
--------

- **Intention:** to specify the output path for the application results.
- **Options:** 
- **What it sets:** 
- **Usage:** 

READ_EXPID:
-----------

- **Intention:** to specify the experiment ID to read input data from.
- **Options:** a0h3, a0fe ... (https://wiki.eduuni.fi/pages/viewpage.action?spaceKey=cscRDIcollaboration&title=Experiment+overview)
- **What it sets:** the FDB5_CONFIG_FILE will point to that experiment.

CONFIGURATION:
++++++++++++++

INPUTS:
-------

- **Intention:** to specify the input files for the simulation.
- **Options:** branches of https://earth.bsc.es/gitlab/kkeller/dvc-cache-de340
- **What it sets:** 
- **Note:** if this option is used, the submodule dvc-cache-de340 needs to be cloned (specified in minimal.yml)


ADDITIONAL_JOBS:
----------------

DQC
~~~~
- **Intention:** activates the data quality checker jobs.
- **Options:** "true" or "false".

TRANSFER
~~~~~~~~
- **Intention:** activates the transfer jobs.
- **Options:** "true" or "false".
- **Note:** only suitable for RESEARCH and PRODUCTION experiments.

WIPE
~~~~
- **Intention:** activates the wipe jobs.
- **Options:** "true" or "false".
- **Note:** only suitable for RESEARCH and PRODUCTION experiments.

CLEAN
~~~~~
- **Intention:** activates the clean jobs.
- **Options:** "true" or "false".


EXPERIMENT:
+++++++++++
See https://autosubmit.readthedocs.io/en/master/userguide/configure/develop_a_project.html#expdef-configuration

DATELIST:
---------

- **Intention:** to specify the list of dates for the simulation.
- **Options:** depends on the inputs.
- **What it sets:** 
- **Usage:** 

MEMBERS:
--------

- **Intention:** to specify the members for ensemble simulations. (WIP)
- **Options:** 
- **What it sets:** 
- **Usage:** 

CHUNKSIZEUNIT:
--------------

- **Intention:** to specify the unit of chunk size.
- **Options:** hour, day, month, year
- **What it sets:** 
- **Usage:** 

CHUNKSIZE: 
-----------

- **Intention:** to specify the chunk size.
- **Options:** numerical (1, 2, 3...)
- **What it sets:** 
- **Usage:** 

NUMCHUNKS: 
----------

- **Intention:** to specify the number of chunks.
- **Options:** numerical (1, 2, 3...)
- **What it sets:** 
- **Usage:** 

CALENDAR: 
----------

- **Intention:** to specify the calendar for the simulation.
- **Options:** standard, noleap
- **What it sets:** 
- **Usage:** 

JOBS:
+++++
See https://autosubmit.readthedocs.io/en/master/userguide/configure/develop_a_project.html#jobs-configuration
Default values in conf/jobs_${WORKFLOW}.yml

PLATFORMS:
++++++++++
See https://autosubmit.readthedocs.io/en/master/userguide/configure/develop_a_project.html#platform-configuration
Default values in conf/platform.yml