#!/bin/bash

set -xuve

python3 cli_lra_workflow.py -c only_lra.yaml -d
cd $1/$2/aqua/cli/aqua-analysis

bash aqua-analysis.sh --exp "${AQUA_EXP}" --source "${AQUA_SOURCE}" --outputdir "${HPCROOTDIR}/aqua_test" --machine "${CURRENT_ARCH,,}" --loglevel "DEBUG"
