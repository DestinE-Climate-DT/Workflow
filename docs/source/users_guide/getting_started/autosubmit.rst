.. _autosubmit :
Autosubmit
----------

Permissions
===========

All experiments should be created in the `Autosubmit Virtual Machine <https://wiki.eduuni.fi/spaces/cscRDIcollaboration/pages/462100841/Autosubmit+Virtual+Machine+Users>`_ (see section :ref:`autosubmit_vm`).

To access the VM, you need a user and your SSH key to be authorized. Add your name, e-mail, preferred username, and SSH (local) public key to the Autosubmit VM Users table.

Follow the instructions `here <https://wiki.eduuni.fi/spaces/cscRDIcollaboration/pages/462100843/Autosubmit+Virtual+Machine>`_ to configure setup according to institution affiliation.

If you have connection errors, check the following:
 - Ensure that your .bashrc is clean, doesn't export variables or load modules that may interfere with the Autosubmit environment, and doesn't contain any aliases that could cause issues.
 - Make sure that there is a directory created under your project's scratch with your username.
 - Make sure that the password-less connection from the Autosubmit VM to the HPC system is working. You can test this by running a simple command like ``ssh <your_username>@<hpc_system> hostname`` from the Autosubmit VM terminal. If you need to configure password-less SSH, follow the instructions in this `page <https://wiki.eduuni.fi/spaces/cscRDIcollaboration/pages/462100843/Autosubmit+Virtual+Machine#AutosubmitVirtualMachine-4.Howtogetpassword-lessaccessfromVMtoLevante%2FLUMI%2FMN4%2FMN5%5Bwip%5D>`_.
 - If you plan to run SYNC_LRA, you need to have password-less connection from LUMI to MN5. This means that in your ~/.ssh/config file in LUMI, you should include:

.. code-block:: yaml

    Host mn5-cluster1
        HostName glogin2.bsc.es
        User XXXX


Installation
============

Autosubmit is installed on the Autosubmit VM, and you can access it via the command line.
Make sure you have a recent Autosubmit version running with the command

.. code-block:: bash

    $ autosubmit --version

User Configurations
====================

Once you have access to the Autosubmit VM, connect to it and add your user configurations to the file ``~/platforms.yml``. Make sure that the username for each platform matches your username for that institution as they could differ:

.. code-block:: yaml

    # Personal platforms file
    # this overrides keys the default platforms.yml

    Platforms:
        lumi-login:
            USER: <LUMI USER>
        lumi:
            USER: <LUMI USER>
        lumi-transfer:
            USER: <LUMI USER>
        lumi-readdatabridge:
            USER: <LUMI USER>
        marenostrum5:
            USER: <BSC USER>
        marenostrum5-login:
            USER: <BSC USER>
        marenostrum5-transfer:
            USER: <VM USER>
        marenostrum5-readdatabridge:
            USER: <VM USER>

GUI Access
===========

To gain access to the Autosubmit GUI, add your github ID and email to `this table <https://wiki.eduuni.fi/pages/viewpage.action?spaceKey=cscRDIcollaboration&title=Autosubmit+GUI+users>`_.
