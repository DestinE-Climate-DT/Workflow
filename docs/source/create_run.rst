Create your own experiment
===========================

Create an Autosubmit experiment using minimal configurations
----------------------------------------------------------------

.. code-block:: bash

    autosubmit expid \
      --description "A useful description" \
      --HPC <TYPE_YOUR_PLATFORM_HERE> \
      --minimal_configuration \
      --git_as_conf conf/bootstrap/ \
      --git_repo https://earth.bsc.es/gitlab/digital-twins/de_340/workflow \
      --git_branch main


.. warning::
    you MUST change ``<TYPE_YOUR_PLATFORM_HERE>`` below with your platform, and add a description.
    For example: lumi or marenostrum5.
    Check the available platforms at ``/appl/AS/DefaultConfigs/platforms.yml``
    or ``~/platforms.yml`` if you created this file in your home directory.



You will receive the following message: ``Experiment <expid> created``, where ``<expid>``
is the identifier of your experiment. A directory will be created for your experiment
at: ``/appl/AS/AUTOSUBMIT_DATA/<expid>``.

The command ``autosubmit expid`` above will create a ``minimal.yml`` file for you.
Modify this file (e.g. ``/appl/AS/AUTOSUBMIT_DATA/<expid>/conf/minimal.yml``) as needed.

In the ``GIT`` section in the ``minimal.yml``, you can use ``PROJECT_SUBMODULES`` to set
the Git submodules for the models you want to run. For applications, submodules are only allowed in development branches.

For a model workflow, you need:
- ``catalog`` if you want to run AQUA.
- ``data-portfolio`` in case you need the DQC profiles (DQC, TRANFER, WIPE tasks).
- ``dvc-cache-de340`` if you want to use DVC inputs.

Or leave it empty to select all the submodules. Autosubmit will clone
them when you run ``autosubmit create`` (first run) or ``autosubmit refresh``.

.. warning::
    You need to have access to the corresponding sources
    repository and your ssh keys must be uploaded there.


When running ``autosubmit create <expid>``, two additional files will be created: ``main.yml`` and, if you are running an applications workflow, ``request.yml``.
The ``main.yml`` file is the main configuration file for your experiment. It will be copied from the examples that we have in the repository, depending on your needs.
The examples can be found in ``lib/request_examples`` and ``mains`` in the workflow repository.
The ``request.yml`` file is used to request data from the HPC (if you run applications).

.. warning::
    All the files that you create in the ``conf`` directory will be loaded by Autosubmit.
    If you need to keep backups or copies of your files, please store them somewhere else.



Customize your experiment
=========================


Examples for each workflow type in ``main_example_endtoend.yml``, ``main_example_model.yml``,
or ``main_example_apps.yml``. Information about what each key does can be found in the `Available keys for main` section.



How to switch between configurations: ``main.yml``
--------------------------------------------------

``main.yml`` is the main file that users will modify. The switches are located there, and depending on those keys, Autosubmit will load some files or others.
In this file, one can also define any customized variable, because it will overwrite the ones loaded in the files.
For example, if you need to frequently change the start date or the length of your simulation, you can uncomment these lines of ``main.yml``, and fill them in, following the specified format:

.. code-block:: yaml


    EXPERIMENT:
       DATELIST: yyyymmddhh
       CHUNKSIZEUNIT: day/month/year
       CHUNKSIZE: nn
       NUMCHUNKS: nn
       SPLITSIZEUNIT: day #(for apps and end-to-end workflows)

If you need to change the wallclock of your job, add the following lines into your ``main.yml``:

.. code-block:: yaml

     JOBS:
         SIM:
             WALLCLOCK: "00:30" #this is a 30 min wallclock.

Another case would be if you are frequently changing the number of nodes that you are using. We have defaults, that you can find in ``/proj/git_project/conf/model/${model_name}``, but they can be overwritten in ``main.yml``, adding the following lines (the ones that you consider):

.. code-block:: yaml

     PLATFORMS:
         LUMI:
             NODES: n
             TASKS: nn
             THREADS: n

In the case of IFS-NEMO, to modify the IO resources you should add:

.. code-block:: yaml

     CONFIGURATION:
         IFS:
             IO_NODES: n
     CONFIGURATION:
         NEMO:
             IO_NODES: n

Or:

.. code-block:: yaml

     CONFIGURATION:
         IFS:
             IO_TASKS: n
     CONFIGURATION:
         NEMO:
             IO_TASKS: n


How to add wrappers into the workflow
--------------------------------------

