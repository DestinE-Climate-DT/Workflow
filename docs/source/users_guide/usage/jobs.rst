Jobs
----


Primary jobs
~~~~~~~~~~~~

Depending on the workflow mode selected, different primary jobs will be executed. The jobs are what Autosubmit submits to the remote platforms. They are a combination of templates (bash scripts) and the configuration selected by the user.

The templates are located in ``/workflow/templates``.

Local setup
***********

Performs basic checks as well as compressing the workflow project in order to be sent through the network.

Runs in the VM.

Given an experiment configuration, it is enough to run this job once. Any updates performed in the project will be sent to the HPC during the SYNCRHONIZE job.

For IFS-NEMO, if the user decided to compile a version of the model in a machine without internet connection, the dependencies will be downloaded at that stage to the VM.


Synchronize
***********

Syncs the workflow project with the remote platform. In general, the project is sent to the selected HPC. If the workflow uses the datamover machine (to transfer, download or wipe data from/to the MareNostrum5 data bridge), the project is also synched to that machine.

Runs in the VM.

This job should run every time that there is an update in the workflow sources. The only exception to this is if the changes are done in the templates or the configuration files. In that case, Autosubmit will combine the new templates or configuration options in runtime, so it's not necessary to rerun the syncrhonize step.

Remote setup
************

Untars the workflow project, which was sent in the synchronize step, and performs basic checks. After that, depending on the configuration, different tasks which used to belong to the remote setup are triggered (compilation, DVC and AQUA setup...).

Runs in the login node of the HPC.

Ini
***

Prepares any necessary initial data for the climate model runs.

If required, modifies namelists and perturbs restarts for multiple ensemble members. If the run is a restarted run, will also copy the restarts from another experiment.

Runs in the login node of the HPC. If a large number of restarts need to be copied, it is possible to change to the compute node via the main.yml.

Sim
***

Runs one chunk of climate simulation.

Runs in the HPC.

IFS-NEMO
________

The IFS-NEMO template does the following steps:

- Define expver (identifier of the input data), label, gtype, resol, levels, host, mpilib… Based on the configuration of the experiment.
- Compute the offset between IFS restart's fixed start date and the current SIM start date. This is to allow an experiment from restart files from another experiment without having to build the initial conditions.
- Computes fclen (forecast lenght in days, from the beggining of the experiment).
- Takes nodes, mpi, omp, jobid, jobname… from the environment. This is used by RAPS to distribute resources and generate the rundir name.
- Creates a backup of the current restart files (the txt files which have information about the actual restart files).
- Exports MultIO variables to choose the output plans.
- Compute realization based on the member identifier and the member list of the experiment.

- Choose between tasks / nodes setup depending on the configuraiton.
- Source .again, as described by the RAPS developers.
- Call hres with a set of flags, which depend on the experiment configuration.

- To easily restart a simulation from a given chunk, we always point to a directory named “current” for the input and ouptut restart files. After the simulation runs, the new restarts are moved to the next chunk’s directory.

IFS-FESOM
________

The IFS-FESOM template does the following steps:

- Define expver, label, gtype, resol, levels, host, mpilib… Based on the configuration of the experiment.
- Export MIR cache paths (``MIR_CACHE_PATH``, ``MIR_FESOM_CACHE_PATH``) required by the interpolation library.
- Compute the offset between IFS restart's fixed start date and the current SIM start date.
- Computes fclen (forecast length in days, from the beginning of the experiment).
- Takes nodes, mpi, omp, jobid, jobname… from the environment.
- Creates a backup of the current restart files (``waminfo``, ``rcf``) and the ``fesom_raw_restart/`` directory (which contains ``fesom.clock``). On retrials, the backups are automatically restored.
- Exports MultIO variables to choose the output plans.
- Configures I/O allocation for both IFS and FESOM, supporting task-based (``IFS_IO_TASKS`` / ``FESOM_IO_TASKS``) or node-based (``IFS_IO_NODES`` / ``FESOM_IO_NODES``) modes.
- If ensemble perturbation is enabled (``FESOM_PERTURB: "true"``), appends ``--fesom-perturb`` and ``--fesom-perturbation-seed`` flags with a member-dependent seed.
- For restarted runs, resolves the ``inipath`` for date redirection if the IFS start date differs from the simulation start date.
- Sets up RAPS environment (``RAPS_ROOTDIR``, ``RAPS_BINDIR``, ``RAPS_ETCDIR``) and calls hres with general, FESOM, restart, FDB, IO, namelist and user flags (e.g. nudging flags ``--destine-enable-nudging`` for story-nudging experiments).
- After the simulation, moves the new restarts to the next chunk's directory and updates the ``current`` symlink.

