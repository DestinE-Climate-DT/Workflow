Data governance
***************

The FDB (Fields Data Base) is a domainspecific object store for meteorological data described by a curated schema of scientifically meaningful metadata. In this workflow, the FDB is used to store the data produced by the climate Models.

The applications read the data from the FDB. The keys used to write and read the data are defined under the REQUEST section of the YAML configuration files, and are based on the current schema.

The data in the FDB is encoded with a set of keys. This is the current first layer of the schema used in Climate-DT, that is used to encode the data in the FDB. The keys are:

.. code-block:: none

    class=d1, dataset=climate-dt, activity, experiment, generation, model, realization, expver, stream=clte/wave, date

Most of them are governed by the workflow, under REQUEST keys:

+-------------+---------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------+
| Key         | Values                    | Observations                                                                                                                                            |
+=============+===========================+====================================================================================================================================================+
| CLASS       | currently, ``d1``         |                                                                                                                                                    |
| DATASET     | currently, ``climate-dt`` |                                                                                                                                                    |
| EXPERIMENT  |                           | (See below) |
| ACTIVITY    |                           | (See below) |
| REALIZATION | number, from 1            | Set in the workflow according to the member number |
| GENERATION  | number, currently 1 or 2  | Marks the operational cycle in which the data was produced |
| MODEL       |                           | Set in ``main.yml``, where the key ``%MODEL.NAME%`` is set to specify the model we run                                                             |
| EXPVER      | ``0001`` or EXPID         | ``0001`` (for ``RUN.TYPE`` *production* or *pre-production*) or EXPID of experiment that produced the data (for ``RUN.TYPE`` *research* or *test*) |
| STREAM      |                           | Set by RAPS in IFS-NEMO and IFS-FESOM                                                                                                              |
| DATE        | ``YYYYMMDD``              |                                                                                                                                                    |
+-------------+---------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------+

``EXPERIMENT`` and ``ACTIVITY`` are set by RAPS in IFS-NEMO and IFS-FESOM. In IFS-FESOM, forcing is configured via granular keys in the ``SIMULATION`` config files: ``%CONFIGURATION.RAPS_FORCING_AEROSOLS%``, ``%CONFIGURATION.RAPS_FORCING_AEROSOLS_VOLCANIC%``, ``%CONFIGURATION.RAPS_FORCING_GHG%``, and ``%CONFIGURATION.RAPS_FORCING_OZONE%``. MultIO metadata (``EXPERIMENT`` and ``ACTIVITY``) is set via ``REQUEST.EXPERIMENT`` and ``REQUEST.ACTIVITY``. In IFS-NEMO, the key ``%CONFIGURATION.RAPS_EXPERIMENT%`` can still be used (deprecated). In ICON, the values of ``REQUEST.EXPERIMENT`` and ``REQUEST.ACTIVITY`` are directly used by the model.

.. note::

    The keys ``REQUEST.EXPERIMENT``, ``REQUEST.ACTIVITY``, ``REQUEST.GENERATION``, ``REQUEST.MODEL``, ``REQUEST.REALIZATION`` and ``REQUEST.RESOLUTION`` are used to read the data from the FDB.

Information about the portfolio and the FDBs used in the workflow: https://wiki.eduuni.fi/spaces/cscRDIcollaboration/pages/578275221/Data+portfolios+and+FDB+documentation

Workflow types
==============

Depending on the type of workflow, the data is stored in different FDBs and is to be accessed in a different way. The workflow allows to enable one or another way of accessing the data via the ``RUN.TYPE`` key in the main.yml file. The allowed keys for it are:

- ``operational``: The experiment writes the data using 0001 expver instead of the expid provided by Autosubmit. It writes in the HPC-FDB.
- ``operational-read`` (previously ``production``): The experiment reads the data from HPC-FDB using the expid provided by autosubmit. The data was previously written using 0001 expver.
- ``research``: The experiment writes the data using the expid provided by Autosubmit. It writes in the HPC-FDB.
- ``pre-production``: The experiment writes the data using 0001 expver instead of the expid provided by Autosubmit. It writes in a local FDB.
- ``test``: The experiment writes [reads] the data using the expid provided by Autosubmit. It writes in [reads from] a local FDB.

DataBridge
==========

If the data was already transferred to the DataBridge, it can be read by enabling the key ``APP.READ_FROM_DATABRIDGE`` in the main.yml file.

LUMI
----

To access the data in the Data Bridge, it is enough to point to the correct FDB_HOME. The workflow will enable it by setting:


.. code-block:: yaml

    APP:
        READ_FROM_DATABRIDGE: "True"

MareNostrum 5
-----------------

To access the data in the Data Bridge, the data needs to be downloaded to the HPC through the client machine. By default, the workflow will use the `MARENOSTRUM5-READDATABRIDGE` platform. In which case, the following should be in the main.yml:

.. code-block:: yaml

    APP:
        READ_FROM_DATABRIDGE: "True"

If you do not wish to pull the data from the Data Bridge, you should add the following instead:

.. code-block:: yaml

    JOBS:
        DN:
            PLATFORM: "MARENOSTRUM5-LOGIN"

The ``MARENOSTRUM5-READDATABRIDGE`` platform is defined in the ``platforms.yml`` file, and it points to the client machine. It has access to the Data Bridge, and it can download the data to the HPC.
The data is downloaded using the ``dn`` job. If this job is run in the client machine, it downloads the data to the HPC-FDB, and it can be accessed with the same FDB_HOME and keys as if it was stored in the production FDB.

Physically, the data is downloaded to: ``/gpfs/scratch/ehpc01/dte/fdb/gateway``.
