Testing Suite setup guide
=========================

Overview
--------

The testing suite is a tool for deploying experiment runs on HPC platforms and for supporting functional testing of the ClimateDT workflows repository.
It is designed to simplify interaction with test cases, including copying cases, managing autosubmit operations, comparing run parameters and outputs, and generating reports.

For the project and its documentation, see:
`Testing Suite documentation <https://gitlab.earth.bsc.es/es/testing_suite>`_.

.. note::

   This page covers the ``testing_suite`` CLI, run by hand from the shared
   ``tsuite1`` account. It is a different tool from the CI testing suite (the
   ``tsuite-*`` GitLab CI jobs) described in :doc:`pipelines_and_jacamar` — those
   run ``destine tsuite ...`` from ``wftools/`` and need no setup here.

Prerequisites
-------------

- Access to the ``tsuite1`` shared user on the Climate DT Autosubmit VM is required before any testing suite operations.
- Password-less SSH access to the target clusters such as ``lumi-cluster`` and ``mn5-cluster1``.
- A recent Autosubmit version configured in the testing suite ``main_config.yml``.
- Valid API, LUMI-O, and GitHub credentials.

Required setup steps
--------------------

1. Access the shared ``tsuite1`` account (if you do not have access, contact the workflow team to request it).

   - Use ``sudo -i -u tsuite1`` on the Climate DT Autosubmit VM.
   - Work from the testing suite installation folder, typically ``/home/tsuite1/testing_suite``.

2. Configure Autosubmit user mapping

   - Activate and configure user mapping as described in the Autosubmit user guide:
     `Autosubmit user mapping <https://autosubmit.readthedocs.io/en/latest/userguide/user_mapping.html#how-to-activate-it-with-examples>`_.

3. Ensure cluster access

   - Confirm you can access required HPC systems without a password prompt.
   - This is usually done with SSH key-based authentication and correct cluster host configuration.

4. Access to the data mover

   - Passwordless access to the MN5 datamover is required; the SSH stanza is in :ref:`mn5-datamover-access` below.

5. Obtain the GUI/API Bearer token

   - Open Chrome and go to https://climatedt-wf.csc.fi/.
   - Open developer tools with Fn + F12.
   - Go to the Application tab, then Local Storage, then the ``climatedt`` entry.
   - Copy the ``token`` value (the Bearer token).
   - Paste it in ``/home/tsuite1/testing_suite/main_config.yml`` under ``Common.api_headers.Authorization``.

   .. warning::

      This is *your personal* token, and ``tsuite1`` is a shared account: everyone
      with ``tsuite1`` access can act as you against the GUI/API for as long as it
      is valid. Replace it when it expires, remove it when you no longer need it,
      and never commit ``main_config.yml``.

6. Obtain LUMI-O credentials for AQUA-push

   - Store AWS credentials in ``~/.aws/credentials``.
   - Sign in at https://auth.lumidata.eu/.
   - Select the correct project and generate an access key with an appropriate duration (for example, up to 1 year).
   - Add the credentials in this format:

     .. code-block:: text

        [development]
        aws_access_key_id = XXXXXXXXXXXXXX
        aws_secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXXX

7. Add GitHub SSH credentials

   - In the VM, run ``ssh-add -L`` to display your public SSH key.
   - Register the key in GitHub under Settings -> SSH and GPG keys -> New SSH key.

8. Verify the testing suite configuration

   - Confirm the tokens and credentials are present in the testing suite configuration files.
   - Make sure the ``main_config.yml`` uses the correct API and GitLab tokens.

.. _mn5-datamover-access:

MN5 datamover access
--------------------

Passwordless access to the MN5 datamover uses the following SSH configuration. It is the
same on the regular Autosubmit VM and on the development VM used by the CI testing suite
(:doc:`pipelines_and_jacamar`).

.. code-block:: text

   Host mn5-prod-client1 mn5-prod-client1.mn5.apps.dte.destination-earth.eu
      User datamover
      HostName mn5-prod-client1.mn5.apps.dte.destination-earth.eu
      ProxyJump ubuntu@217.71.198.144

More information on getting datamover access is available in the
`datamover documentation <https://wiki.eduuni.fi/spaces/cscRDIcollaboration/pages/628993364/MN5-prod-client+machine+access+intermediate+access+to+MN5+Data+Bridge>`_.

Running the testing suite
-------------------------

Typical workflow commands:

- ``testing_suite --clean``
- ``testing_suite --refresh clone``
- ``testing_suite --create``
- ``nohup testing_suite --run &``
- ``testing_suite --status`` — display the status of the experiments.

Selecting a config file and a branch
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``--config_file`` selects which config file — and therefore which set of experiments —
a command applies to. It defaults to ``config.yml``.

``--set_branch`` points every experiment in that config file at one git branch in a
single command, by rewriting ``PROJECT_BRANCH`` in each experiment's ``minimal.yml``:

.. code-block:: bash

   testing_suite --config_file main-6.2.3.yml --set_branch main
   testing_suite --config_file main-6.2.3.yml --set_branch v6.2-production

Notes
-----

- If the autosubmit version in the testing suite config is not the latest, update it or check with the Autosubmit team.
- After tests pass, follow local project release and merge policies as needed.
- Announce successful suite completion and unblock main only after validating the results.
