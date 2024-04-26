==========================
Cheat Sheet for Autosubmit
==========================


Preview your scripts
~~~~~~~~~~~~~~~~~~~~~

``autosubmit inspect $expid``

With this command, Autosubmit will generate the ``.cmd`` files that will
be submitted when you perform ``autosubmit run $expid``. You can check
them in ``$expid/tmp``.

`+
info <https://autosubmit.readthedocs.io/en/master/userguide/monitor_and_check/index.html#how-to-generate-cmd-files>`__

See the defined variables
~~~~~~~~~~~~~~~~~~~~~~~~~~

``autosubmit report $expid -all``

With this command Autosubmit will generate a list of all the variables
loaded. You can check this list in ``$expid/tmp``

`+
info <https://autosubmit.readthedocs.io/en/master/userguide/monitor_and_check/index.html#how-to-extract-information-about-the-experiment-parameters>`__

Check the graph/status of your experiment
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
``autosubmit monitor $expid``

This command will open a ``pdf`` file with the current status of the
workflow. You will be able to visually check which processes are
running, completed, waiting…

`+
info <https://autosubmit.readthedocs.io/en/master/userguide/monitor_and_check/index.html#how-to-extract-information-about-the-experiment-parameters>`__

Run your long workflow
~~~~~~~~~~~~~~~~~~~~~~~

``nohup autosubmit run $expid`` 

If you are planning to launch a long
workflow, you can launch it with the ``nohup`` option. In this way, you
can safely close your terminal and Autosubmit will continue managing
your jobs. If you want to check the regular output, check
``$expid/tmp/ASLOGS/$date_$command``. If you want to stop Autosubmit,
``ps ax | grep autosubmit`` will show you the running jobs. Look for
yours and kill it: ``kill $jobid``.

   Notice that this won’t stop the jobs that are already running in the
   HPC. In order to kill them, in the HPC, look for your job and cancel
   it.

`+
info <https://autosubmit.readthedocs.io/en/master/userguide/run/index.html>`__

Resubmit your FAILED jobs:
~~~~~~~~~~~~~~~~~~~~~~~~~~

``autosubmit setstatus EXPID -fs FAILED -t WAITING -s``

Skip chunks that you already run:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

It might happen that you want to restart from a previous run. You are
probably willing to skip some of the chunks. In order to do so, you can
take advantage of ``autosubmit setstatus`` command. An example, in order
to begin from chunk 8, would be:

``autosubmit setstatus $expid -fl "a03s_19500101_fc0_INI a03s_19500101_fc0_1_SIM a03s_19500101_fc0_2_SIM a03s_19500101_fc0_3_SIM a03s_19500101_fc0_4_SIM a03s_19500101_fc0_5_SIM a03s_19500101_fc0_6_SIM a03s_19500101_fc0_7_SIM" -t COMPLETED -s``

   Autosubmit must be stopped in order to do this.

`+
info <https://autosubmit.readthedocs.io/en/master/userguide/manage/index.html#how-to-change-the-job-status>`__.

How to SYNCHRONIZE your HPC experiment directory with the one in the VM (for example, after a workflow update)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-  Run ``autosubmit refresh`` or ``git pull`` inside the
   ``proj/git_project`` directory.
-  Make sure that your experiment is stopped.
-  Run the following commands

::

   # Will make the SYNC step to ready to run
   autosubmit setstatus $EXPID -fl "$EXPID_SYNCHRONIZE" -t READY -s
   # Change `a0cp_19900101_fc0_1_SIM` for the next chunk that you want to run. AS won't run this chunk.
   autosubmit setstatus $EXPID -fl "a0cp_19900101_fc0_1_SIM" -t SUSPENDED -s
   # Run the experiment (it will just run the SYNC step)
   autosubmit run $EXPID
   # Set the suspended job to ready to run.
   autosubmit setstatus $EXPID -fs SUSPENDED -t READY -s
   # Continue your experiment
   autosubmit run $EXPID
