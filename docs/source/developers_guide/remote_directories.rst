Remote directories
******************

This section provides and overlook of the remote directories used by the workflow, and how they are used by the different applications.

Autosubmit experiment directory
-------------------------------
When the workflow is executed it creates a directory for each experiment in the remote platform, which is named after the experiment ID. This directory is the project directory from the ClimateDT VM which includes the worfklow sources that are in GitLab/GitHub, this proj folder is transferred in the synchronize job and contains the necessary files and subdirectories for running the experiment in the remote platform.
Additionally, the experiment directory contains the ``LOG_<expid>`` folder which contains the batch jobs which are finally submitted to the remote platform, and also the logs of the jobs that are run.

These directories are the most basic ones for the Autosubmit workflow to operate. They are created in all the remote platforms that the workflow runs on.
They are created by the workflow on the ``HPCROOTDIR`` path, which is constructed with the ``SCRATCH_DIR``, the platform project ``PLATFORMS.<PLATFORM>.PROJECT`` and the platform user name ``PLATFORMS.<PLATFORM>.USER``:

``HPCROOTDIR``: ``<SCRATCH_DIR>/<PROJECT>/<USER>/<EXPID>``

The basic and functional folders created by autosubmit are the following ones:

- ``git_project.tar.gz``
- ``git_project``
- ``LOG_<expid>``

More folders and files may be created in the experiment directory depending on the subworkflow and the specific experiment configuration. They are reviewed in later sections.

Precompiled models, input and output data
-----------------------------------------

Precompiled models
~~~~~~~~~~~~~~~~~~

The Autosubmit workflow allows for diferent modes of usage, it allows compiling and running from source (this is option is currently working for the IFS-NEMO subworkflow).
The other option is using precompiled model binaries and input data, which are stored in the remote platform. These files are typically stored in a specific directory structure that allows the workflow to access them easily.

These paths depend on the remote platform and the workflow mode, operational or development, but they generally follow a structure similar to:

``<SCRATCH_DIR>/<PROJECT>/models/<MODEL>/<VERSION>/``

ex development mode: ``/project/project_465000454/models/icon/destine_phase2_v1.2.0``

The project variables defines if we are running using the operational or development option.


Model input data
~~~~~~~~~~~~~~~~

Model input data will likely be managed/stored in a dvc respository, which is a version control system for data files. This is the case currently for IFS-NEMO and will likely be the case for ICON and IFS-FESOM.

Although at current time, while this is being documented, the input data for the models (generally the case of ICON) and some of the applications, is stored in the following directory

- LUMI: ``/appl/local/climatedt/pool/data/``
- Marenostrum5: ``/gpfs/scratch/ehpc01/input_data``

In the case for ICON, these folders are then linked in each model version folder specied before.

Additionally for IFS-NEMO, the input data is added to the ``HPCROOTDIR``:

- ``inipath``: Here the initial conditions and configuration files for IFS-NEMO are included.

For IFS-FESOM, the input data and model binaries are bundled in the pre-installed model path (``MODEL.PATH``). The MIR interpolation cache (``MIR_CACHE_PATH``, ``MIR_FESOM_CACHE_PATH``) is stored in the model directory and must be accessible at runtime.

Model rundir
~~~~~~~~~~~~~~~~
When the models run, a rundir is created in the ``HPCROOTDIR``, this directoy contains the model simulation files for each chunk.
In the case of ICON, the folder structure is the following one;

- ``restarts``
- ``run_<CHUNK_STARTDATE>-<CHUNK_ENDDATE>_<expid>_<sdate>_<member>_<chunk>_<job>-<SLURM_JOB_ID>``

The restarts folder contains the restart files for each chunk, this is discussed in more detail in section :ref:`restarts`.
For the run directories, in the case for ICON it contains the model namelists for that chunk, links to the necessary input files, and more model specific files that are needed for the model to run. The run directories are named after the chunk start and end date plus the Autosubmit job name and SLURM job ID, for example: ``run_19900101-19900201_t0qn_19900101_fc0_5_SIM-12345678``. This pattern is preserved even when jobs run inside Autosubmit wrappers.

For IFS-NEMO, the restarts are added to the ``HPCROOTDIR`` under the:

- ``restarts``: Restart directory, which includes the restarts for each member and chunk

For IFS-FESOM, the rundir is created by RAPS under ``HPCROOTDIR``. The restart directory includes:

- ``restarts``: Contains IFS restarts (``rcf``, ``waminfo``) and FESOM restarts (``fesom_raw_restart/``, ``fesom.clock``) per member and chunk

Model output data
~~~~~~~~~~~~~~~~~

Model data is all managed by the different FDBs (Fields Data Base) and in theory follows the GSV (General State Vector) metadata format. Where these FDB data is stored for each experiment, depends on the type of workflow being run and the remote platform being used.
As mentioned in other sections, there are test, pre-production, production, operational, operational-read and research experiment types.

For the production and pre-production experiments, the data is stored in the **HPC_FDB**, this FDB is usually stored under the path specified by **FDB_PROD**:

- Marenostrum5: ``/gpfs/scratch/ehpc01/dte/fdb``
- LUMI: ``/appl/local/destine/fdb``

For the test and research experiments, the data is stored using LOCAL FDBs, which are stored in the experiments directory under the path ``%SCRATCH_DIR%/%PROJECT%/experiments``:

- Marenostrum5: ``/gpfs/scratch/ehpc01/experiments/$autosubmit_expid``
- LUMI: ``/scratch/project_465000454/experiments/$autosubmit_expid``

Data consumers (apps and opa) input for auxiliary data
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Data consumers use may need auxiliary data to run, such as some refference files for the bias adjustment or others that are use case specific.

- Marenostrum5:
  - test environment: ``/gpfs/projects/ehpc01/applications/``
  - production environment ``"/gpfs/scratch/ehpc01/input_data/applications/``

- LUMI:
  - test environment: ``/project/project_465000454/applications/``
  - production environment: ``/appl/local/climatedt/input_data/applications/``

Folders created by components and additional jobs
-------------------------------------------------

The workflow creates additional folders in the ``HPCROOTDIR`` directory, depending on the components and jobs that are executed.
As a reference, the following folders are created by the most complete version of the workflow, the end-to-end workflow run:

- ``dqc_output``: Directory containing data quality checker log outputs
- ``out``: Output folder for AQUA and the LRA
- ``profiles``: Profiling information from runs
- ``wipe_requests``: Contains wipe request files generated by the ``WIPE_CHECK`` and ``WIPE`` jobs, organized into per-realization subdirectories (``wipe_requests/<REALIZATION>/``). Includes flat request files (e.g. ``general_request_clte_<CHUNK>_request.flat``) used by ``fdb-wipe``, and listing logs (e.g. ``<profile>_sdate_<START>_endate_<END>_real_<MEMBER>_list.log``) from the validation step.
- ``<EXPID>.yaml``: Experiment file with necessary data fields for AQUA
- ``fdb_usage.log``: Log file tracking FDB and storage usage
- ``check_mem``: Memory usage check files