DQC (Data Quality Checker)
**************************

Performs basic checks on the data produced by the simulation.

Runs in the HPC.

It has two modes: BASIC and FULL.

The basic is blocking for the simulation, meaning that if the DQC BASIC detect a failure, the SIM+10 won't be submitted.

This 10 chunk's buffer is a tradeoff: it prevents from wasting resources by stopping the simulation, but allows to use wrappers in the SIM jobs, and avoids unnecessary waiting between SIM jobs.


DN (Data Notifier)
******************

Notifies when the wanted data is already produced by the model. Internally, it uses the GSV interface to detect how many messages are present in the FDB which match with the request.

If the data needs to be read from the data bridge of MareNostrum5, the data is downloaded to the HPC in that step using fdb-copy.

Access Point: mn5-prod-client1 (datamover) machine via AS VM (same as we use for the transfer). This machine has visibility to both the Bridge and HPC-FDB. genericfdb, a service account, will write transferred data to MN5.

Staging Location: /gpfs/scratch/ehpc01/dte/fdb/gateway

The data downloaded can't be deleted by a user and needs to be done by ECMWF upon request throught the Mattermost channel mn5-hpc-gateway-fdb-deletion.

There is a check to prevent that the data that is already downloaded is downloaded again.

The DN runs in the login node of the HPC when reading from the HPC or the LUMI Data Bridge, and in the datamover when reading from the MN5 Data Bridge.

OPA
***

Creates the statistics required by the data consumers (Apps). Runs in the HPC.

Applications
************

Creates usable output using the applications from the different use cases. Runs in the HPC.


+------------------+----------------+-------+------+------------+---------+
| JOB              | PLATFORM       | MODEL | APPS | END TO END | SIMLESS |
+==================+================+=======+======+============+=========+
| ``local_setup``  | Autosubmit VM  | x     | x    | x          | x       |
+------------------+----------------+-------+------+------------+---------+
| ``synchronize``  | Autosubmit VM  | x     | x    | x          | x       |
+------------------+----------------+-------+------+------------+---------+
| ``remote_setup`` | HPC*           | x     | x    | x          | x       |
+------------------+----------------+-------+------+------------+---------+
| ``ini``          | HPC Login node | x     |      | x          | x       |
+------------------+----------------+-------+------+------------+---------+
| ``sim``          | HPC            | x     |      | x          |         |
+------------------+----------------+-------+------+------------+---------+
| ``dqc``          | HPC            | x     |      | x          | x       |
+------------------+----------------+-------+------+------------+---------+
| ``dn``           | HPC Login node / client machine in MN5 |       | x    | x          | x       |
+------------------+----------------+-------+------+------------+---------+
| ``opa``          | HPC            |       | x    | x          | x       |
+------------------+----------------+-------+------+------------+---------+
| ``applications`` | HPC            |       | x    | x          | x       |
+------------------+----------------+-------+------+------------+---------+

Platform in which each one of the primary jobs run, as well as relation of jobs with each one of the workflow modes.

* Login nodes for LUMI, interactive partition for MareNostrum5


Additional jobs
~~~~~~~~~~~~~~~

Since v5.2.0, the applications are configured as additional jobs, that is, that they are enabled or disabled by setting them ``True`` or ``False`` in ``conf/main.yml``. They are mandatory in ``APPS`` and ``END-TO-END`` mode.

.. note::
   Running wrappers for OPA and APP jobs requires both the application and its wrapper key to be set to ``"True"`` in the workflow configuration (for example, in ``main.yml``):

   .. code-block:: yaml

      APP:
        HYDROMET: "True"
        HYDROMET_WRAPPER: "True"

Generate profiles
*****************

