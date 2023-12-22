#!/bin/bash

set -xuve

python3 run_lra.py -c only_lra.yaml
cd $1/$2/aqua/cli/aqua-analysis
bash aqua-analysis.sh

