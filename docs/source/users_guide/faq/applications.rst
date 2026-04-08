Applications
------------

How can I update my application?
********************************

See the section :ref:`integration_of_applications`.


How can I update my application submodule? (only in development branches)
*************************************************************************

Go inside your application's submodule, do ``git fetch``, ``git checkout $your-branch``. Check that it points to your lastest commit (``git log``) and once it is correct, go back to the workflow repository, ``git add`` the submodule, ``git commit`` and ``git push``.

How can I read from an ensemble member in an ensemble run, apps alone workflow?
*******************************************************************************

In order to read from a member that is encoded in an FDB with a given REALIZATION number, the realization number must be state under REQUEST.REALIZATION in ``conf/main.yml`` . For example, if a user wants to read from a member that was written as REALIZATION=3 in the data bridge or in any other FDB, they will have to state ``REQUEST.REALIZATION: 3``, regardless of the key stated under ``EXPERIMENT.MEMBERS`` that they select.

NOTE: The workflow does only support the read of 1 single member or all members of an ensemble in an experiment but not any other subset of members.
