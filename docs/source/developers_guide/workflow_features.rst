How to use your own input data and model installation
------------------------------------------------------


We are willing to store model versions and inputs in a uniform way. In every platform, we have a defined path where we will store inputs and model versions.

- LUMI: ``/projappl/project_465000454/models/${MODEL_NAME}``
- MareNostrum5: ``/gpfs/projects/ehpc01/models/${MODEL_NAME}``

By default, the workflow points to the latest release of each model. If you want to use a different version, or your own installation, you should follow the instructions below.

Under these directories, you can find:
- Different folders, containing the model version. The path to any installation should follow: ``${MODEL_VERSION}/make/${PLATFORM}-${ENVIRONMENT}``.
- ``${MODEL_VERSION}/inidata:`` points to the input directory.

To use your own installation,

.. code-block:: yaml

    MODEL:
        PATH: "Path-to-your-model-installation"


If the version that you are specifying doesn't exist, or is not correctly configured, the remote setup will fail.

If you need a new one, you should specify the new MODEL.PATH, and also,

.. code-block:: yaml

    MODEL:
      COMPILE: "true"


A MODEL VERSION with the specified name will be created and used in your experiment. It will use the default inputs (``${MODEL_NAME}/inidata``).

To choose the sources that you want to use, check them out in your model's submodule (git fetch + git checkout BRANCH, COMMIT or TAG).


IFS-NEMO: DVC inputs
----------------------

We also support the usage of inputs from the DVC repository. By default, the last release, to which the submodule points to, will be used.

To use them, set:

.. code-block:: yaml

    MODEL:
      INPUTS: "%HPCROOTDIR%/%PROJECT.PROJECT_DESTINATION%/dvc-cache-de340"

If you want to use a different branch, additionally, set:

.. code-block:: yaml

    MODEL:
      USE_FIXED_DVC_COMMIT: "false"
      DVC_INPUTS_BRANCH: "name-of-the-branch"


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

The patches are located in the ``conf/namelist_patches`` directory. You can create your own patches and use them in your experiment. Create a merge request in order to share your patch with other users.


AQUA usage
----------

AQUA has been successfully integrated into the Climate DT workflow as an Additional Job, which allows the user to easily deploy and run AQUA in LUMI or MareNostrum5. In all the tasks, AQUA runs containerized.

AQUA can be used to analyze your simulation. To enable it, you need to have:

.. code-block:: yaml

    CONFIGURATION:
        ADDITIONAL_JOBS:
            AQUA: "True"


It can be:

- Coupled with a model-only or end-to-end workflow, where it monitors simulations in real time.
- Executed in `simless` mode, analyzing completed experiments offline. You need to specify the ``RUN.TYPE`` and the parameters under ``REQUEST``: MODEL, EXPERIMENT, GENERATION, REALIZATION and ACTIVITY.

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
