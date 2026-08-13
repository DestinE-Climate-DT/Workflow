.. _nrt:

Near-real-time (NRT) runs
-------------------------

Near-real-time (NRT) refers to producing simulation output with minimal delay, advancing the model as soon as the input forcing data becomes available on a daily scale so that results are ready shortly after each simulated day rather than only once a full chunk has finished. This makes the data usable for time-sensitive applications that need to follow the simulation as it progresses.

NRT mode runs the model one simulation day at a time, dividing each chunk into daily Autosubmit splits (one split = one simulation day). It is only supported for IFS-FESOM.

To enable it, set the following in your ``main.yml``:

.. code-block:: yaml

    CONFIGURATION:
        NRT: "True"

This makes the ``SIM`` job split-aware: restarts are handled per split and only the chunk-boundary restart is backed up. No other change is needed for a ``model`` run.

For ``end-to-end`` runs, the ``DN`` job depends on the matching ``SIM`` split by default (``CONFIGURATION.DN: "True"``), so applications flow daily instead of waiting for the chunk's last split. To keep the standard chunk-level dependency instead, set:

.. code-block:: yaml

    CONFIGURATION:
        DN: "False"

Post-processing jobs (DQC, transfer, constant-variable fix)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

When the ``DQC``, ``TRANSFER``, and ``FIX_CONSTANT_VARIABLES`` jobs are enabled (``CONFIGURATION.ADDITIONAL_JOBS.*: "True"``), NRT also runs them per simulation day so that checked data is delivered shortly after each day completes rather than once the whole chunk has finished:

- ``DQC_BASIC`` runs once per ``SIM`` split, checking only that day's data.
- ``TRANSFER`` ships each day as soon as it passes ``DQC_BASIC``. Daily transfers within a chunk are serialized so they do not race on remote state or exceed datamover connection limits.
- ``FIX_CONSTANT_VARIABLES`` runs as soon as day 2 is simulated — instead of after the full first chunk — and back-fills the time-constant fields that the first day's check and transfer depend on.

Monthly-mean output (FDB stream ``clmn``) only lands in the FDB once a month is complete, so DQC and transfer handle it on the split that crosses the month boundary: ``DQC_BASIC`` re-checks the month's monthly profiles and ``TRANSFER`` ships the monthly means, both with the request widened back to the first day of that month.

This per-day behaviour is applied by per-job toggle files under ``conf/toggles/`` — ``dqc-True-nrt-True.yml``, ``transfer-True-nrt-True.yml``, and ``fix_constant_variables-True-nrt-True.yml``. Each is off by default and loaded only when both its job and NRT are enabled, i.e. ``CONFIGURATION.ADDITIONAL_JOBS.<JOB>`` and ``CONFIGURATION.NRT`` are both ``"True"``. Enable all three together: if any is left disabled, its override references a job that does not exist.

.. note::
   NRT is only supported for IFS-FESOM.
