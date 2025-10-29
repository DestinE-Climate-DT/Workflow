.. _integration_of_applications:

Integration of Applications
***************************

Updating Applications
---------------------

When the application developer has a new feature or a fix to be added in the climateDT workflow, the following steps must be followed:

1. The application developer works on the source code of the application in their corresponding repository, normally locally with test data.

2. **Before testing anything in the workflow**, the application **must** pass its unit tests to ensure that any potential errors that appear come from the workflow integration and not from the application itself.

3. Once the unit tests have passed, the application developer should create a tag (and potentially a release). Once there is a tag, the application can be run inside the workflow directly if the interfaces did not change, by asking A1 to create and deploy a container on the different HPC machines to be used by the workflow. Then the version of the application to be tested can be selected via the workflow configuration file: ``conf/application/container_versions.yml``. The application developer should then run a short workflow to verify if the application works without issues in the workflow. If issues arise at this step, support will be provided by the workflow team. If the issue is in the workflow, the workflow team will take over. If the error is elsewhere, either A1 (containers) or the application developer will take over. Eventually, if the error is in the application, the tag should be updated with the fix and the container rebuilt and redeployed.

   **(Advanced, option, if the software dependencies do not change in the new app tag)** Use the application as a submodule in the workflow. This approach involves modifying the workflow by adding the application as a submodule. The source code, in this case, is used by modifying the ``PYTHONPATH``, while still relying on an older version of the application to set up the environment. This allows direct testing of the application within the workflow by modifying the source code directly on the HPC. If the tests are successful, the application developer should release a new tag and ask A1 to deploy the container, and then proceed with the standard option just described above.

4. Once the integration in step 3 is completed, the application is included in the workflow's weekly testing suite. If successful, the application is then included in the next workflow release.

.. note::

   *What if the app developer has to change not only the app source code but also some parts of the workflow repository (the interface of the application inside the workflow)?*

   Then you should open `an issue <https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/issues/new>`_ in the workflow repository and the workflow team will evaluate whether the changes make sense at the workflow level.

 If so, you can work on a branch that contains the issue number in the name (click on "New Merge Request"). Eventually the workflow team will validate your changes and it will get into the workflow main branch.

Updating Components as Submodule
--------------------------------

.. note::
   This includes ``ifs-nemo``, ``catalog``, ``dvc-cache-de340``, ``data-portfolio`` and ``nemo``.

1. Clone this repository. Check out the update-components branch.`
2. Run ``git submodule update --init ${COMPONENT}``

3. Go to the component directory and checkout the desired commit, i.e. ``cd ${COMPONENT} && git fetch && git checkout ${COMMIT})``.
4. Go back to the root directory and commit the changes, i.e. ``git add ${COMPONENT} && git commit -m "Update ${COMPONENT} to ${COMMIT}"``.
5. Push the changes to the remote repository.
