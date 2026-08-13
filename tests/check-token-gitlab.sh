#!/usr/bin/env bash
set -e

# Smoke test for BSC GitLab HTTPS access.
#
# Uses 'git ls-remote' — the same credential path Autosubmit uses to clone
# the workflow repo.  Requires ~/.netrc to have an entry for GITLAB_HOST:
#
#   machine gitlab.earth.bsc.es
#       login <username>
#       password <personal_access_token>
#
# The PAT needs 'read_repository' scope (sufficient for clone/fetch).
# Create one at: https://gitlab.earth.bsc.es/-/profile/personal_access_tokens

GITLAB_HOST="${GITLAB_HOST:-gitlab.earth.bsc.es}"
GITLAB_REPO="${GITLAB_REPO:-https://${GITLAB_HOST}/digital-twins/de_340-2/workflow.git}"

echo "Testing BSC GitLab HTTPS access to ${GITLAB_HOST}..."
echo "  repo: ${GITLAB_REPO}"
echo ""

# ── Check ~/.netrc has an entry for this host ────────────────────────────────
netrc_file="${HOME}/.netrc"
if [ ! -f "${netrc_file}" ]; then
    echo "ERROR: ~/.netrc not found"
    echo "Create it with:"
    echo "  machine ${GITLAB_HOST}"
    echo "  login <username>"
    echo "  password <personal_access_token>"
    exit 1
fi

if ! grep -q "machine ${GITLAB_HOST}" "${netrc_file}"; then
    echo "ERROR: no 'machine ${GITLAB_HOST}' entry found in ~/.netrc"
    echo "Add:"
    echo "  machine ${GITLAB_HOST}"
    echo "  login <username>"
    echo "  password <personal_access_token>"
    exit 1
fi

# ── Test credentials with git ls-remote (same path Autosubmit uses) ──────────
# GIT_TERMINAL_PROMPT=0 prevents git from hanging waiting for interactive input.
echo "Running: git ls-remote ${GITLAB_REPO}"
if GIT_TERMINAL_PROMPT=0 git ls-remote "${GITLAB_REPO}" >/dev/null 2>&1; then
    echo ""
    echo "SUCCESS: BSC GitLab HTTPS credentials are valid"
else
    echo ""
    echo "ERROR: 'git ls-remote' failed for ${GITLAB_REPO}"
    echo "Possible causes:"
    echo "  - PAT is expired or invalid"
    echo "  - PAT lacks 'read_repository' scope"
    echo "  - ~/.netrc hostname does not match (check 'machine' line)"
    echo ""
    echo "Renew PAT at: https://${GITLAB_HOST}/-/profile/personal_access_tokens"
    echo "Then update ~/.netrc accordingly."
    exit 1
fi
