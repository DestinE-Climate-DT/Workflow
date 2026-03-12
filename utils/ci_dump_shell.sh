#!/usr/bin/env bash
set -euo pipefail
echo "Dumping CI environment variables and PATH"
env | sort
echo "PATH as currently ordered:"
echo "PATH=$PATH" | tr ':' '\n'
echo ""
CI_OPEN_MERGE_REQUESTS=digital-twins/de_340-2/workflow!1025
echo "Thanks for debugging with the shell......"
