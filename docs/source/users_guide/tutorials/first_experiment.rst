Your first experiment
---------------------

Create your own experiment
==========================

1. Create an Autosubmit experiment using minimal configurations to run a test experiment in marenostrum5.

To run your first experiment, you need to have an experiment ID (autosubmit expid) for you this can be done by:

.. code-block:: bash

   autosubmit expid \
     --description "My first experiment" \
     --HPC MareNostrum5 \
     --minimal_configuration \
     --git_as_conf conf/bootstrap/ \
     --git_repo https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow \
     --git_branch <latest TAG (see below)>

.. list-table:: Command Options
   :header-rows: 1

   * - Key
     - Options
     - Notes
   * - DESCRIPTION
     - *any*
     - Add some useful information
   * - PLATFORM
     - marenostrum5, lumi
     - More platforms can be added in the future
   * - TAG
     - `use latest tag <https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/tags>`_
     - Latest tested tag

.. note ::
  You must change the keys between < > !

You will receive the following message: *Experiment <expid> created*, where ``<expid>``
is the identifier of your experiment. A directory will be created for your experiment
at: ``/appl/AS/AUTOSUBMIT_DATA/<expid>``.

Basic instructions to execute the workflow with Autosubmit can be found in `How to run <https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/wikis/How-to-run>`_. The rest of the documentation is available in the same `Wiki <https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/wikis/home>`_.

2. Start the interactive command line to setup the main characteristics of your experiment: write(models), read(apps,simless) or streaming(end-to-end).

.. code-block:: bash

   # type anywhere in the virtual machine
   autosubmit create <expid>

.. note ::
  You are asked to introduce the credentials to the remote repositories, therefore you must have access to it to proceed.

You will be further asked to select the type of workflow you want to run:

.. code-block:: bash

   Choose a workflow:
   1. model
   2. end_to_end
   3. app
   4. simless
   Enter your choice (1/2/3/4):

Depending on the option that you select you will be further asked for details on the simulation you want to run, such as what model or applications you want to run and for what period.

.. note ::

  You have now the option to edit the document in vim. You can do it by typing 'i', edit it and save it by typing ':wq'.
  If you have any doubts when editing the main configuration file, read carefully the keys description in ``docs/source/keys_main.rst``.

.. note ::

  The supported options for the current tutorial are: ``app``, ``end-to-end`` (``ifs-nemo``), and ``model`` (``ifs-nemo``).

You will be popped up with a pdf of the structure o fthe workflow that you just have chosen. In this moment the experiment is as well visible in the `Autosubmit GUI <https://climatedt-wf.csc.fi/>`_.

3. After your experiment is defined and you are fine with what you see in the image or in the GUI, close the PDF to continue. You can then execute ``autosubmit run $expid`` to run your experiment. If you want to have your experiment in the background (that is, in a way you can close your terminal and get a coffee in the meantime) you can use the nohup (*no hang up*) command:

.. code-block:: bash

  nohup autosubmit run $expid &
