.. _prerequisites:

Prerequisites
-------------------------

Some workflow configurations require additional permissions or access to specific resources. This page lists those prerequisites and links to the documentation that explains them in more detail.

Access to required infrastructure resources
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To run the workflow, you must have access to either MareNostrum5 or LUMI, and to the Autosubmit Virtual Machine. Instructions for obtaining access to these resources are provided in the :ref:`infrastructure` section.

Access to computational resources
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To run the workflow, you must be authorized to use compute resources on either MareNostrum5 or LUMI.

- The development project in MareNostrum5 is `ehpc01`. If you already have access to MareNostrum5 but need access to this project, you can ask for it by adding a comment on this `page <https://gitlab.earth.bsc.es/digital-twins/de_340-2/project_management/-/issues/76>`_.

- The development project in LUMI is `project_465002727`. If you already have access to LUMI but need access to this project, you can request it by following the instructions in the section :ref:`infrastructure_lumi`.

Access to the datamover machine
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To access the Data Bridge in MareNostrum5 through the workflow, users need access to an intermediate machine through a shared user (datamover@mn5-prod-client1). When logged in, data from the bridge can be downloaded to MareNostrum5 for use. If the platform selected for the experiment is MareNostrum5, some workflow jobs, such as data transfer or wipe jobs, require this access. If you need access to this machine, please follow the instructions in this `page <https://wiki.eduuni.fi/spaces/cscRDIcollaboration/pages/628993364/MN5-prod-client+machine+access+intermediate+access+to+MN5+Data+Bridge>`_.

Additional configurations for AQUA
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Some AQUA-related jobs require extra configuration. If you want to run AQUA jobs, please read the section :ref:`aqua_usage`. The following permission is required for these jobs:

 - `AQUA_PUSH`: to push changes to the AQUA catalog, you need write access to this `repository <https://github.com/DestinE-Climate-DT/Climate-DT-catalog>`_. Optionally, you may also request access to the AQUA Dashboard to view the figures produced by this job. To request Dashboard access, sign in to the `ClimateDT Internal Evaluation Charts Portal <https://climatedt-internal-dashboard.2.rahtiapp.fi>`_ and submit a request.
