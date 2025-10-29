Applications
------------

How can I update my application?
********************************

See the section :ref:`integration_of_applications`.


How can I update my application submodule? (only in development branches)
*************************************************************************

Go inside your application's submodule, do ``git fetch``, ``git checkout $your-branch``. Check that it points to your lastest commit (``git log``) and once it is correct, go back to the workflow repository, ``git add`` the submodule, ``git commit`` and ``git push``.
