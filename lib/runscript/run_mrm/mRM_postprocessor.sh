#!/bin/bash

set -xuve 

# passing arguments needed
HPCROOTDIR=$1
PROJDEST=$2
start_year=$3
start_month=$4
start_day=$5

# mRM working directories
export WORK_DIR="$HPCROOTDIR/$PROJDEST/lib/runscript/run_mrm"
# mRM restart files dir
export RESTART_DIR="${WORK_DIR}/restart_files"

# merging all mRM subdomains
DATE="${start_year}_${start_month}_${start_day}"
out_file="${WORK_DIR}/final_results/mRM_Fluxes_States_${DATE}.nc"
for subdomain_id in {1..52}; do   
    if [[ "${subdomain_id}" == '1' ]]; then
        first_file=./subdomain_${subdomain_id}/output/mRM_Fluxes_States.nc
        second_file=./subdomain_$((subdomain_id+1))/output/mRM_Fluxes_States.nc
        cdo mergegrid ${first_file} ${second_file} ${out_file}
    else
        infile=./subdomain_$((subdomain_id+1))/output/mRM_Fluxes_States.nc
        cdo mergegrid ${infile} ${out_file} ${out_file}_bak && mv ${out_file}_bak ${out_file}
    fi
done

# updating subdomains for next time step
for subdomain_id in {1..52}; do  
   cp -f ${WORK_DIR}/subdomain_${subdomain_id}/output/mRM_restart_001.nc ${RESTART_DIR}/subdomain_${subdomain_id}/
done
