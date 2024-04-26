Create your own experiment
===========================

Create an Autosubmit experiment using minimal configurations.
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
    you MUST change `<TYPE_YOUR_PLATFORM_HERE>` below with your platform, and add a description.
    For example: lumi, marenostrum4, juwels, levante...
    Check the available platforms at `/appl/AS/DefaultConfigs/platforms.yml`
    or `~/platforms.yml` if you created this file in your home directory.


You will receive the following message: `Experiment <expid> created`, where `<expid>`
is the identifier of your experiment. A directory will be created for your experiment
at: `/appl/AS/AUTOSUBMIT_DATA/<expid>`.

The command `autosubmit expid` above will create a `minimal.yml` file for you.
Modify this file (e.g. `/appl/AS/AUTOSUBMIT_DATA/<expid>/conf/minimal.yml`) as needed.

In the `GIT` section in the `minimal.yml`, you can use `PROJECT_SUBMODULES` to set
the Git submodules for the models you want to run. **MANDATORY SUBMODULES ARE: "gsv_interface one_pass"**
Or leave it empty to select all the submodules. Autosubmit will clone
them when you run `autosubmit create` (first run) or `autosubmit refresh`.

.. warning::
    you need to have access to the corresponding model sources
    repository and your ssh keys must be uploaded there.

In `/appl/AS/AUTOSUBMIT_DATA/<expid>/conf/`, create a `main.yml` file (e.g.: `vim main.yml`).
    Here you can select the workflow you will run by setting:

.. code-block:: yaml

    RUN:
      WORKFLOW: end-to-end #model or apps

Examples for each workflow type in ``main_example_endtoend.yml``, ``main_example_model.yml``,
or ``main_example_apps.yml``. Information about what each key does can be found in the `Available keys for main` section.

.. code-block:: yaml

    RUN:
        WORKFLOW: end-to-end
        ENVIRONMENT: cray
        CLEAN_RUN: true
        PROCESSOR_UNIT: gpu
        # Frequency of the monitoring in seconds
        MEMORY_FREQUENCY: 30

    MODEL:
        NAME: ifs-nemo
        SIMULATION: test-ifs-nemo
        GRID_ATM: tco79l137
        GRID_OCE: eORCA1_Z75
        VERSION: DE_CY48R1.0_climateDT_20231214

    APP:
        NAMES: mhm, wildfires_fwi, aqua
        OUTPATH: "/scratch/project_465000454/tmp/%DEFAULT.EXPID%/"

    JOBS:
        SIM:
            WALLCLOCK: "00:10"
            NODES: 4

    EXPERIMENT:
        DATELIST: 19900101 #Startdate
        MEMBERS: fc0
        CHUNKSIZEUNIT: day
        CHUNKSIZE: 3
        NUMCHUNKS: 1
        CALENDAR: standard

    CONFIGURATION:
        RAPS_EXPERIMENT: "hist"
        ADDITIONAL_JOBS:
            TRANSFER: "False"
            BACKUP: "True"
            MEMORY_CHECKER: "False"
            DQC: "False"

    WRAPPERS:
        WRAPPER:
            TYPE: "vertical"
            JOBS_IN_WRAPPER: SIM


Customize your experiment
=========================


How to switch between configurations: `main.yml`
-------------------------------------------------

`main.yml` is the main file that users will modify. The switches are located there, and depending on those keys, Autosubmit will load some files or others. In this file, one can also define any customized variable, because it will overwrite the ones loaded in the files. For example, if you need to frequently change the start date or the length of your simulation, you can uncomment these lines of `main.yml`, and fill them in, following the specified format:

.. code-block:: yaml

     # Uncomment these keys if you want to run the model for specific dates (not the default setting in SIMULATION)
     # EXPERIMENT:
     #    DATELIST: yyyymmddhh
     #    CHUNKSIZEUNIT: day/month/year
     #    CHUNKSIZE: nn
     #    NUMCHUNKS: nn

If you need to change the wallclock of your job, add the following lines into your `main.yml`:

.. code-block:: yaml

     JOBS:
         SIM:
             WALLCLOCK: "00:30" #this is a 30 min wallclock.

Another case would be if you are frequently changing the number of nodes that you are using. We have defaults, that you can find in `/proj/git_project/conf/model/${model_name}`, but they can be overwritten in `main.yml`, adding the following lines (the ones that you consider):

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


How to add wrappers into the workflow:
--------------------------------------

The purpose of the wrappers is to submit multiple jobs in a single SLURM task. This increases the wallclock of the submitted task, but once this job enters, the jobs in the wrapper will run one after the other skipping the queueing time. For this workflow, you probably want to wrap multiple `SIM` jobs into one task.
To configure them, add the following lines in your `main.yml`:

.. code-block:: yaml

     WRAPPERS:
         WRAPPER_0:
             TYPE: "vertical"
             JOBS_IN_WRAPPER: "SIM"

     PLATFORMS:
            LUMI:
                 PARTITION: "small/standard" #choose one
                 MAX_WALLCLOCK: "72:00/48:00" #this will be the wallclock of the wrapper

Autosubmit will fit as many `SIM` jobs as it can, by dividing the defined `MAX_WALLCLOCK` between the `WALLCLOCK` of your job. Once this is saved, you can preview the graph with: 

`autosubmit inspect <expid> -cw -f # Visualize wrapper cmds`


How to run the additional jobs:
---------------------------------------------------------------------------------------------

