.. _getting_started:

Getting Started
===============

All the experiments should be created in the `Autosubmit Virtual Machine`_. To access the VM, you need a user and your SSH key to be authorized. Add your name, e-mail, preferred username, and SSH (local) public key to the `table`_.

Make sure you have a recent Autosubmit version running ``autosubmit --version``. You can follow more detailed description about Autosubmit in `Autosubmit Readthedocs`_.

Prerequisites
-------------

Inside the Autosubmit VM, you need to put your user configurations for platforms somewhere (we recommend ``~/platforms.yml``)::

        # personal platforms file
        # this overrides keys the default platforms.yml

        Platforms:
            lumi-login:
                USER: <USER>
            lumi:
                USER: <USER>
            lumi-transfer:
                USER: <USER>
            marenostrum5:
                USER: <USER>
            marenostrum5-login:
                USER: <USER>

You also need to configure password-less access to the platforms where you want to run experiments. Further instructions can be found `here`_ (Section 4. How to get password-less access from VM to Levante / LUMI / MN4).

.. _Autosubmit Virtual Machine: https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+VM
.. _table: https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+VM+Users
.. _Autosubmit Readthedocs: https://autosubmit.readthedocs.io/en/master/
.. _here: https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+VM

Development environment
-----------------------

To set up the development environment, you need to follow these steps:

- Create a virtual environment: ``python3 -m venv venv``
- Activate the virtual environment: ``source venv/bin/activate``
- Install the dependencies: ``pip install -e .[test]``
- Install the pre-commit hooks: ``pre-commit install --install-hooks``


Access to the GUI
-----------------

For those that need access to the GUI, you can add your github ID + email to this table: https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+GUI+users
