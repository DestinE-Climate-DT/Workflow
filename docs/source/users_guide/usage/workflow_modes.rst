Workflow modes
--------------


There are 4 modes of the workflow:

- ``model``: runs the model (ICON, IFS-FESOM, IFS-NEMO).
- ``end-to-end``: runs the model and the selected applications in a streaming fashion.
- ``applications``: runs the applications only by simulating the data streaming (``DN`` + ``OPA`` + ``APP``).
- ``simless``: runs the steps previous to the model without executing the SIM step. This is useful to run additional jobs (e.g. backup, transfer, etc.) and deal with data produced in a separate experiment.

They are controlled via the ``RUN.WORKFLOW`` key in the file ``main.yml`` and are used to define the workflow to be executed.
