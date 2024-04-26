About the project
==================

This repository contains the DE_340 workflow. It is used for production, development and testing in conjunction with `Autosubmit4 <https://earth.bsc.es/gitlab/es/autosubmit>`_. The implemented workflow tasks keep a model-agnostic interface and contain the merged sub-workflows for ICON, IFS-FESOM, and IFS-NEMO. Currently, LUMI is supported for IFS-NEMO and ICON to perform simulations. MareNostrum4 is supported for IFS-NEMO.

Current list of steps:
----------------------

Each step contains a very short description of its main purpose. The templates are located in ``/workflow/templates``.

- ``local_setup``: performs basic checks as well as compressing the workflow project in order to be sent through the network. Runs in the Autosubmit VM.
- ``synchronize``: syncs the workflow project with the remote platform. Runs in the Autosubmit VM.
- ``remote_setup``: loads the necessary environment and then compiles the different models/applications. Performs checks in the remote platform. Runs in the remote platform (login nodes for LUMI, interactive partition for MN4). Installs the running applications and the GSV interface.
- ``ini``: prepares any necessary initial data for the climate model runs. If desired, deletes old restarts and run directories. Runs in the login node of the HPC.
- ``sim``: runs one chunk of climate simulation. Runs in the HPC.
- ``dn``: notifies when the wanted data is already produced by the model. Runs in the login node of the HPC.
- ``opa``: creates the statistics required by the data consumers (Apps). Runs in the HPC.
- ``applications``: creates usable output using the applications from the different use cases. Runs in the HPC.

Additional jobs (optionals):
----------------------------

- ``transfer``: transfers the data produced in the simulation to the Data Bridge.
- ``backup``: copies the rundir and the restarts to another partition.
- ``check_mem``: monitors the memory consumption of the SIM jobs.
- ``dqc``: performs basic checks on the data produced by the simulation.
- ``wipe``: wipes already transferred data from the HPC-FDB.

Selectable configuration
------------------------

We are now running the workflow with the new version of the CUSTOM_CONFIG and the minimal configuration new features of Autosubmit. This new configuration scheme allows for a distributed, hierarchical parametrization of the workflow, thereby providing a more customizable, modular, and user-friendly workflow. The structure, domain and use of this new configuration scheme will likely evolve as it adapts to the needs of other work packages.
