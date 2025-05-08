==========================
Available keys in main.yml
==========================

RUN:
++++

Minimum set of parameters that define an experiment.

WORKFLOW:
----------

- **Intention:** select the workflow type.
- **Options:** ``end-to-end``, ``model``, ``apps``. ``simless``.
- **Usage:** selects the job list. This key is used in `conf/bootstrap/include.yml <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/blob/main/conf/bootstrap/include.yml>`_ to load the joblist file. It will load `jobs_apps.yml <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/blob/main/conf/jobs_apps.yml>`_, `jobs_model.yml <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/blob/main/conf/jobs_model.yml>`_ or `jobs_end-to-end.yml <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/blob/main/conf/jobs_end-to-end.yml>`_

ENVIRONMENT:
-------------

- **Intention:** to select the environment being used. Generally ``cray`` for ``LUMI`` and ``intel``, ``openmp``... for Marenostrum.
- **Options:** In LUMI, ``cray``.
- **What it sets:** It sets the environment to use with the pre-compiled binaries. Check the models' pre-compiled directory to see which environments are supported.
- **Usage:** as a switch and as a variable in the workflow.

PROCESSOR_UNIT:
---------------

- **Intention:** To select the processor unit being used.
- **Options:** ``cpu`` for ``ifs-nemo`` & ``icon`` (r2b4 only), ``gpu`` for ``ifs-nemo`` and ``gpu_gpu`` for ``icon`` (hetjobs for r2b8 and r2b9).
- **What it sets:** It sets the processor_unit variable, which is used to load specific environment settings, runscripts or general configuration for running on the different options.
- **Usage:** as a switch and as a variable in the workflow.

TYPE:
-----------

- **Intention:** To mark the experiment as a production, research, test or pre-production, define where it outputs, the expver and if it should go to the data bridge or not. This key also is used for the apps workflow to read from experiments that have the configuration (e.g. read from TYPE: [production, research, pre-production, test]).
- **Options:** ``production``, ``research``, ``pre-production`` or ``test`` (default).
- **What it sets:**
    - Production: The experiment writes the data using 0001 expver instead of the expid provided by Autosubmit. It writes in the HPC-FDB instead of in a local FDB.
    - Research: The experiment writes the data using the expid provided by Autosubmit. It writes in the HPC-FDB instead of in a local FDB.
    - Pre-production: The experiment writes the data using 0001 expver instead of the expid provided by Autosubmit. It writes in a local FDB.
    - Test: The experiment writes the data using the expid provided by Autosubmit. It writes in a local FDB.

MODEL:
++++++

Only if WORKFLOW: ``end-to-end`` or ``model``.

NAME:
-----

- **Intention:** to select which model runs.
- **Options:** ``icon``, ``ifs-nemo``, ``ifs-fesom``, ``nemo``.
- **What it sets:** Select which SIM template will run. Select `the directory <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/blob/main/conf/model/>`_ to load the grid-specific parameters.
- **Usage:** as a switch and as a variable in the workflow.

GRID_ATM:
---------

- **Intention:** to select the resolution (grid) of the atmosphere.
- **Options:** depend on the model. For ICON: ``r2b4`` (test), ``r2b8`` (development) & ``r2b9`` (production). For IFS-NEMO: ``tco79l137`` (test), ``tco1279l137`` (development), ``tco2559l137`` (production).
- **What it sets:** Selects which file of the `model directory <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/tree/main/conf/model/ifs-nemo>`_ will be loaded. In IFS-based models, it sets keys related to the inputs: ``GTYPE`` (tco), ``EXPVER`` (experiment ID of the inputs), ``RESOL`` (resolution), ``LEVELS`` (pressure levels) and ``LABEL``.
- **Usage:** as a switch and as a variable in the workflow.

GRID_OCE:
---------

- **Intention:** to select the resolution (grid) of the ocean.
- **Options:** depends on the model. For ICON: ``r2b4`` (test), ``r2b8`` (development) & ``r2b9`` (production). For IFS-NEMO: ``eORCA1_Z75``, ``eORCA12_Z75``
- **Usage:** as a variable in the workflow.