The profiles are yaml files that contain the variables that the models output. They are experiment dependent, meaning that they are different for every model, output portfolio and resolution.

The generate profiles task will create those files in the HPC according to the experiment configuration and the data portfolio submodule version.

The profiles are then used by several tasks, like the DQC, transfer or the wipe-check to identify the variables that the current experiment should contain.

Transfer
********

Transfers (copies) the data produced in the simulation to the Data Bridge.

In LUMI, the process of transferring uses the mars client of the machine to archive the data.

It consists in two steps: first, the data is retrieved from the FDB to a GRIB file using the GSV interface and according to the profiles.

We have one profile per levtype, and we generate one request per profile per split.

Those requests are placed in the HPC, in the root of the experiment, under transfer_requests.

Intermediate checkpoints are written to avoid duplication of archive in case of failure. The checkpoints are also in the same directory, under transfer_requests.

Then, an archive mars request is generated, and the GRIB file retrieved from the FDB is archived to the data bridge using the mars client. Once it is archived, the GRIB file is deleted.

In MareNostrum5, the approach is different. fdb-copy is used to transfer the data. This command is run in the datamover machine. It copies the whole content of the first layer of the schema of the FDB (all levtypes and params at the time).

In both approaches, it is possible to modify the metadata.

Runs on the HPC or on the client machine in MN5.


Backup
******

Copies the rundir and selected restart files to another partition.

Runs on the HPC.


Check_mem
*********

Monitors the memory consumption of the SIM jobs.

Runs on the login node of the HPC.


Wipe
****

Deletes data from the HPC-FDB that has already been transferred to the Data Bridge, freeing up storage space on the HPC. It consists of two jobs: a validation step (``wipe-check``) and a deletion step (``wipe``).

To enable it, set:

.. code-block:: yaml

    CONFIGURATION:
        ADDITIONAL_JOBS:
            WIPE: "True"
        WIPE:
            DOIT: "False"    # "False" = dry-run (default), "True" = actually delete
            UNSAFE: "False"  # "True" enables --unsafe-wipe-all (use with caution)

``GENERATE_PROFILES`` must be set to ``True`` (this is enabled automatically when WIPE is activated).

By default, ``WIPE.DOIT`` is ``False``, which means the job performs a dry-run: it validates that the data can be wiped but does not delete anything. Set it to ``True`` only after confirming that the transfer is working correctly.

.. note::
   When ``WIPE.DOIT`` is ``False``, the ``wipe`` job will appear as **FAILED** in the Autosubmit monitor. This is intentional: the job deliberately exits with a non-zero code after the dry-run to signal that no actual deletion occurred. The FDB info file update is also skipped in dry-run mode.

``WIPE.UNSAFE`` enables the ``--unsafe-wipe-all`` flag in ``fdb-wipe``. It is disabled by default and should only be used when strictly necessary.

The wipe handles two data types separately:

- **CLTE (climate time series)**: wiped for every chunk.
- **CLMN (monthly)**: wiped only when the chunk contains the first day of a month.

wipe-check
~~~~~~~~~~

Validates that data has been correctly transferred to the Data Bridge before deletion. It iterates over the DQC profiles and, for each one, compares the number of messages listed in the Data Bridge FDB against the expected count using strict equality — a difference of even one message causes the job to fail, preventing data loss.

Monthly profiles (those with ``monthly`` in the filename) are skipped unless the chunk contains the first day of a month, mirroring the same condition applied by the ``wipe`` job.

It also verifies that the experiment version (``EXPVER``) used in the TRANSFER job is consistent with the one configured for the wipe (``BRIDGE_EXPVER``). ``BRIDGE_EXPVER`` defaults to the Autosubmit experiment ID (``%DEFAULT.EXPID%``).

Depends on ``REMOTE_SETUP``, ``TRANSFER+10`` (giving a buffer of 10 chunks), ``LRA_GENERATOR+1``, and all application jobs
(``APP_WILDFIRES_FWI``, ``APP_WILDFIRES_WISE``, ``APP_ENERGY_INDICATORS``, ``APP_ENERGY_OFFSHORE``,
``APP_OBSALL``, ``APP_HYDROLAND``, ``APP_HYDROMET``). This ensures all application outputs are ready
before validating data for deletion. The job does not retry on failure (``RETRIALS: 0``).

