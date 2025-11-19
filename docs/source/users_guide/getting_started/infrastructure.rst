Infrastructure
--------------

In the current Phase of Destination Earth, i.e. Phase 2, a few machines adhered to


Machines
========

LUMI
****

`LUMI <https://lumi-supercomputer.eu/>`_ is hosted by `CSC <https://csc.fi/en/>`_ in Finland.

To gain access please follow `these instructions <https://wiki.eduuni.fi/pages/viewpage.action?pageId=319161939&spaceKey=cscRDIcollaboration&title=Access%2Bto%2BLumi>`_. Please, note that different steps apply depending on whether you are a Finnish / CSC user, or a EuroHPC user.


MareNostrum 5
*************

`MareNostrum 5 <https://bsc.es/es/marenostrum/marenostrum-5>`_ is hosted by `BSC <https://bsc.es/>`_ in Spain.

To gain access please follow `these instructions <https://wiki.eduuni.fi/spaces/cscRDIcollaboration/pages/480346152/Access+to+Marenostrum+5+-+instructions>`_.


.. _autosubmit_vm:

Autosubmit Virtual Machine
**************************

The Autosubmit Virtual Machine (ASVM) is hosted by CSC, and serves as an entry point for the users and developers to run and test experiments. It has an installation of Autosubmit, the workflow manager with which the workflow is run.

For more information and to gain access please follow `these instructions <https://wiki.eduuni.fi/spaces/cscRDIcollaboration/pages/462100843/Autosubmit+Virtual+Machine>`_.


Containers
==========

Most of the components used in the workflow are containerized, and can be run in any machine that supports containers. They are used in the workflow to ensure reproducibility and portability of the experiments.

The containers are deployed by A1 and the recipies used are stored in `ContainerRecipies <https://github.com/DestinE-Climate-DT/ContainerRecipes/tree/main>`_.

Data Storage
============

The data produced by the workflow is stored temporarely in the HPC where it is produced. The path depends on the type of experiment running, and in any case, is stored in an FDB.

The data can be automatically transferred to the Data Bridge using the TRANSFER jobs. Once it is correctly transferred, it can then be deleted from the HPC using the WIPE jobs.

The data consumers (Apps) can then access the data from the Data Bridge. The access is different in LUMI and MARENOSTRUM5, due to the architecture of the machines.