VERSION:
--------

- **Intention:** to select model pre-compiled binaries to run.
- **Options:** depends on the model. All model versions are stored in ``/projappl/project_465000454/models/{icon,ifs-nemo,ifs-fesom}``.
- **What it sets:** It sets the pre-compiled binaries of the model version to run, and the default inputs used.
- **Usage:** as a switch and as a variable in the workflow.

COMPILE:
---------

- Only for IFS-NEMO.
- **Intention:** to compile the model.
- **Options:** ``True`` or ``False``.


SIMULATION:
-----------

- **Intention:** to set the keys that characterize a type of simulation.
- **Options:** All the files of `the simulation directory <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/tree/main/conf/simulation>`_.
- **What it sets:** ``EXPERIMENT`` keys (date, chunk length), default ``PARTITION`` and ``MAX_WALLCLOCK`` for each platform, default ``WALLCLOCK`` of the ``SIM`` step, default number of retrials in the ``SIM`` step.
- **IFS-NEMO:** type of ``RAPS_EXPERIMET``, and only in some ``MODEL_VERSIONS`` the selection of the MultIO plans.
- **Usage:** switch. Not used as a variable in the workflow.

DVC_INPUTS_BRANCH:
------------------

- Only for IFS-NEMO.
- **Intention:** to specify the input files for the simulation.
- **Options:** branches of https://earth.bsc.es/gitlab/digital-twins/de_340-2/dvc-de_340.git
- **What it sets:**
- **Note:** if this option is used, the submodule dvc-cache-de340 needs to be cloned (specified in minimal.yml)

RAPS_MIR_CACHE_PATH
-------------------

- **Purpose:** override the default value for `MIR_CACHE_PATH` defined by RAPS. Currently not usable for LUMI as it is enforved by RAPS for this machine.
- **Default:** empty. Uses the default defined by RAPS.
- **Options:** a directory.
- **Sets:** exports `MIR_CACHE_PATH`

RAPS_MIR_FESOM_CACHE_PATH
-------------------------

- Only for IFS-FESOM.
- **Purpose:** override the default value for `MIR_FESOM_CACHE_PATH` defined by RAPS. Currently not usable for LUMI as it is enforved by RAPS for this machine.
- **Default:** empty. Uses the default defined by RAPS.
- **Options:** a directory.
- **Sets:** exports `MIR_FESOM_CACHE_PATH`


APP:
+++++

NAMES:
------

- **Intention:** to select the application(s) that will run in a simulation.
- **Options:** ENERGY_ONSHORE, ENERGY_OFSHORE, MHM, HYDROMET, WILDFIRES_FWI, WILDFIRES_WISE, DATA.
- **What it sets:**  the application that will be run either in workflow type: ``apps`` or ``end-to-end``.
- **Usage:** ['**option**']. e.g. ['ENERGY_ONSHORE']. For multiple apps: [ENERGY_ONSHORE, HYDROLAND, ...]

OUTPATH: (deprecated. Moved to OPA_OUTPATH in conf/application/opa.yml, soon to be removed from `main.yml`)
------------------------------------------------------------------------------------------------------------

READ_FROM_DATABRIDGE:
---------------------
- **Intention:** to specify if the application should read from the databridge.
- **Options:** "true" or "false".

CONFIGURATION:
+++++++++++++++

CONTAINER_DIR:
--------------

- **Intention:** to specify the container directory.
- **Default:** "%CONFIGURATION.HPC_PROJECT_DIR%/containers"
- **Options:** any path the user has the container stored.

PROJECT_SCRATCH:
----------------

- **Intention:** to specify the project scratch directory.
- **Default:**  "%CURRENT_SCRATCH_DIR%/%CURRENT_PROJECT%"

LIBDIR:
-------

- **Default:** "%HPCROOTDIR%/%PROJECT.PROJECT_DESTINATION%/lib"

SCRIPTDIR:
----------

