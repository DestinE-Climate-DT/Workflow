# Baseline Tests

For the purpose of testing the workflow on merge requests, the baseline tests automatically create a set of predefined experiments using the merge request's source branch and comparing them against the target branch (via `$CI_MERGE_REQUEST_TARGET_BRANCH_NAME`). The job only compares to the target branch in merge-request pipelines. If there is no associated merge request, the running branch is compared against `main`. The baseline tests use Autosubmit to create the experiments inside a Docker image run by a GitLab runner.

The comparison covers every file Autosubmit generates in the experiment's `tmp/` directory, not just the `.cmd` job scripts: the additional files listed after the first entry of a job's `FILE:` (the FDB configs, the AQUA catalog config, ...) are diffed too. Use `--extensions` and/or `--expected_scripts` to narrow a local run; left empty, as the CI job leaves them, nothing is filtered out.

## TODO
