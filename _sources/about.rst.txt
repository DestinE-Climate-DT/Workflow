About the project
==================

This repository contains the DE_340 workflow. It is used for production, development and testing in conjunction with `Autosubmit4 <https://earth.bsc.es/gitlab/es/autosubmit>`_. The implemented workflow tasks keep a model-agnostic interface and contain the merged sub-workflows for ICON, IFS-FESOM, and IFS-NEMO. Currently, LUMI is supported for IFS-NEMO and ICON to perform simulations. MareNostrum5 is supported for IFS-NEMO.

Workflow modes
--------------
There are 4 modes of the workflow:

- ``model``: runs the model (ICON, IFS-FESOM, IFS-NEMO).
- ``end-to-end``: runs the model and the selected applications in a streaming fashion.
- ``applications``: runs the applications only by simulating the data streaming (``DN`` + ``OPA`` + ``APP``).
  - ``data``: same as ``applications`` but with a single dummy `APP` named `DATA`.
- ``simless``: runs the steps previous to the model without executing the SIM step. This is useful to run additional jobs (e.g. backup, transfer, etc.) and deal with data produced in a separate experiment.

List of jobs
----------------------

The templates are located in ``/workflow/templates``.

- ``local_setup``: performs basic checks as well as compressing the workflow project in order to be sent through the network. Runs in the Autosubmit VM.
- ``synchronize``: syncs the workflow project with the remote platform. Runs in the Autosubmit VM.
- ``remote_setup``: loads the necessary environment and then compiles the different models/applications. Performs checks in the remote platform. Runs in the remote platform (login nodes for LUMI, interactive partition for MareNostrum5). Installs the running applications and the GSV interface.
- ``ini``: prepares any necessary initial data for the climate model runs. Runs in the login node of the HPC.
- ``sim``: runs one chunk of climate simulation. Runs in the HPC.
- ``dqc``: performs basic checks on the data produced by the simulation. Runs in the HPC. It has two modes: BASIC and FULL.
- ``dn``: notifies when the wanted data is already produced by the model. Runs in the login node of the HPC.
- ``opa``: creates the statistics required by the data consumers (Apps). Runs in the HPC.
- ``applications``: creates usable output using the applications from the different use cases. Runs in the HPC.

Additional jobs (optionals)
----------------------------

- ``transfer``: transfers the data produced in the simulation to the Data Bridge. Runs in the HPC.
- ``backup``: copies the rundir and the restarts to another partition. Runs in the HPC.
- ``check_mem``: monitors the memory consumption of the SIM jobs. Runs in the login node of the HPC.
- ``wipe``: wipes already transferred data from the HPC-FDB. Runs in the HPC.
- ``clean``: compresses the rundir and the logs from the HPC. Purges the data of the FDB (deletes repeated entries). Runs in the login node of the HPC.
- ``scaling``: performs a scaling test of the model. Runs in the HPC.
- ``aqua``: contains 3 jobs: LRA_GENERATOR, AQUA_ANALYSIS and AQUA_PUSH. The first one generates the LRA files and the second one performs the analysis of the AQUA files. Both run in the HPC. The last one pushes the AQUA plots to LUMI-O. Runs in the Autosubmit VM.
- ``POSTPROC_$APP_NAME``: enables the placeholder job at the end of the chunk (to be used in app or end-to-end modes) to run postprocessing scripts outside the core streaming. It is a job per application.

Selectable configuration
------------------------

We are now running the workflow with the new version of the CUSTOM_CONFIG and the minimal configuration new features of Autosubmit.
This new configuration scheme allows for a distributed, hierarchical parametrization of the workflow, thereby providing a more customizable, modular, and user-friendly workflow.
The structure, domain and use of this new configuration scheme will likely evolve as it adapts to the needs of other work packages.

In the ``main.yml`` the user will decide the parameters of the simulation. Depending on what the user selects, one set or another of configurations will be loaded.
The parameters ``RUN.WORKFLOW``, ``RUN.TYPE``, ``MODEL.NAME``, ``MODEL.SIMULATION``, ``MODEL.GRID_ATM``, ``CONFIGURATION.ADDITIONAL_JOBS.*``, ``APP.NAMES`` will be used to load the configuration files.
The user can overwrite any parameter defininig it in the ``main.yml`` file. It will have priority over the default configuration files loaded previously.

In the ``minimal.yml`` the basic information of the experiment is defined. It is the last file loaded in the configuration process. For more information: `Autosubmit documentation on minimal experiments  <https://autosubmit.readthedocs.io/en/master/userguide/set_and_share_the_configuration/index.html#advanced-configuration>`_.

Containers usage
-----------------

The workflow runs some componens conteinarized. Those containers are already deployed in the HPCs. The containers are used for the following components:
- AQUA (https://github.com/DestinE-Climate-DT/AQUA/pkgs/container/aqua)
- GSV_INTERFACE (https://github.com/DestinE-Climate-DT/ContainerRecipes/pkgs/container/gsv currently patched, installing jinja2)
- BASE (https://github.com/DestinE-Climate-DT/ContainerRecipes/pkgs/container/BASE)
- DVC
- ENERGY_ONSHORE
- ENERGY_OFFSHORE
- HYDROMET
- HYDROLAND
- WILDFIRES_FWI
- WILDFIRES_WISE
- ONE_PASS
- TOOLS
- ENSEMBLES

(NOTE: `https://github.com/DestinE-Climate-DT/ContainerRecipes/pkgs/container` does not hold all the containers under but they should be soon deployed automatically to the HPCs.)