- **Default:** "%HPCROOTDIR%/%PROJECT.PROJECT_DESTINATION%/runscripts"


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

SCALING
~~~~~~~~
- **Intention:** activates the scaling jobs.
- **Options:** "true" or "false".
- **Note:** should be used in a ``simless`` workflow.

AQUA
~~~~
- **Intention:** activates the aqua jobs.
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
- **What it sets:** The unit lenght of the chunk in the simulation.
- **Usage:**

SPLITSIZEUNIT:
--------------
- **Intention:** to specify the unit of chunk size.
- **Options:** day (more options to come)
- **What it sets:** The lenght of the split execution.
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

GSV:
++++

VERSION:
--------

- Specify the version of the GSV_interface contianer used in the workflow.
- Default: 2.9.7

WEIGHTS_PATH:
-------------

- Path to the weighs.
- Default: "%CONFIGURATION.HPC_PROJECT_DIR%/gsv_files/gsv_weights"

TEST_FILES:
-----------

- Default: "%CONFIGURATION.HPC_PROJECT_DIR%/gsv_files/gsv_test_files"

DEFINITION_PATH:
----------------

- Default: "%CONFIGURATION.HPC_PROJECT_DIR%/gsv_files/grid_definitions"

REQUEST:
++++++++

- By default, this is specified in ``conf/simulation`` and ``conf/data_gov``. If the user wants to read from other simulations (for example in a SIMLESS worfklow) this keys can be used to specify the keys that he/she wants to read from.

EXPERIMENT:
------------

- **Intention:** to specify the experiment.
- **Options:** "cont", "hist", "SSPX-Y.Z"...
- **What it sets:** the experiment key in the FDB.

ACTIVITY:
---------

- **Intention:** to specify the activity.
- **Options:** "projections", "baseline"
- **What it sets:** the activity key in the FDB.

GENERATION:
------------

- **Intention:** to specify the generation.
- **Options:** "1"
- **What it sets:** the generation key in the FDB.

REALIZATION:
------------

- **Intention:** to specify the realization.
- **Options:** integer, starting from "1".
- **What it sets:** the realization key in the FDB.

EXPVER:
--------

- **Intention:** to specify the experiment version.
- **Options:** "0001" for production, Autosubmit experiment ID for the rest.
- **What it sets:** the expver key in the FDB.

FDB_HOME:
----------

- **Intention:** to specify the path of the FDB.
- **Options:** any path the user wants to read from.
- **What it sets:** the FDB_HOME variable in the workflow.

MODEL:
------

- **Intention:** to specify the model.
- **Options:** "icon", "ifs-nemo", "ifs-fesom"
- **What it sets:** the model key in the FDB.


JOBS:
+++++
See https://autosubmit.readthedocs.io/en/master/userguide/configure/develop_a_project.html#jobs-configuration
Default values in conf/jobs_${WORKFLOW}.yml

PLATFORMS:
++++++++++
See https://autosubmit.readthedocs.io/en/master/userguide/configure/develop_a_project.html#platform-configuration
Default values in conf/platform.yml

ARCH_GPU:
---------

- **Intention:** to specify the architecture to compile IFS-NEMO in GPUs.

ARCH_CPU:
---------

- **Intention:** to specify the architecture to compile IFS-NEMO in CPUs.

ADDITIONAL_COMPILATION_FLAGS_GPU:
----------------------------------

- **Intention:** to specify additional compilation flags for IFS-NEMO in GPUs.

ADDITIONAL_COMPILATION_FLAGS_CPU:
----------------------------------

- **Intention:** to specify additional compilation flags for IFS-NEMO in CPUs.


DVC_INPUTS_CACHE:
-----------------
- **Intention:** to specify the path of the DVC cache for the simulation.

FDB_DIR:
--------
- **Intention:** to specify the path of the FDB directory for test and pre-production experiment.

FDB_PROD:
---------
- **Intention:** to specify the path of the FDB directory for production experiment.

HPC_PROJECT_DIR:
----------------
- **Intention:** to specify the path of the HPC project directory, where permanent data and containers are stored.