The purpose of the wrappers is to submit multiple jobs in a single SLURM task. This increases the wallclock of the submitted task, but once this job enters, the jobs in the wrapper will run one after the other skipping the queueing time. For this workflow, you probably want to wrap multiple ``SIM`` jobs into one task.
To configure them, add the following lines in your ``main.yml``:

.. code-block:: yaml

     WRAPPERS:
         WRAPPER_0:
             TYPE: "vertical"
             JOBS_IN_WRAPPER: "SIM"

     PLATFORMS:
            LUMI:
                 PARTITION: "small/standard" #choose one
                 MAX_WALLCLOCK: "72:00/48:00" #this will be the wallclock of the wrapper

Autosubmit will fit as many ``SIM`` jobs as it can, by dividing the defined ``MAX_WALLCLOCK`` between the ``WALLCLOCK`` of your job. Once this is saved, you can preview the graph with:

``autosubmit inspect <expid> -cw -f # Visualize wrapper cmds``


How to run the additional jobs
---------------------------------------------------------------------------------------------

By default, most of the additional jobs are disabled. You can enable them adding this in your ``main.yml`` and setting the ones that you want to run to "True".

.. code-block:: yaml

    CONFIGURATION:
        ADDITIONAL_JOBS:
            TRANSFER: "False"
            BACKUP: "True"
            MEMORY_CHECKER: "False"
            DQC: "False"
            WIPE: "True"
            CLEAN: "True"
            SCALING: "False"
            AQUA: "True"



How to change default start dates, chunk size, and the number of chunks (Recommended option)
---------------------------------------------------------------------------------------------

If you will be frequently using a determined set of values and that set does not exist yet, you can create your own configuration. To do so, go into ``/proj/git_project/conf/simulation`` and copy one of the existing files. Then, modify it. You can use those configurations by placing the name of the file that you have just created in ``main.yml``:

.. code-block:: yaml

     MODEL:
         SIMULATION: file_name

In the case of IFS-NEMO, you can also modify your ICMCL file there. If you want to make those configurations available for everyone, you can push your new file to our GitLab.


How to change grid-specific variables (number of nodes, processors...):
If you will be frequently using a determined set of values and that set does not exist yet, you can create your own configuration. To do so, go into ``/proj/git_project/conf/models/${model_name}`` and copy one of the existing files. Then, modify it. You can use those configurations by placing the name of the file that you have just created in ``main.yml``:

.. code-block:: yaml

     MODEL:
         GRID_ATM: file_name

In the case of IFS-NEMO, you can also modify the number of IO nodes there. If you want to make those configurations available for everyone, you can push your new file to our GitLab.


How to use your own input data and model installation
------------------------------------------------------


We are willing to store model versions and inputs in a uniform way. In every platform, we have a defined path where we will store inputs and model versions (or have symbolic links pointing to the path where they are actually stored).
- LUMI: ``/projappl/project_465000454/models/${MODEL_NAME}``
- MareNostrum5: ``/gpfs/projects/ehpc01/models/${MODEL_NAME}``

Under these directories, you can find:
- Different folders, containing the model version. The path to any installation should follow: ``${MODEL_VERSION}/make/${PLATFORM}-${ENVIRONMENT}``.
- ``${MODEL_VERSION}/inidata:`` points to the input directory.

Then, you should specify the ``MODEL_VERSION`` and the ``ENVIRONMENT`` in ``main.yml``

.. code-block:: yaml

    RUN:
        ENVIRONMENT: "cray/intel/..."

    MODEL:
        MODEL_VERSION: "Name-of-the-model-version"


If the version that you are specifying doesn't exist, or is not correctly configured, the remote setup will fail.

If you need a new one, you should specify the MODEL_VERSION in the same way, but also:

.. code-block:: yaml

    CONFIGURATION:
        INSTALL: "shared"


A MODEL VERSION with the specified name will be created and used in your experiment. It will use the default inputs (``${MODEL_NAME}/inidata``).

To choose the sources that you want to use, check them out in your model's submodule (git fetch + git checkout BRANCH, COMMIT or TAG).


IFS-NEMO: DVC inputs
----------------------

We also support the usage of inputs from the DVC repository. To use them, set:

.. code-block:: yaml

     MODEL:
        INPUTS: "%HPCROOTDIR%/%PROJECT.PROJECT_DESTINATION%/dvc-cache-de340"
        DVC_INPUTS_BRANCH: "dvc-inputs-tag-name"


IFS-based models: ICMCL files
--------------------------------

Different ICMCL files can be used. To use them, set:

