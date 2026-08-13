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

The realization is derived from the member's own name: ``fcN`` resolves to realization ``N+1``. To read the member written as REALIZATION=3 in the data bridge or in any other FDB, state ``EXPERIMENT.MEMBERS: fc2``.

NOTE: The workflow does only support the read of 1 single member or all members of an ensemble in an experiment but not any other subset of members.
