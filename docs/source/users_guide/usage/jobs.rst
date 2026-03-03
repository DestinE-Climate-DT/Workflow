Jobs
----


Primary jobs
~~~~~~~~~~~~

Depending on the workflow mode selected, different primary jobs will be executed. The jobs are what Autosubmit submits to the remote platforms. They are a combination of templates (bash scripts) and the configuration selected by the user.

The templates are located in ``/workflow/templates``.

- ``local_setup``: performs basic checks as well as compressing the workflow project in order to be sent through the network.
- ``synchronize``: syncs the workflow project with the remote platform.
- ``remote_setup``:
    - loads the necessary environment and then compiles the different models/applications.
    - Performs checks in the remote platform.
    - Installs the running applications and the GSV interface.
- ``ini``: prepares any necessary initial data for the climate model runs. Runs in the login node of the HPC.
- ``sim``: runs one chunk of climate simulation. Runs in the HPC.
- ``dqc``: performs basic checks on the data produced by the simulation. Runs in the HPC. It has two modes: BASIC and FULL.
- ``dn``: notifies when the wanted data is already produced by the model. Runs in the login node of the HPC.
- ``opa``: creates the statistics required by the data consumers (Apps). Runs in the HPC.
- ``applications``: creates usable output using the applications from the different use cases. Runs in the HPC.


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

The following additional jobs are optional:

- ``transfer``: transfers the data produced in the simulation to the Data Bridge. Runs in the HPC or the client machine in MN5.
- ``backup``: copies the rundir and certain restarts to another partition. Runs in the HPC.
- ``check_mem``: monitors the memory consumption of the SIM jobs. Runs in the login node of the HPC.
- ``wipe``: contains two jobs:
    - ``wipe-check``: checks which data has already been transferred to the HPC-FDB. Runs in the HPC or the client machine in MN5.
    - ``wipe``: wipes already transferred data from the HPC-FDB. Runs in the HPC.
- ``clean``: compresses the rundir and the logs from the HPC. Purges the data of the FDB (deletes repeated entries). Runs in the HPC.
- ``clean_restarts``: deletes certain restart directories on the remote platform. Runs in the HPC.
    - ``KEEP_EVERY``: this variable determines which restart directories to keep. The 1st is always saved then each restart directory at the frequency indicated with this variable.
- ``scaling``: performs a scaling test of the model. Runs in the HPC.
- ``aqua``: use the variable ``AQUA.EXPERIMENT_NAME`` to clearly name the AQUA plots, files, and catalog branch. contains 3 jobs:
    - ``LRA_GENERATOR``: generates the LRA (Low resolution archive) files
    - ``AQUA_ANALYSIS``: Performs the analysis of the AQUA files
    - ``AQUA_PUSH``: Pushes AQUA plots to LUMI-O
    - ``AQUA_PUSH`` and the second one performs the analysis of the AQUA files
- ``sync_lra``: contains 3 jobs:
    - ``SYNC_LRA``: syncs the LRA files to the common path.
    - ``UPDATE_CATALOG``: updates the catalog urlpath with the new location of the LRA.
    - ``PUSH_UPDATED_CATALOG``: pushes the updated catalog to the reposotitory.
- postprocessing for application: It is actually a job per application (``POSTPROCESS_${APPNAME}``), and allows for postprocessing scripts outside of the core streaming. It runs at the end of the chunk in ``app`` or ``end-to-end`` mode.(to be used in app or end-to-end modes) to run postprocessing scripts outside the core streaming.

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

+-------------------+----------------+
| JOB               | PLATFORM       |
+===================+================+
| ``transfer``      | HPC            |
+-------------------+----------------+
| ``backup``        | HPC            |
+-------------------+----------------+
| ``check_mem``     | HPC Login node |
+-------------------+----------------+
| ``wipe``          | HPC            |
+-------------------+----------------+
| ``clean``         | HPC            |
+-------------------+----------------+
| ``clean-restarts``| HPC            |
+-------------------+----------------+
| ``scaling``       | HPC            |
+-------------------+----------------+
| ``LRA_GENERATOR`` | HPC            |
+-------------------+----------------+
| ``AQUA_ANALYSIS`` | HPC            |
+-------------------+----------------+
| ``AQUA_PUSH``     | Autosubnut VM  |
+-------------------+----------------+
| ``SYNC_LRA``      | LUMI           |
+-------------------+----------------+
| ``UPDATE_CATALOG``| HPC            |
+-------------------+----------------+
| ``PUSH_UPDATED_CATALOG`` | Autosubmit VM     |
+-------------------+----------------+
| ``MONITOR_RESOURCES`` | HPC Login node |
+-------------------+----------------+
| ``PERFORMANCE_METRICS`` | HPC Login node |
+-------------------+----------------+
| ``POSTPROCESS_${APPNAME}`` | HPC   |
+-------------------+----------------+

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
- ``CONFIGURATION.ADDITIONAL_JOBS.*``
- ``APP``

The user can overwrite any parameter defininig it in the ``main.yml`` file. This will have priority over the default configuration files loaded previously.

.. note ::
    For a comprehensive list of the allowed values, see :ref:`configuration_keys`.


In the ``minimal.yml`` the basic information of the experiment is defined. It is the last file loaded in the configuration process. For more information: `Autosubmit documentation on minimal experiments  <https://autosubmit.readthedocs.io/en/master/userguide/set_and_share_the_configuration/index.html#advanced-configuration>`_.
