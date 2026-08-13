#!/usr/bin/env bash
set -e

# Smoke test: SSH from the dev VM → LUMI → MN5 login node.
# Validates the hop the SYNC_LRA job uses to collect LRA output from both
# LUMI and MN5 runs into the central LRA store on LUMI — for an MN5 run,
# LUMI pulls the LRA from MN5 over this hop.
#
# ─── Prerequisites ──────────────────────────────────────────────────────────
# On the dev VM (climatedt-wf-dev1):
#   ~/.ssh/config must have a 'Host lumi-cluster' entry.
#
# On LUMI (~/.ssh/ of your LUMI user):
#   1. An SSH key pair for MN5, e.g. ~/.ssh/id_ed25519_bsc
#   2. ~/.ssh/config (or equivalent) that can reach glogin1.bsc.es:
#        Host mn5-cluster1
#            Hostname glogin1.bsc.es
#            IdentityFile ~/.ssh/id_ed25519_bsc
#            User <bsc_username>
#   3. The PUBLIC key must be added to MN5's ~/.ssh/authorized_keys.
#      On MN5 run:
#        echo "<contents of ~/.ssh/id_ed25519_bsc.pub from LUMI>" \
#             >> ~/.ssh/authorized_keys
#      or use:
#        ssh-copy-id -i ~/.ssh/id_ed25519_bsc.pub <bsc_user>@glogin1.bsc.es
# ────────────────────────────────────────────────────────────────────────────

LUMI_HOST="${LUMI_HOST:-lumi-cluster}"
# Use the Host alias defined in LUMI's ~/.ssh/config (e.g. mn5-cluster1)
# so the correct User and IdentityFile are picked up automatically.
# Override with the raw hostname (glogin1.bsc.es) only if no alias is configured.
MN5_FROM_LUMI_HOST="${MN5_FROM_LUMI_HOST:-mn5-cluster1}"

echo "=== Cross-HPC SSH check: dev VM → LUMI → MN5 ==="
echo "Hop 1: dev VM → ${LUMI_HOST}"
echo "Hop 2: ${LUMI_HOST} → ${MN5_FROM_LUMI_HOST}"
echo ""

# ── Hop 1: dev VM → LUMI ────────────────────────────────────────────────────
echo "Checking SSH connectivity to ${LUMI_HOST}..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=15 "${LUMI_HOST}" \
    "echo 'Hop 1 OK'" 2>/dev/null; then
    echo "ERROR: Cannot reach ${LUMI_HOST} from the dev VM"
    echo "Ensure ~/.ssh/config has a 'Host lumi-cluster' entry with Hostname lumi.csc.fi"
    exit 1
fi
echo "Hop 1 OK: reached ${LUMI_HOST}"
echo ""

# ── Hop 2: LUMI → MN5 ───────────────────────────────────────────────────────
echo "Checking SSH connectivity from ${LUMI_HOST} to ${MN5_FROM_LUMI_HOST}..."
# Capture output into a variable so we can inspect it independently of the
# SSH exit code.  The inner ssh on LUMI writes to LUMI's stdout, which
# becomes the outer SSH's stdout and lands in $hop2_out.
hop2_out=$(ssh -o BatchMode=yes -o ConnectTimeout=15 "${LUMI_HOST}" \
    "ssh -o BatchMode=yes -o ConnectTimeout=15 \
         -o StrictHostKeyChecking=accept-new \
         '${MN5_FROM_LUMI_HOST}' 'echo hop2_ok'" 2>&1) || true

if echo "${hop2_out}" | grep -q "hop2_ok"; then
    echo "Hop 2 OK: ${LUMI_HOST} → ${MN5_FROM_LUMI_HOST}"
else
    echo ""
    echo "ERROR: Cannot SSH from ${LUMI_HOST} to ${MN5_FROM_LUMI_HOST}"
    echo "SSH output:"
    echo "${hop2_out}"
    echo ""
    echo "To fix this, on LUMI:"
    echo "  1. Generate (or reuse) an SSH key pair for MN5:"
    echo "       ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_bsc"
    echo "  2. Copy the public key to MN5's authorized_keys:"
    echo "       ssh-copy-id -i ~/.ssh/id_ed25519_bsc.pub <bsc_user>@glogin1.bsc.es"
    echo "     or manually append ~/.ssh/id_ed25519_bsc.pub to"
    echo "     ~/.ssh/authorized_keys on MN5."
    echo "  3. Add a Host alias to LUMI's ~/.ssh/config (so 'ssh mn5-cluster1'"
    echo "     works without specifying User/IdentityFile each time):"
    echo "       Host mn5-cluster1"
    echo "           Hostname glogin1.bsc.es"
    echo "           IdentityFile ~/.ssh/id_ed25519_bsc"
    echo "           User <bsc_username>"
    exit 1
fi
echo "SUCCESS: Cross-HPC SSH hop LUMI → MN5 is working"
