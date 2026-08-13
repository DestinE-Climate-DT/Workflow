CICD Pipelines and Jacamar
==========================

This page documents the ClimateDT workflows repository's current CI/CD jobs, the
Jacamar-based CI testing suite, instructions to set them up for use, and basic
guidance on what to check when jobs fail.

.. note::

   Two different things in this repository are called a "testing suite":

   - the **CI testing suite** — the ``tsuite-*`` jobs described on this page, which
     run Autosubmit experiments from GitLab CI via Jacamar; and
   - the **testing_suite tool** — a separate CLI, documented in
     :doc:`testing_suite_setup`, run by hand from the shared ``tsuite1`` account.

   They are independent: the CI jobs call ``destine tsuite ...`` from ``wftools/``
   and never invoke ``testing_suite``.

1. CI/CD jobs
-------------

Overview
~~~~~~~~
- The pipeline stages are: smoke, lint, test, mirror, report. Jobs live in ``.gitlab-ci.yml`` and included files (``.gitlab/ci/*.yml``).
- Common lint jobs: ``shellcheck``, ``shfmt``, ``yamllint``, ``yamlfmt``, ``ruff``, ``templates_numeration``.
- Test jobs include: ``test-python``, ``test-shell``, ``coverage-shell``, ``test-preflight``, ``baseline-test``. A ``mirror_releases`` job runs on tags to push releases to GitHub.

How they work
~~~~~~~~~~~~~
- Jobs run according to the rules and stages defined in ``.gitlab-ci.yml``. Some jobs are automatic, others are manual (require human to click the play button in GitLab). Artifacts and reports (coverage, JUnit, code-quality) are published by the jobs where applicable.
- Variables control behaviour: ``TSUITE_TYPE``, ``TSUITE_AUTO``, ``TSUITE_TYPES_JSON`` influence the CI testing-suite flow.

Requirements to run jobs
~~~~~~~~~~~~~~~~~~~~~~~~
- Runners with appropriate tags (see ``default.tags`` in ``.gitlab-ci.yml``). The Jacamar jobs override this with ``tags: [jacamar]``, which is what routes them to the development Autosubmit VM.
- For some jobs (e.g. ``mirror_releases``) network tools and authentication are required (GitHub CLI token). Do not store secrets in repository docs.
- To run Jacamar/HPC jobs additional access (see Jacamar section) is necessary.

2. Jacamar jobs
---------------

What Jacamar is
~~~~~~~~~~~~~~~
Jacamar CI is the GitLab runner executor used on the development Autosubmit VM
(``climatedt-wf-dev1``): it runs each CI job as the GitLab user who triggered it, so
HPC access uses your own credentials rather than a shared service account. That is
why running these jobs requires being added to the Jacamar user mapping (see
section 3) rather than installing anything yourself.

The CI testing suite is built on top of it. Its ``tsuite-*`` jobs detect affected
experiment types from MR diffs, generate a child pipeline with one chain per type,
and require a human to start and approve the relevant chains.

Pipeline structure (high level)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- Parent pipeline: runs smoke/lint/test and orchestrates the Jacamar flow with ``tsuite-prepare`` (auto), ``tsuite-trigger`` (the single manual gate), an internal bridge (``_tsuite-launch``), ``tsuite-collect`` and ``tsuite-required`` (merge gate).
- Child pipeline: per-experiment-type chains. Chain stages: ``expid`` -> ``create`` -> ``run`` -> ``monitor`` -> ``delete``.
- A failed required chain preserves the experiment on the HPC for debugging instead of deleting it, and a manual ``force-delete-{type}`` job is provided to clean it up afterwards. Optional chains have no ``force-delete``: their ``delete`` job is manual and deletes unconditionally.

How experiment types are selected
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
``tsuite-prepare`` decides which experiments to run from the files your MR touches,
using the registry in ``tests/tsuite_config.yml``:

- ``path_rules`` maps a regex over changed paths to a set of tags. For example
  ``^templates/sim_ifs-fesom\.sh$`` activates the ``ifs-fesom`` tag, while core files
  such as ``lib/common/util.sh`` activate the special tag ``ALL``.
- ``experiment_types`` lists each type with its target HPC and its own tags. A type is
  selected ("detected") when its tags intersect the activated ones.

Detected types are **required**: they render in the ``required-*`` stages of the child
pipeline and gate the merge via ``tsuite-required``. Every other type that has templates
available is still generated, in the ``optional-*`` stages, but never blocks the MR.

To see what your branch would trigger before pushing:

.. code-block:: bash

   pip install .                                  # provides the destine CLI (wftools)
   git diff --name-only origin/main > changed_files.txt
   destine tsuite detect --file changed_files.txt --verbose

TSUITE_AUTO modes
~~~~~~~~~~~~~~~~~
- ``NONE``: every chain stays manual (default).
- ``REQUIRED``: required chains auto-run, optional remain manual.
- ``ALL``: all chains auto-run.

3. Instructions: how to set them up
-----------------------------------

Experiments run on the development Autosubmit VM (climatedt-wf-dev1)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- Jacamar experiments are executed from the development Autosubmit VM. This VM should be set up with the same SSH keys, service tokens, and configuration used by the main Autosubmit environment.
- Ensure the development Autosubmit VM has passwordless SSH access to the target HPC systems and datamovers, and that relevant environment files and credentials are present.
- Verify the VM can access GitLab with a valid ``.netrc`` entry before running Jacamar tests.

Essentially you have to set up the development Autosubmit VM (``climatedt-wf-dev1``)
the same way as the main Autosubmit VM.

1. Request access: Jacamar/HPC usage requires whitelisting. Contact the workflow team with your GitLab name and VM username to get passwordless SSH access to ``climatedt-wf-dev1`` and to be added to the Jacamar user mapping script.

   .. code-block:: text

      Host climatedt-wf-dev1
         HostName 217.71.194.230
         User <vm username>
         IdentityFile <path to private key>
         ForwardX11 yes
         ProxyJump <mn5 or lumi login nodes>

2. SSH and tokens: configure SSH keys and any service tokens on the dev VM consistent with the primary Autosubmit VM.

   - Passwordless access to the HPC systems under the SSH aliases ``lumi-cluster`` and ``mn5-cluster1`` (same as the regular Autosubmit VM). These are the names the smoke checks and the generated chains use; they can be overridden with ``$LUMI_HOST`` / ``$MN5_HOST``.
   - Passwordless access to the MN5 datamover (same as the regular Autosubmit VM). The SSH stanza and how to request access are in :ref:`mn5-datamover-access`.
   - Copy the LUMI-O (aws) configuration and credentials to the testing VM (same as the regular Autosubmit VM).

3. Configure ``.netrc`` on the testing VM so automated tools can authenticate with GitLab when running tests.

   .. code-block:: text

      machine gitlab.earth.bsc.es
      login <username>
      password <personal_access_token>

   In order to generate a personal access token, go to your GitLab profile -> Settings -> Access Tokens.
   Create a token with the ``read_repository`` scope and copy it to the ``.netrc`` file.

How to trigger Jacamar tests
~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- Open the MR. ``tsuite-prepare`` runs automatically and produces the child-pipeline artifact (``child-pipeline.yml``).
- Choose ``TSUITE_TYPE`` and ``TSUITE_AUTO`` from the drop-downs on the **Run pipeline** page (they are declared as top-level ``variables:`` in ``.gitlab-ci.yml``). This is the intended path: the values flow into both ``tsuite-prepare`` and the trigger, so the manual gate becomes a single click.
- Start ``tsuite-trigger`` with one "Run job" click. Its "Run with options" form is an override only — it shows blank Key/Value boxes with no drop-downs or help text (gitlab.com issue #426022), so use it only if you have to change ``TSUITE_AUTO`` at the gate itself.
- When the child pipeline is created, start the ``expid-*`` jobs for the required types (or let them auto-start, depending on ``TSUITE_AUTO``). The rest of each chain runs automatically.

Type selection precedence is ``TSUITE_TYPES_JSON`` > ``TSUITE_TYPE`` > auto-detection
from the MR diff.

Adding a new experiment type
~~~~~~~~~~~~~~~~~~~~~~~~~~~~
1. Add an entry to ``experiment_types`` in ``tests/tsuite_config.yml`` with a ``type`` name, a ``description``, the target ``hpc``, and the ``tags`` that should select it.
2. Add **both** templates in ``tests/tsuite_mains/``: ``tsuite-jacamar-main-<type>.yml`` (the experiment ``main.yml``) and ``tsuite-jacamar-minimal-<type>.yml`` (the Autosubmit ``minimal.yml`` bootstrap). If either is missing, ``tsuite-prepare`` skips the type and records it as a skipped JUnit case rather than failing, so the chain simply never appears.
3. Add a ``path_rules`` pattern if changes to a particular file should select the new type automatically.
4. Optionally add the name to the ``TSUITE_TYPE`` drop-down in ``.gitlab-ci.yml`` so it can be picked by hand.

The ``expid`` job patches ``EXPID``, ``PROJECT_BRANCH`` and ``PROJECT_ORIGIN`` in the
copied ``minimal.yml``, so the templates can keep static defaults for those three.

4. What to look for when CI/CD jobs fail
----------------------------------------

Immediate checks
~~~~~~~~~~~~~~~~
- Job logs: inspect the job log in GitLab for the failing job. The log often contains the precise error and failing command.
- Artifacts: check produced artifacts (JUnit XML, coverage, code-quality) for test failures or parse errors.
- Variables and rules: verify pipeline variables (``TSUITE_*``), branch/tag conditions, and runner tags match expected values.

In addition, most jobs that are not Jacamar-specific, such as the test-python, test-shell, or the baseline test are executed through the makefile targets in the ``Makefile``. If they fail, you can run the same commands locally to reproduce the failure and debug it.
Most of the time, the failure is due to and outdated configuration under the files in the ``tests/workflow_mock`` directory for baseline tests or due to missing parameters, or yaml key field restrictions in the schema files.

Jacamar-specific failures
~~~~~~~~~~~~~~~~~~~~~~~~~
- Smoke stage: these run first, as your own user, and are where someone who is not yet in the Jacamar user mapping fails. If any fail, revisit the access steps in section 3 before looking anywhere else.

  - ``identity-env-check``, ``token-check-lumi-o``, ``token-check-github``, ``token-check-gitlab`` gate ``tsuite-prepare`` — if one fails, nothing downstream runs.
  - ``ssh-check-lumi``, ``ssh-check-mn5``, ``ssh-check-lumi-to-mn5``, ``datamover-check-mn5`` check connectivity. They do not gate the suite, but a failure here points straight at the passwordless-SSH or datamover setup from section 3, step 2.
- ``tsuite-prepare``: check artifacts (``child-pipeline.yml``) to confirm detected experiment types and template validation messages.
- ``tsuite-trigger``: ensure ``TSUITE_AUTO`` is set as intended. If manual, the reviewer must start the ``expid-*`` jobs in the child pipeline.
- ``expid-*`` jobs: check that the testing VM / runner has access to the HPC system, SSH keys are valid, and ``.netrc`` is configured. Examine Autosubmit output in the job log (expid allocation, template install, create/run steps).
- ``tsuite-collect`` / ``tsuite-required``: if the merge gate fails, confirm a JUnit file exists for each required type under ``reports/`` and that no failures are present in the XML.

Debugging a failed experiment
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Each chain allocates a fresh test-case expid (``autosubmit expid --testcase``) described
as ``CI <pipeline-id> type <type>``, so you can identify yours from the pipeline ID. When
a required chain fails, the experiment is deliberately **not** deleted:

- Pipeline: the ``create-*``, ``run-*`` and ``monitor-*`` job logs of the chain, plus the ``monitor`` job artifacts (``reports/tsuite-monitor.xml``, ``reports/metrics.txt``). This is where a Jacamar experiment is followed.
- Experiment directory: ``/appl/AS/AUTOSUBMIT_DATA/<expid>`` on ``climatedt-wf-dev1``.
- Autosubmit logs: ``/appl/AS/AUTOSUBMIT_DATA/<expid>/tmp/LOG_<expid>`` on ``climatedt-wf-dev1``.

.. note::

   These experiments do **not** appear in the Autosubmit GUI at
   ``https://climatedt-wf.csc.fi``: that GUI serves the main Autosubmit VM, while the
   chains allocate their expids on the development VM (``climatedt-wf-dev1``), which has
   its own Autosubmit database and no GUI. Inspect them from the pipeline, or over SSH on
   the development VM.

When you have finished investigating, click the manual ``force-delete-{type}`` job to
reclaim it. Note that the ``run`` job has a 12 h timeout: a chain that outruns it is
killed and the experiment is preserved the same way.

Common remedies
~~~~~~~~~~~~~~~
- Rerun the failing job after fixing the issue (commit or pipeline variable).
- For authentication issues: verify SSH keys, tokens, and ``.netrc`` entries on the testing VM. Rotate or recreate credentials via the project's secrets management when needed — do not publish them in docs.
- For missing templates: ensure the template files are present in the repository and that ``tsuite-prepare`` validation passes.
- For flaky HPC runs: re-run the experiment chain; if failures persist, gather JUnit and Autosubmit logs and open an issue with the team.

More information and further reading
------------------------------------
- See ``.gitlab-ci.yml`` and ``.gitlab/ci/jacamar-*.yml`` for implementation details.
- Internal issue discussions and guidelines (project-specific) contain more operational notes; don't expose secrets when following them.