.. code-block:: yaml

     CONFIGURATION:
                ICMCL: "name-of-the-icmcl-file"

Options are:

- ``biweekly``: ICMCL_tcoXXXX_yyyymmdd

- ``generic``: ICMCL_tcoXXXX_yyyymmdd_yyyymmdd #start and end date

- ``monthly``: ICMCL_tcoXXXX_yyyymm

- ``yearly``: ICMCL_tcoXXXX_yyyy

- ``yearly_extra``: ICMCL_tcoXXXX_yyyy_extra

How to manage the Retrials
----------------------------

When a job fails, Autosubmit can automatically resubmit it. This is recommended if you are sure that your code is fine but the HPC that you are using is unstable.
To add them, open your ``$expid/conf/minimal.yml`` and add a ``RETRIALS`` key under ``CONFIG``:

.. code-block:: yaml

     CONFIG:
         # Current version of Autosubmit.
         AUTOSUBMIT_VERSION: "4.0.87"
         # Total number of jobs in the workflow.
         TOTALJOBS: 20
         # Maximum number of jobs permitted in the waiting status.
         MAXWAITINGJOBS: 20
         RETRIALS: 5

This will be applied to all your jobs (and Wrappers).

Keep in mind that if you use this option and your job fails because of some bug, you will be wasting resources.


Data governance, FDB management
--------------------------------

There are four types of experiments: ``test``, ``pre-production``, ``research`` and ``production``. To select the type of experiment, specify ``RUN.TYPE``. This will load the corresponding subset of configurations:


.. list-table:: Types of experiment
   :widths: 25 25 25 50
   :header-rows: 1

   * - KEY
     - FDB
     - EXPVER
     - Purpose
   * - PRODUCTION
     - HPC-FDB
     - 0001
     - 5km real simulation s
   * - RESEARCH
     - HPC-FDB
     - Autosubmit expid
     - Other research experiments
   * - PRE-PRODUCTION
     - Local
     - 0001
     - 5km test simulations
   * - TEST
     - Local
     - Autosubmit expid
     - Small tests of workflow/model functionalities. Default behaviour.

In the experiments that use local FDBs, a directory corresponding to each experiment is created in the scratch of the project, under ``/experiments``. The data produced by the experiment will be stored there.
In the experiments that use HPC-FDB, the official ``FDB_HOME`` provided by ECMWF is used.


Ensembles (IFS-NEMO)
---------------------

To run an ensemble with several members:

.. code-block:: yaml

    EXPERIMENT:
        MEMBERS: "fc0 fc1 fc2"

To activate the initial conditions perturbations,

.. code-block:: yaml

    CONFIGURATION:
        OCE_INI_MEMBER_PERTURB: "true"

Scaling tests
---------------

To run a scaling test, you should configure a ``simless`` joblist (``WORKFLOW: simless``) and set ``SCALING: "True"`` in the ADDITIONAL_JOBS section of your ``main.yml``.
This will take the configuration from conf/additional_jobs/scaling.yml. You can modify this file to set the number of nodes and tasks that you want to use for the scaling test.
Inspect your experiment before launching it to check that the scaling experiment is correctly configured.

Namelist modifications (IFS-NEMO)
----------------------------------

It is possible to modify the namelists of the models (``fort.4``, ``namelist_cfg``, ``namelist_ice_cfg``). This will create a ``inipath`` directory in your experiment (both if you use DVC or normal inputs).
In that directory, all the files are symlinks to the real files. If a namelist is chosen to be modified, the symlink is replaced by the modified file.
To modify the namelists, you should add the following lines in your ``main.yml``:

.. code-block:: yaml

    NAMELIST_PATCHES:
        FORT_4: "name-of-the-path-to-the-fort.4"
        NAMELIST_CFG: "name-of-the-path-to-the-namelist_cfg"
        NAMELIST_ICE_CFG: "name-of-the-path-to-the-namelist_ice_cfg"

The patches are located in the ``conf/namelist_patches`` directory. You can create your own patches and use them in your experiment. Create a merge request in order to share your patch, that might be used by other users.


AQUA usage
----------

AQUA has been successfully integrated into the Climate DT workflow as an Additional Job, which allows the user to easily deploy and run AQUA in LUMI or MareNostrum5. In all the tasks, AQUA runs containerized.

AQUA can be used to analyze your simulation. It is configured to run as an additional job, so to enable it, you need to have:

.. code-block:: yaml

    CONFIGURATION:
        ADDITIONAL_JOBS:
            AQUA: "True"


It can be:

- Coupled with a model-only or end-to-end workflow, where it monitors simulations in real time.
- Executed in `simless` mode, analyzing completed experiments offline. You need to specify the ``RUN.TYPE`` and the parameters under ``REQUEST``.

.. warning::

    In order to successfully run AQUA you need the following submodules:
        - ``catalog``: to create the catalog entry for your experiment in the Remote Setup.
        - ``data-portfolio``: to get the DQC profiles (DQC, TRANFER, WIPE tasks).

This will load the configuration under ``conf/additional_jobs/aqua-True.yaml``.

- REMOTE SETUP: AQUA is installed within the experiment directory. An .aqua folder is created, storing all necessary configuration files. A catalog entry (YAML-based metadata file) is generated when AQUA runs alongside a model. This catalog entry contains essential information, including variable names, grid definitions, FDB home and keys, and dates. It also points to the `fdb_info_file`, a YAML file that is updated with the data of each simulation available in the FDB and the Data Bridge. The catalog generator takes the information from the ``templates/AQUA/config_catgen.yaml`` that is parsed by Autosubmit using the information from the experiment.
- LRA GENERATOR: Converts high-resolution outputs into a low-resolution archive (LRA). Allows users to configure specific variables for processing. It is configured by the YAML file ``templates/AQUA/only_lra.yaml``, that is parsed by Autosubmit as additional script in the LRA task.
- AQUA ANALYSIS: Runs the AQUA analysis. The analysis is based on the LRA generated in the previous step. Executes selected diagnostic routines and generates analytical plots using the AQUA analysis wrapper.
- AQUA PUSH: Uploads results, including plots and catalog entries, to the designated repository or visualization platform. Runs on the Autosubmit Virtual Machine (VM).

The frequency of those jobs can be tuned with the ``FREQUENCY`` parameter of each job. The variables used in the LRA can also be tuned with the `VARS_*` parameters.

The output of the LRA and the AQUA analysis will be stored in the experiment folder, in a directory named `out`.


Run without IO (IFS-NEMO):
--------------------------

To disable the flags for IO, add the following lines in your `main.yml`:

.. code-block:: yaml

    CONFIGURATION:
        IO_ON: "False"

Set application versions:
-------------------------

The default version of the applications can be changed by using the following keys:

.. code-block:: yaml

    SOME_APP:
      VERSION: "x.x.x"

The default values can be found under `conf/applications/container_versions.yml`.

Set applications request details:
---------------------------------

The area, resolution and interpolation method of the data from the streaming (the input data to the applications) are defined by:

.. code-block:: yaml

    SOME_APP:
        GRID: g #"0.1/0.1"
        AREA: a #"70/-12/48/31"
        METHOD: m #nn/con

`Note: For more info check https://earth.bsc.es/gitlab/digital-twins/de_340-2/gsv_interface/-/blob/main/docs/source/gsv_request_syntax.rst `

The default values can be found under `conf/applications/default_gsv_request.yml`.

The defaults can be overriden in `main.yml` as well.

Set additional application-specific keys:
-----------------------------------------

There are a set of files that are meant to contain all the keys that are application-specific. They can be found in `conf/applications/$some_app.yml`.

For `data` workflows, here is where the specifications of the data request are detailed (`conf/applications/data.yml`).

Execute the workflow
====================

Now you can **create** the workflow:

.. code-block:: bash

    autosubmit create <expid>



And **run** it:

.. code-block:: bash

    autosubmit run <expid>

If you want to update the git repository, **refresh** your experiment (equivalent to a git pull):

.. warning::
    BE CAREFUL! This command will overwrite any changes in the local project folder.
    Note that this is doing the same thing that the ``autosubmit create`` did in a previous
    step, but ``autosubmit create`` only refreshes the git repository the first time it is

.. code-block:: bash

    autosubmit refresh <expid>

Then you need autosubmit to **create** the workflow again:

.. code-block:: bash

    autosubmit create <expid> -v -np

This resets the status of all the jobs, so if you do not want to run everything from
the beginning again, you can **set the status** of tasks, for example:

.. code-block:: bash

    autosubmit setstatus a002 -fl "a002_LOCAL_SETUP a002_SYNCHRONIZE a002_REMOTE_SETUP" -t COMPLETED -s

``-fl`` is for filter, so you filter them by job name now, ``-t`` is for target status(?)
so, we set them to ``COMPLETED`` here. ``-s`` is for save, which is needed to save the
results to disk.

You can add a ``-np`` for “no plot” to most of the commands to not have the error with
missing ``xdg-open``, etc.