Runs on the HPC or on the client machine in MN5.

wipe
~~~~

Executes the actual deletion of data from the HPC-FDB using ``fdb-wipe``. It runs only after ``WIPE_CHECK`` has completed successfully.

Also depends on ``DQC_FULL`` (only if it has ``FAILED`` status, to prevent wiping data that failed quality checks).
The job does not retry on failure (``RETRIALS: 0``).

After a successful wipe, the FDB info file is updated with the new data start date. This step is skipped when running in dry-run mode (``WIPE.DOIT=False``).

Runs on the HPC.


clean
*****

Compresses the rundir and log files from the HPC.
Purges the data of the FDB by deleting repeated entries.

Runs on the HPC.


clean_restarts
**************

Deletes selected restart directories on the remote platform.

Runs on the HPC.

``KEEP_EVERY``
    Determines which restart directories are kept.
    The first restart is always saved, and then one restart directory is kept at the frequency specified by this variable.

``KEEP_LAST``
    Number of most recent restart directories to always preserve, regardless of the ``KEEP_EVERY`` interval.
    Must be a positive integer.


scaling
*******

Performs a scaling test of the model.

Runs on the HPC.


aqua
****

Contains jobs related to AQUA diagnostics and visualization:

LRA_GENERATOR
~~~~~~~~~~~~~

Generates the LRA (Low-Resolution Archive) files.

AQUA_ANALYSIS
~~~~~~~~~~~~~

Performs the analysis of the AQUA files.

AQUA_PUSH
~~~~~~~~~

Pushes AQUA plots to LUMI-O.


AQUA_GRID_BUILD
~~~~~~~~~~~~~~~

Builds native grid definition files from simulation output for AQUA.
Runs once after the first SIM chunk. When enabled, ``LRA_GENERATOR`` depends on it.
Extracts grid structures using ``aqua grids build`` in the AQUA container.
ONLY needed if grids are not yet avaiable in aqua-dvc. Inform AQUA Team if the grids need to be added in aqua-dvc.


sync_lra
********

Contains jobs for synchronizing and publishing LRA data:

SYNC_LRA
~~~~~~~~

Synchronizes the LRA files to the common path.

UPDATE_CATALOG
~~~~~~~~~~~~~~

Updates the catalog ``urlpath`` with the new LRA location.

PUSH_UPDATED_CATALOG
~~~~~~~~~~~~~~~~~~~

Pushes the updated catalog to the repository.


postprocessing for application
******************************

Application-specific postprocessing jobs.

This is implemented as one job per application:

``POSTPROCESS_${APPNAME}``

These jobs allow running postprocessing scripts outside of the core streaming workflow.
They run at the end of the chunk in ``app`` or ``end-to-end`` mode.

Performance Jobs
~~~~~~~~~~~~~~~~~~~~~~~~~~~

The workflow includes dedicated performance monitoring and analysis jobs to help diagnose and quantify resource usage during simulations.

MONITOR_RESOURCES
^^^^^^^^^^^^^^^^^^

- ``Function``: Continuously collects per-node and per-step resource metrics while the SIM job is running.
- ``Data collected``:
    - Per-node pidstat samples at configurable intervals (default: 10 seconds).
    - SLURM ``sstat`` per-step and aggregated snapshots at configurable intervals (default: 60 seconds).
    - Threads-per-core (TPC) detection from the first allocated node to normalise CPU metrics to physsical nodes instead of logical nodes.
- ``Output``: Compressed JSON files under ``$HPCROOTDIR/performance/monitor/`` (e.g. ``metadata/start.json.gz``, ``pidstat/nodes/{node}/{ts}.json.gz``, ``sstat/steps/{step}_{ts}.json.gz``).
- ``Dependencies``: Runs while ``SIM`` has ``STATUS: RUNNING``.

PERFORMANCE_METRICS
^^^^^^^^^^^^^^^^^^^^

