#!/bin/bash

set -xuve

# Passing arguments needed
out_dir=${1}
resolution=${2}

# Create the header.txt file based on resolution
if [ "$resolution" == "0.1" ]; then
    ncols=3600
    nrows=1400
    cellsize=0.1
elif [ "$resolution" == "0.05" ]; then
    ncols=7200
    nrows=2800
    cellsize=0.05
else
    echo "Error: Unsupported resolution '$resolution'. Supported values are '0.1' and '0.05'."
    exit 1
fi

# Write the header.txt file
cat <<EOF >"${out_dir}/header.txt"
ncols         ${ncols}
nrows         ${nrows}
xllcorner     -180
yllcorner     -56
cellsize      ${cellsize}
NODATA_value  -9999
EOF
