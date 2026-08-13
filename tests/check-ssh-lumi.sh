#!/usr/bin/env bash
set -e

# Smoke test for LUMI login node SSH connectivity.
# Verifies password-less SSH access and checks critical paths that
# Autosubmit jobs rely on.
#
# Requires ~/.ssh/config to contain an entry such as:
#   Host lumi-cluster
#       Hostname lumi.csc.fi
#       IdentityFile ~/.ssh/<your_sshkey>
#       User <lumi user>

LUMI_HOST="${LUMI_HOST:-lumi-cluster}"

echo "Checking SSH connectivity to ${LUMI_HOST}..."

if ! ssh -o BatchMode=yes -o ConnectTimeout=15 "${LUMI_HOST}" "echo 'SSH connection successful'" 2>/dev/null; then
    echo "ERROR: Cannot connect to ${LUMI_HOST}"
    echo "Ensure ~/.ssh/config has a 'Host lumi-cluster' entry with Hostname lumi.csc.fi"
    exit 1
fi

echo "SSH connection established"
echo ""

# Report the remote user and hostname so logs are informative
REMOTE_ID=$(ssh -o BatchMode=yes -o ConnectTimeout=15 "${LUMI_HOST}" "echo \"user=\$(whoami) host=\$(hostname)\"" 2>/dev/null || echo "unknown")
echo "Remote identity: ${REMOTE_ID}"
echo ""

echo "Checking required paths..."
required_paths=(
    "/pfs/lustref1"
    "/scratch"
    "/projappl"
)

paths_ok=true
for path in "${required_paths[@]}"; do
    if ssh -o BatchMode=yes -o ConnectTimeout=15 "${LUMI_HOST}" "test -d '${path}'" 2>/dev/null; then
        echo "  OK: ${path}"
    else
        echo "  MISSING: ${path}"
        paths_ok=false
    fi
done

if [ "${paths_ok}" = false ]; then
    echo ""
    echo "ERROR: Some required paths are missing on ${LUMI_HOST}"
    exit 1
fi

echo ""
echo "SUCCESS: LUMI login node is reachable and paths look good"