By default, the additional jobs are disabled. You can enable them adding this in your `main.yml` and setting the ones that you want to run to "True".

.. code-block:: yaml

    CONFIGURATION:
        ADDITIONAL_JOBS:
            TRANSFER: "False"
            BACKUP: "True"
            MEMORY_CHECKER: "False"
            DQC: "False"
            WIPE: "True"


How to change default start dates, chunk size, and the number of chunks (Recommended option):
---------------------------------------------------------------------------------------------

If you will be frequently using a determined set of values and that set does not exist yet, you can create your own configuration. To do so, go into `/proj/git_project/conf/simulation` and copy one of the existing files. Then, modify it. You can use those configurations by placing the name of the file that you have just created in `main.yml`:

.. code-block:: yaml

     RUN:
         SIMULATION: file_name

In the case of ifs-nemo, you can also modify your ICMCL file there. If you want to make those configurations available for everyone, you can push your new file to our GitLab. 


How to change grid-specific variables (number of nodes, processors...):
If you will be frequently using a determined set of values and that set does not exist yet, you can create your own configuration. To do so, go into `/proj/git_project/conf/models/${model_name}` and copy one of the existing files. Then, modify it. You can use those configurations by placing the name of the file that you have just created in `main.yml`:

.. code-block:: yaml

     RUN:
         GRID_ATM: file_name

In the case of ifs-nemo, you can also modify the number of IO nodes there. If you want to make those configurations available for everyone, you can push your new file to our GitLab. 


How to use your own input data and model installation:
------------------------------------------------------


We are willing to store model versions and inputs in a uniform way. In every platform, we have a defined path where we will store inputs and model versions (or have symbolic links pointing to the path where they are actually stored).
- LUMI: `/projappl/project_465000454/models/${MODEL_NAME}`
- MareNostrum4: `/gpfs/projects/dese28/models/${MODEL_NAME}`

Under these directories, you can find:
- Different folders, containing the model version. The path to any installation should follow: `${MODEL_VERSION}/make/${PLATFORM}-${ENVIRONMENT}`.
- `${MODEL_VERSION}/inidata:` points to the input directory.

Then, you should specify the `MODEL_VERSION` and the `ENVIRONMENT` in `main.yml` 

.. code-block:: yaml

    MODEL:
        MODEL_VERSION: "Name-of-the-model-version"


If the version that you are specifying doesn't exist, or is not correctly configured, the remote setup will fail.

If you need a new one, you should specify the MODEL_VERSION in the same way, but also:

.. code-block:: yaml

    CONFIGURATION:
        INSTALL: "shared"


A MODEL VERSION with the specified name will be created and used in your experiment. It will use the default inputs (`${MODEL_NAME}/inidata`). 

To choose the sources that you want to use, check them out in your model's submodule (git fetch + git checkout BRANCH, COMMIT or TAG).


IFS-NEMO only:

We also support the usage of inputs from the DVC repository. To use them, set:

.. code-block:: yaml

     CONFIGURATION:
                INPUTS: "dvc-inputs-tag-name"


How to manage the Retrials:
----------------------------

When a job fails, Autosubmit can automatically resubmit it. This is recommended if you are sure that your code is fine but the HPC that you are using is unstable. 
To add them, open your `$expid/conf/minimal.yml` and add a `RETRIALS` key under `CONFIG`:

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


Data governance, FDB management:
--------------------------------

There are four types of experiments: TEST, PRE-PRODUCTION, RESEARCH and PRODUCTION. The keys 


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


Ensembles (IFS-NEMO):
---------------------

To run an ensemble with several members:

.. code-block:: yaml

    EXPERIMENT:
        MEMBERS: "fc0 fc1 fc2"

To activate the initial conditions perturbations, 

.. code-block:: yaml

    CONFIGURATION:
        ATM_INI_MEMBER_PERTURB: "true"


Execute the workflow
====================

Now you can **create** the workflow:

.. code-block:: bash

    autosubmit create <expid>


.. note::
    Create the jobslist for your experiment (applies for end-to-end and apps)

    In order to select the number of the applications that you want to run, you need to create the corresponding structure of the workflow, by using a simple python script. In the VM:

    .. code-block:: bash

        cd $expid/proj/git_project/conf/

        python create_jobs_from_mother_request.py

And **run** it:

.. code-block:: bash

    autosubmit run <expid>

If you want to update the git repository, **refresh** your experiment (equivalent to a git pull):

.. warning::
    BE CAREFUL! This command will overwrite any changes in the local project folder.
    Note that this is doing the same thing that the `autosubmit create` did in a previous
    step, but `autosubmit create` only refreshes the git repository the first time it is

.. code-block:: bash

    autosubmit refresh <expid>

Then you need autosubmit to **create** the workflow again:

.. code-block:: bash

    autosubmit create <expid> -v -np

This resets the status of all the jobs, so if you do not want to run everything from
the beginning again, you can **set the status** of tasks, for example:

.. code-block:: bash

    autosubmit setstatus a002 -fl "a002_LOCAL_SETUP a002_SYNCHRONIZE a002_REMOTE_SETUP" -t COMPLETED -s

`-fl` is for filter, so you filter them by job name now, `-t` is for target status(?)
so, we set them to `COMPLETED` here. `-s` is for save, which is needed to save the
results to disk.

You can add a `-np` for “no plot” to most of the commands to not have the error with
missing `xdg-open`, etc.