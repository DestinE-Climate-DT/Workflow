Software components
-------------------

These are two lists of the components of DestinE, which appear as different parts of the workflow.

1. From `Operations Committee <https://wiki.eduuni.fi/spaces/cscRDIcollaboration/pages/519539831/Operations+Committee>`_
2. From the `Roadmap for Next Cycle <https://wiki.eduuni.fi/spaces/cscRDIcollaboration/pages/589749899/Roadmap+for+next+cycle>`_

Please, note that these links are added as of May 2025. Although they contain comprehensive lists, they may become obsolete.

Besides Autosubmit (see section :ref:`autosubmit`) and the workflow itself, this is a description of the different components in DestinE.

Climate Models
==============

The following climate models are part of the DestinE workflow:

- IFS-FESOM: pre-installed versions stored in the HPC. The interface between the workflow and IFS-FESOM is in RAPS. The workflow calls hres with a set of pre-defined flags including FESOM-specific flags for ocean coupling, I/O allocation, and MIR cache configuration. Supports both task-based and node-based I/O allocation modes.
- IFS-NEMO: integrated as a submodule, as it can be compiled in the workflow. The interface between the workflow and IFS-NEMO is in RAPS. The workflow calls the hres/model script with a set of pre-defined flags depending on the experiment that will run. The ifs-bundle is used in IFS-NEMO to automatically compile the model.
- ICON: pre-installed versions stored in the HPC.


AQUA
====

- ``AQUA`` is used within the workflow as a Singularity container.
- ``catalog`` is cloned on demand during local setup (revision controlled by ``AQUA.CATALOG_REF``), contains the AQUA catalog metadata needed to run experiments, and is synced to the HPC separately from the workflow project.


GSV Interface (GSV)
===================

- ``GSV interface`` is used within the workflow as a Singularity container. It is used in all the tasks that require reading and processing of data.


One Pass Algorithms (OPA)
=========================

- ``One_Pass`` package
- Bias Adjustment (Bias Correction)

Data Quality Checker (DQC)
==========================

Task that runs the data quality checks on the data produced by the models. It is part of the GSV interface.

Applications (APP)
==================

- OBSALL
- Energy Indicators
- Hydroland
- Hydromet
- Wildfires FWI
- Wildfires WISE


Data Portfolio (DP)
==================

The data portfolio is a submodule of the workflow that determines the expected output by every model, in every configuration and resolution, and the metadata associated with it. It is used to ensure that the data produced by the workflow is consistent and meets the requirements of the Destination Earth project.

Data Version Control (DVC)
=========================

DVC is used to manage the input data used by some of the models (currenlty, IFS-NEMO).

.. note::

    To see the different jobs and configurability that each of the components runs in, see the section :ref:`jobs`.
