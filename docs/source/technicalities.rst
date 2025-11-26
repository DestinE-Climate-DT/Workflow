=============================
Technicalities
=============================

Directories created with the workflow (IFS-NEMO)
------------------------------------------------

The experiment directory in the HPC is located in the scratch of the user. During the steps of the workflow, a set of directories is created:

- ``%PROJDIR%`` (default: git_project): contains the workflow project
- ``rundir``: where the simulation runs. RAPS creates a directory for each run attempt.
- ``restarts``: restart files of the model, separated by each chunk.
- ``inipath``: symlinks to the initial data used to execute the model, one per member. If the namelists or the initial conditions are modified, it is reflected in this directory.
- ``LOGS_{EXPID}``: logs of the experiment.


Restarts (IFS-NEMO)
-------------------
After each SIM chunk, the resulting restart files are automatically relocated to separate subdirectories, all inside a directory identified by the chunk number. The restart directory is also automatically defined as a symbolic link to the current chunk’s restart directory, allowing users to rerun any particular chunk at their convenience.
In a regular execution, the directory 1/ will be empty (initializing from initial conditions), the restart 2/ contain the restart files necessary to start the second chunk, and so on.

In case of a failure:
- If the failure is before writing the restarts, the retrial will take the restart files to initialize the chunk again.
- If the failure is during the writing of the restart files, the worfklow will detect that and use the not corrupted set of restart files.

To-do: explain restart mechanism for ICON and IFS-FESOM, and also for the applications.

Data governance
---------------

The data in the FDB is encoded with a set of keys. This is the current 1st layer of the schema used in Climate-DT, that is used to encode the data in the FDB. The keys are:

``class=d1, dataset=climate-dt, activity, experiment, generation, model, realization, expver, stream=clte/wave, date``

Most of them are governed by the workflow, under ``REQUEST`` keys:

- CLASS is currently fixed to ``d1``.
- DATASET is currently fixed to ``climate-dt``.
- EXPERIMENT and ACTIVITY are set by RAPS in IFS-NEMO and IFS-FESOM. In the SIMULATION config files, we set the key %CONFIGURATION.RAPS_EXPERIMENT% to specify which experiment we run. RAPS associates the corresponding ACTIVITY. To read the data, we set the keys REQUEST.EXPERIMENT and REQUEST.ACTIVITY. In ICON, the values of REQUEST.EXPERIMENT and REQUEST.ACTIVITY are directly used by the model.
- REALIZATION is a number, starting from 1. It is set in the workflow according to the member number.
- GENERATION is a number (1 or 2 currently) that marks in which operational cycle the data was produced.
- MODEL is set in the ``main.yml``, where we set the key ``%MODEL.NAME%`` to specify which model we run.
- EXPVER is ``0001`` (if ``RUN.TYPE`` is ``production```` or ``pre-production``) or the EXPID of the experiment that produced the data (if ``RUN.TYPE`` is ``research`` or ``test````).
- STREAM is set by RAPS in IFS-NEMO and IFS-FESOM.
- DATE is the date of the data.

The keys ``REQUEST.EXPERIMENT``, ``REQUEST.ACTIVITY``, ``REQUEST.GENERATION``, ``REQUEST.MODEL``, ``REQUEST.REALIZATION`` and ``REQUEST.RESOLUTION`` are used to read the data from the FDB.

Data streaming
--------------

The data streaming is a fundamental piece to run the ClimateDT successfully. Internally the Data Notifier (DN) and the One Pass Algorithms (OPA) run at daily simulation steps, that is, every time the model produces a day of data an instance of the OPA is triggered by the DN. Applications are launched also daily by default, but the workflow allows the possibility to run them at other frequencies (always equal or lower than the OPA, e.g. monthly) always that they can run at such frequencies (e.g. there are no memory constraints).


Update a component version (development)
----------------------------------------

Component is integrated as submodule
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If the component is integrated as a submodule, the developer of the component has to do the following steps:

Note: this includes ``ifs-nemo``, ``catalog``, ``dvc-cache-de340``, ``data-portfolio`` and ``nemo``.

- Clone this repository. Check out the ``update-components`` branch.`
- Run ``git submodule update --init ${COMPONENT}``
- Go to the component directory and checkout the desired commit (``cd ${COMPONENT} && git fetch && git checkout ${COMMIT}``).
- Go back to the root directory and commit the changes (``git add ${COMPONENT} && git commit -m "Update ${COMPONENT} to ${COMMIT}"``). Push the changes to the remote repository.

Component is integrated as a container
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If the component is integrated as a container, the developer of the component has to do the following steps:

- Clone this repository. Check out the ``update-components`` branch.
- Upload the container to the containers folder.
- Update the container version in the configuration file where the ``VERSION`` of the component is defined (conf/applications/container_version.yml in app cases).
- Commit the changes and push them to the remote repository.