- ``Function``: After monitoring completes, computes end-to-end performance KPIs (CMIPS-style) from SLURM accounting and monitoring data.
- ``Metrics computed``:
    - **SYPD** (Simulated Years Per Day) and **QSYPD** (including queue time).
    - **Core-hours**: Total physical core-hours consumed (normalized by threads-per-core).
    - **CHSY** (Core-Hours per Simulated Year): Core-hour efficiency metric.
    - **Energy**: Energy consumption in Joules, Joules per simulated year, and carbon footprint (gCO2).
    - **Memory Bloat**: Ratio of actual memory usage (MaxRSS) to theoretical restart size.
    - **Storage**: Total FDB output data size (bytes) and data intensity (bytes per core-hour).
    - **Data Output Cost**: Time and resource fractions dedicated to I/O operations (from model timing files).
    - **Grid Points**: Total number of grid points for the simulation.
- ``Output``: A compressed JSON summary in ``$HPCROOTDIR/performance/performance_metrics/{jobname}/CMIPS.json.gz`` containing metadata, raw SLURM info and computed performance metrics.
- ``Dependencies``: Depends on ``MONITOR_RESOURCES`` with ``STATUS: COMPLETED``.

+---------------------------+-------------------------------+
| JOB                       | PLATFORM                      |
+===========================+===============================+
| ``transfer``              | HPC                           |
+---------------------------+-------------------------------+
| ``backup``                | HPC                           |
+---------------------------+-------------------------------+
| ``check_mem``             | HPC Login node                |
+---------------------------+-------------------------------+
| ``wipe``                  | HPC                           |
+---------------------------+-------------------------------+
| ``wipe-check``            | HPC / client machine in MN5   |
+---------------------------+-------------------------------+
| ``clean``                 | HPC                           |
+---------------------------+-------------------------------+
| ``clean-restarts``        | HPC                           |
+---------------------------+-------------------------------+
| ``scaling``               | HPC                           |
+---------------------------+-------------------------------+
| ``LRA_GENERATOR``         | HPC                           |
+---------------------------+-------------------------------+
| ``AQUA_ANALYSIS``         | HPC                           |
+---------------------------+-------------------------------+
| ``AQUA_PUSH``             | Autosubnut VM                 |
+---------------------------+-------------------------------+
| ``SYNC_LRA``              | LUMI                          |
+---------------------------+-------------------------------+
| ``UPDATE_CATALOG``        | HPC                           |
+---------------------------+-------------------------------+
| ``PUSH_UPDATED_CATALOG``  | Autosubmit VM                 |
+---------------------------+-------------------------------+
| ``MONITOR_RESOURCES``     | HPC Login node                |
+---------------------------+-------------------------------+
| ``PERFORMANCE_METRICS``   | HPC Login node                |
+---------------------------+-------------------------------+
| ``POSTPROCESS_${APPNAME}``| HPC                           |
+---------------------------+-------------------------------+

.. _selectable_configuration:

Selectable configuration
~~~~~~~~~~~~~~~~~~~~~~~~

We are now running the workflow with the new version of the ``CUSTOM_CONFIG`` and the minimal configuration new features of Autosubmit.
This new configuration scheme allows for a distributed, hierarchical parametrization of the workflow, thereby providing a more customizable, modular, and user-friendly workflow. The structure, domain and use of this new configuration scheme will likely evolve as it adapts to the needs of other work packages.

In the file ``main.yml`` the user will decide the parameters of the simulation. Depending on what the user selects, one set or another of configurations will be loaded.

The following parameters will be used to load the configuration files:

- ``RUN.WORKFLOW``
- ``MODEL.NAME``
- ``MODEL.SIMULATION``
- ``MODEL.GRID_ATM``
- ``CONFIGURATION.DATA_PORTFOLIO`` — must be set in ``main.yml`` as ``full``, ``reduced``, or ``minimal`` to load the corresponding output portfolio configuration
- ``CONFIGURATION.ADDITIONAL_JOBS.*``
- ``APP``

The user can overwrite any parameter defininig it in the ``main.yml`` file. This will have priority over the default configuration files loaded previously.

.. note ::
    For a comprehensive list of the allowed values, see :ref:`configuration_keys`.


In the ``minimal.yml`` the basic information of the experiment is defined. It is the last file loaded in the configuration process. For more information: `Autosubmit documentation on minimal experiments  <https://autosubmit.readthedocs.io/en/master/userguide/set_and_share_the_configuration/index.html#advanced-configuration>`_.
