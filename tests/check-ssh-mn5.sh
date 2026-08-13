#!/usr/bin/env bash
set -e

# Smoke test for MareNostrum5 login node SSH connectivity.
# Verifies password-less SSH access and checks critical paths that
# Autosubmit jobs rely on.
#
# Requires ~/.ssh/config to contain an entry such as:
#   Host mn5-cluster1
#       Hostname glogin4.bsc.es
#       IdentityFile ~/.ssh/<your_sshkey>
#       User <bsc user>
#
# Note: glogin4 is used because it allows internet access.

MN5_HOST="${MN5_HOST:-mn5-cluster1}"

echo "Checking SSH connectivity to ${MN5_HOST}..."

if ! ssh -o BatchMode=yes -o ConnectTimeout=15 "${MN5_HOST}" "echo 'SSH connection successful'" 2>/dev/null; then
    echo "ERROR: Cannot connect to ${MN5_HOST}"
    echo "Ensure ~/.ssh/config has a 'Host mn5-cluster1' entry pointing to glogin4.bsc.es"
    exit 1
fi

echo "SSH connection established"
echo ""

# Report the remote user and hostname so logs are informative
REMOTE_ID=$(ssh -o BatchMode=yes -o ConnectTimeout=15 "${MN5_HOST}" "echo \"user=\$(whoami) host=\$(hostname)\"" 2>/dev/null || echo "unknown")
echo "Remote identity: ${REMOTE_ID}"
echo ""

echo "Checking required paths..."
required_paths=(
    "/gpfs/projects"
    "/gpfs/scratch"
)

paths_ok=true
for path in "${required_paths[@]}"; do
    if ssh -o BatchMode=yes -o ConnectTimeout=15 "${MN5_HOST}" "test -d '${path}'" 2>/dev/null; then
        echo "  OK: ${path}"
    else
        echo "  MISSING: ${path}"
        paths_ok=false
    fi
done

if [ "${paths_ok}" = false ]; then
    echo ""
    echo "ERROR: Some required paths are missing on ${MN5_HOST}"
    exit 1
fi

echo ""
echo "SUCCESS: MN5 login node is reachable and paths look good"
