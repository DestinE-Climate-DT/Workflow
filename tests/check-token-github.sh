#!/usr/bin/env bash
set -e

# Check for GitHub SSH access
# This validates SSH authentication for cloning repositories like:
# git@github.com:DestinE-Climate-DT/Climate-DT-catalog.git
echo "Testing GitHub SSH connection..."
ssh_output=$(ssh -T git@github.com -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 2>&1) || true
if echo "$ssh_output" | grep -q "successfully authenticated"; then
    echo "SUCCESS: GitHub SSH authentication is valid"
    echo "$ssh_output" | head -n 1
else
    echo "ERROR: GitHub SSH authentication failed"
    echo "Please ensure:"
    echo "  1. Your SSH key is added to your GitHub account"
    echo "  2. ssh-agent is running with your key loaded"
    echo "  3. GitHub is reachable from this network"
    echo ""
    echo "Test manually with: ssh -T git@github.com"
    exit 1
fi
