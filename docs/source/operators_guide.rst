=============================
Operators guide
=============================

How to switch projects
-----------------------

In order to change the project used by the workflow, the operator has to add, in the ``conf/main.yml`` file the following lines:
The REMOTE_SETUP job runs on the login node therefore the project also has to be specified for that.

.. code-block:: yaml

  PLATFORMS:
    # LUMI as example, but it can be any platform
    LUMI:
      PROJECT: <PROJECT>

    LUMI-LOGIN:
      PROJECT: <PROJECT>
 
How to use a robot account
--------------------------

To switch the account used for the simulation one can change the user for the corresponding platform in ``conf/main.yml``:

.. code-block:: yaml

  PLATFORMS:
    # LUMI as example, but it can be any platform
    LUMI:
      USER: <USER>

If in ``conf/platforms.yml`` the following is defined ``USER: <to-be-overloaded-in-user-conf>`` then the user may be overloaded if a user is given in ``~/platforms.yml``.

How to set the paths in the E/O-suite
-----------------------------------------
The default paths used in the development projects are not the same as in the operational project.
Therefore, one has to set the desired paths to the input data and the software from the specific suite (as example E-25.0), in the ``conf/main.yml``:

.. code-block:: yaml

  MODEL:
    VERSION: 'DE_CY48R1.0_climateDT_20240723'
    ROOT_PATH: "%CONFIGURATION.HPC_PROJECT_DIR%/E-25.0/models/%MODEL.NAME%" # Where to find the models
    PATH: "%MODEL.ROOT_PATH%/%MODEL.VERSION%/" # Where to find the specific model version
    INPUTS: "%MODEL.ROOT_PATH%/%MODEL.VERSION%/inidata" # Where to find the input data

  CONFIGURATION:
    CONTAINER_DIR: "%CONFIGURATION.HPC_PROJECT_DIR%/E-25.0/containers"

For IFS-FESOM the MIR_CACHE_PATH must also be updated. This can be done in ``conf/main.yml``

.. code-block:: yaml

  MODEL:
    NAME: ifs-fesom
    RAPS_MIR_CACHE_PATH: "/scratch/<project>/path/to/multio_mir_cache"
    RAPS_MIR_FESOM_CACHE_PATH: "/scratch/<project>/path/to/multio_mir_cache/fesom"

How to set container versions
-----------------------------
The versions of the containers need to be configured in the workflow to ensure the correct version is used.
For the applications and OPA the versions can be set in ``conf/applications/container_versions.yml``.
For the GSV and AQUA it can be set in the ``main.yml``.

.. code-block:: yaml

  GSV:
    VERSION: 2.9.0

How to set resolutions of applications
--------------------------------------
The applications use input data from the models that can be interpolated to different resolutions. Therefore, one must set the desired resolution for each application.
This can be done in ``/conf/applications/resolutions.yml"``. The following encoding is used:

* 100km = 1.0
* 10km = 0.1
* 5km = 0.05


A chunk runs successfully, but needs to be rerun (IFS-FESOM use case)
---------------------------------------------------------------------

Use case example:

Chunk 450 has not run successfully but it was manually set as COMPLETED. It needed to be rerun together with chunk 451.

These were the steps involved in restarting the 450 chunk:

#. Check that the time reflected in ``<expid>/restarts/fesom_raw_restart/fesom.clock`` matches the latest time of the previous chunk. If those dates match then you can move on to step 2. If they don't, backup the fesom_raw_restart and find the ``fesom_raw_restart_*`` in ``<expid>/restarts`` that contains a ``fesom.clock`` that matches the latest time of the previous chunk and copy it to fesom_raw_restart. In our example, the final time of the previous chunk to the one we wanted to run was 161640 hours (from the rundir name ``h161640.N284.T1920xt14xh1+ioT320xt14xh0.nextgems_6h.i32r1w32.a1oo_...``) and we wanted to rerun the chunk of final time 162000. Our simulation started on 1st of January 2020, so if we add 161640/24 days to it in a calendar application (e.g. `Timeanddate website <https://www.timeanddate.com/date/dateadded.html?d1=1&m1=1&y1=2038&type=add&ay=&am=&aw=&ad=161&rec=>`_) we get 10 June 2038 which was in agreement with the content of the fesom.clock (day 160 2038, which is indeed 10 June 2038).
#. Check the ``<expid>/restarts/rcf`` file and make sure that the CTIME matches the final time of the previous chunk. The format of CTIME is such as 0067350000 where the 4 digits on the right are maybe for hours and seconds, and the rest of the digits (006735) indicate the days since the beginning of the simulation. This file is used by IFS to understand which restarts to load, so as long as this date is correct the correct restarts should be loaded. If it is not correct, find one of the rcf_* backup files in <expid>/restarts that match the expected simulated time and rename it to rcf.
#. In the Autosubmit VM manually remove all the COMPLETED files in ``/appl/AS/AUTOSUBMIT_DATA/<expid>/tmp`` that have a chunk number >= than the chunk you want to resume the simulation from. In our case, we wanted to rerun chunk 450, so every file matching ``a1oo_20200101_450_*_COMPLETED``, ``a1oo_20200101_451_*_COMPLETED``, ``a1oo_20200101_452_*_COMPLETED`` ... was removed. This "resets" Autosubmit to the chunk where we want to resume. The reccomended way to do this is using the ``setstatus`` command.
#. Run ``autosubmit create a1oo``
#. Run ``autosubmit recovery a1oo -s --all`` (`Autosubmit docs <https://autosubmit.readthedocs.io/en/master/userguide/modifying_workflow/index.html#how-to-recover-an-experiment>`_)
#. Run ``autosubmit run a1oo`` to resume the run starting from the desired chunk.
