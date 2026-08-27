# Baseline Tests

For the purpose of testing the workflow on merge requests, the baseline tests automatically create a set of predefined experiments using the merge request's source branch and comparing them against the target branch (via `$CI_MERGE_REQUEST_TARGET_BRANCH_NAME`). The job only compares to the target branch in merge-request pipelines. If there is no associated merge request, the running branch is compared against `main`. The baseline tests use Autosubmit to create the experiments inside a Docker image run by a GitLab runner.

## TODO
