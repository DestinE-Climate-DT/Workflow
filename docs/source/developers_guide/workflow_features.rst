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

.. note::
   IFS-FESOM does not use DVC. Its input data and model binaries are pre-installed on the HPC platforms.

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

Ensembles (IFS-FESOM)
----------------------

IFS-FESOM also supports ensemble runs with multiple members. To enable FESOM ocean perturbation, set ``FESOM_PERTURB`` to ``"true"``:

.. code-block:: yaml

    CONFIGURATION:
        FESOM_PERTURB: "true"
        FESOM_PERTURBATION_SEED_BASE: "50000"

The perturbation seed for each member is computed as ``FESOM_PERTURBATION_SEED_BASE + MEMBER_NUMBER`` (e.g. fc0 → 50001, fc1 → 50002). This passes ``--fesom-perturb --fesom-perturbation-seed <seed>`` to RAPS.

Scaling tests
---------------

To run a scaling test, you should configure a ``simless`` joblist (``WORKFLOW: simless``) and set ``SCALING: "True"`` in the ADDITIONAL_JOBS section of your ``main.yml``.
This will take the configuration from conf/additional_jobs/scaling.yml. You can modify this file to set the number of nodes and tasks that you want to use for the scaling test.
Inspect your experiment before launching it to check that the scaling experiment is correctly configured.

Namelist modifications (IFS-NEMO)
----------------------------------

It is possible to modify the namelists of the models (``fort.4``, ``namelist_cfg``, ``namelist_ice_cfg``). This will create a ``inipath`` directory in your experiment (both if you use DVC or normal inputs).

.. note::
   For IFS-FESOM, namelist modifications are handled through the RAPS ``NAMELIST_FLAGS`` (``--inproot-namelists``). Custom namelists can be placed in the input root directory and will be picked up by RAPS during the simulation.
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

- AQUA SETUP: AQUA is installed within the experiment directory. An .aqua folder is created, storing all necessary configuration files. A catalog entry (YAML-based metadata file) is generated when AQUA runs alongside a model. This catalog entry contains essential information, including variable names, grid definitions, FDB home and keys, and dates. It also points to the `fdb_info_file`, a YAML file that is updated with the data of each simulation available in the FDB and the Data Bridge. The catalog generator takes the information from the ``templates/AQUA/config_catgen.yaml`` that is parsed by Autosubmit using the information from the experiment.
- LRA GENERATOR: Converts high-resolution outputs into a low-resolution archive (LRA). Allows users to configure specific variables for processing. It is configured by the YAML file ``templates/AQUA/only_lra.yaml``, that is parsed by Autosubmit as additional script in the LRA task.
- AQUA ANALYSIS: Runs the AQUA analysis. The analysis is based on the LRA generated in the previous step. Executes selected diagnostic routines and generates analytical plots using the AQUA analysis wrapper.
- AQUA PUSH: Uploads results, including plots and catalog entries, to the designated repository or visualization platform. Runs on the Autosubmit Virtual Machine (VM).

The frequency of those jobs can be tuned with the ``FREQUENCY`` parameter of each job. The variables used in the LRA can also be tuned with the `VARS_*` parameters.

The output of the LRA and the AQUA analysis will be stored in the experiment folder, in a directory named `out`.

LUMI-O credentials for AQUA-push
*********************************

More information may be found here: https://docs.lumi-supercomputer.eu/storage/lumio/auth-lumidata-eu/

1) In the VM, the AWS credentials have to be stored in the \~/.aws/credentials file
2) Go to https://auth.lumidata.eu/
3) Log in
4) Open the ....454 project.
5) Set the max duration and generate key.
6) Store them in this format (\~/.aws/credentials):

```
[development]
aws_access_key_id = XXXXXXXXXXXXXX
aws_secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXXX
```

If you have access to the operational project,

7) Repeat steps 5 and 6 for the operational project, and store them in this format:

```
[operational]
aws_access_key_id = XXXXXXXXXXXXXX
aws_secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXXX
```

GitHub credentials for AQUA catalog
************************************

In the VM, run ssh-add -L to get your public ssh-key. In your GitHub account, Settings > SSH and GPG keys > register your public ssh-key in New ssh key


AQUA Grid Build
***************

The ``AQUA_GRID_BUILD`` job builds native grid definition files from simulation output so that AQUA can read and process data at its original resolution before regridding. It runs once after the first simulation chunk and produces grid files consumed by ``LRA_GENERATOR`` and other AQUA tools.

To enable it, add the following to your ``main.yml``:

.. code-block:: yaml

    CONFIGURATION:
        ADDITIONAL_JOBS:
            AQUA_GRID_BUILD: "True"

This loads the configuration from ``conf/additional_jobs/aqua_grid_build-True.yml``.

**How it works:**

1. ``AQUA_GRID_BUILD`` depends on ``AQUA_SETUP`` and the first ``SIM`` chunk.
2. It extracts grid structures from simulation output using ``aqua grids build`` inside the AQUA container.
3. Grid files are written to a dedicated directory (``GRID_OUTDIR``) with component subdirectories (``FESOM/``, ``NEMO/``, ``HealPix/``).
4. Grid registry files (e.g., ``fesom.yaml``, ``nemo.yaml``) are updated so AQUA tools can discover the grids.
5. When enabled, ``LRA_GENERATOR`` automatically depends on ``AQUA_GRID_BUILD``.

**Catalog configuration (AQUA_SETUP):**

