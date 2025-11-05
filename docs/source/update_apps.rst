===========
Update apps
===========

When the applciation developer has a new feature or a fix to be added in the climateDT workflow, it has to follow these steps:

1. The application developer works on the source code of the application in their corresponding repository, normally in local with test data.

2. IMPORTANT STEP BEFORE TESTING ANYTHING IN THE WORKLFOW: the application MUST pass their unit tests to ensure that the possible errors that appear come from the workflow integration and not from the application itself.

3. Once the untit tests have passed, the app developer should create a tag (and potentially a release). Once there is a tag, the application can be tested inside the workflow through 2 different ways:
 
 3.1. (Recommended) Request A1 to create and deploy a container in the different HPC machines to be used by the workflow with the. Then the version of the application to be tested is just selectable via the workflow configuration. (conf/applciation/container_versions.yml). Then the application developer should run a short workflow to see if the application works without issues. If issues happen in this step, support will be provided from the workflow team. If the issue is on the workflow, the workflow team will take over. If the error is elsewhere, either A1 (containers) or the app developer will take over. Eentually if the error is on the app, the tag shoul be updated with the fix and the container rebuilt and redeployed.

 3.2. (Advanced solution, faster for testing) Use the application as submodule in the workflow. This solution involves modifying the workflow by adding the application as submodule. The source code in this case is taken by modifying the PYTHONPATH, while using an older version of the applciation to get the environment. This allows direct test of the application in the workflow, by modifying the source code in the HPC directly. If the tests are successful, the application developer should release a new tag and ask A1 to deploy the container, and go thruogh option 3.1.

4. Once the integration in (3) is completed, the application is run inside the workflow weekly testing suite, and if it is successful, the application is then included in the new workflow release.

### What if the app developer has to change not only the app source code but also some parts of the workflow repository?

Then you should open an issue in the workflow repository, and the workflow team will evaluate if the changes make sense at workflow level. If so, You can work on a branch that contains the issue number in the name (jsut click on "create merge request"). Eventually the workflow team will validate your changes and it will get into the workflow main branch.