When ``AQUA_GRID_BUILD`` is enabled, the ``AQUA_SETUP`` step automatically reconfigures the AQUA catalog
to use experiment-local grid paths instead of the system defaults. This is done by
``runscripts/aqua/update_aqua_config.py``, a standalone Python script called from inside the
AQUA Singularity container during setup. It performs two updates:

- **machine.yaml**: Redirects ``grids``, ``weights``, and ``areas`` paths for the active platform
  to the experiment-local ``aqua-data/`` directory.
- **matching_grids.yaml**: Sets the ``atm_grid`` and ``ocean_grid`` entries for the model and
  DQC profile to match the actual experiment resolution.

The script accepts two subcommands (``update-paths`` and ``update-grids``) with named arguments.
See ``python3 runscripts/aqua/update_aqua_config.py --help`` for details.

**Key configuration parameters:**

- ``AQUA.GRID_OCE``: Ocean grid name (e.g., ``CORE2``, ``DARS2``, ``NG5``, ``eORCA1``, ``eORCA12``). For IFS-FESOM, this is inherited from ``MODEL.GRID_OCE``. For IFS-NEMO, it must be set explicitly because the AQUA grid name differs from MODEL (e.g., ``eORCA12`` vs ``eORCA12_Z75``).
- ``AQUA.GRID_VERSION``: Grid version number. Set per model in the base config (``4`` for IFS-FESOM, ``3`` for IFS-NEMO).
- ``AQUA_GRID_BUILD.SKIP_IF_AVAILABLE``: Skip building if grid files already exist (default: ``True``).
- ``AQUA_GRID_BUILD.REBUILD``: Force rebuild even if grids exist (default: ``False``).
- ``AQUA_GRID_BUILD.VERIFY_GRIDS``: Verify grid files with CDO after building (default: ``True``).
- ``AQUA_GRID_BUILD.LOGLEVEL``: Log verbosity (default: ``INFO``).

.. note::

    HEALPix atmosphere grids are registry-only — they are defined by mathematical properties and do not produce physical ``.nc`` files. The job handles this automatically.


Run without IO (IFS-NEMO):
--------------------------

To disable the flags for IO, add the following lines in your `main.yml`:

.. code-block:: yaml

    CONFIGURATION:
        IO_ON: "False"

.. note::
   Running without IO is not supported for IFS-FESOM. Both IFS and FESOM I/O servers are required (setting IO tasks to zero will cause an error).


Wipe: data cleanup from the HPC-FDB
-------------------------------------

The WIPE job removes data from the HPC-FDB after it has been successfully transferred to the Data Bridge, freeing up storage space. It is split into two coordinated jobs: ``WIPE_CHECK`` (validation) and ``WIPE`` (deletion).

The implementation consists of:

- ``templates/wipe-check.sh``: Iterates over the DQC profiles and verifies that the expected number of messages for each profile exists in the Data Bridge FDB. Uses ``fdb-list`` to count messages and compares against expected counts using **strict equality** — any difference causes an immediate failure. Monthly profiles (filename contains ``monthly``) are skipped unless the chunk contains the first day of a month. The FDB list request uses ``SECOND_TO_LAST_DATE`` as the end date (the chunk's last day is excluded). Generates flat request files under ``wipe_requests/<REALIZATION>/``.
- ``templates/wipe.sh``: Executes ``fdb-wipe`` to delete data from the HPC-FDB. Sets ``METKIT_PARAM_RAW=1`` before invoking the container to prevent METKIT from resolving parameter names during the wipe. Handles CLTE (climate time series) and CLMN (monthly data) separately, since monthly data is only wiped when the chunk contains the first day of a month. When ``WIPE_DOIT=False`` (dry-run), the job deliberately exits with a non-zero code after running ``fdb-wipe`` without ``--doit``, causing the job to appear as FAILED in the Autosubmit monitor and skipping the FDB info update. After a real wipe (``WIPE_DOIT=True``), the FDB info file is updated.
- ``lib/common/utils/wipe_utils.sh``: Contains the shared utility functions:

  - ``check_messages_wipe(profile_file)``: Generates a flat request from the profile using ``SECOND_TO_LAST_DATE`` as the end date (the chunk's last day is excluded), runs ``fdb-list`` on the Data Bridge, and compares listed vs. expected message counts using **strict equality**. Any mismatch causes an immediate failure.
  - ``exec_wipe(WIPE_DOIT, GENERAL_REQUEST, FLAT_REQ_NAME, MINIMUM_KEYS, WIPE_UNSAFE)``: Builds and runs the ``fdb-wipe`` command. Supports dry-run mode (``WIPE_DOIT=False``) and optional ``--unsafe-wipe-all`` flag.
  - ``check_expver_match(modify_metadata_transfer, modify_metadata_fields, bridge_expver, expver)``: Validates that the experiment version used in the TRANSFER job matches the one expected by the WIPE job. This prevents accidental deletion of data that was transferred with different metadata.

Both jobs run inside a Singularity container (GSV image) and use the same general request YAML files (``general_request_clte.yaml``, ``general_request_clmn.yaml``) as the TRANSFER job.

The minimum keys used for the ``fdb-wipe`` command differ by data type:

- CLTE: ``class,dataset,experiment,activity,expver,model,generation,realization,type,stream,date``
- CLMN: ``class,dataset,experiment,activity,expver,model,generation,realization,type,stream,year,month``

Both ``WIPE_CHECK`` and ``WIPE`` are configured with ``RETRIALS: 0`` — they are not retried on failure, to avoid accidental data loss from partial retries.
