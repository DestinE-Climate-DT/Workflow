#!/bin/bash

set -vx
exp_id=$1  #experiment used for the transfer to the bridge eg: a17o
model=$2   #model name eg:IFS-NEMO
exp=$3     #real name of the experiment eg: scenario (used only for reporting)
sim_exp=$4 #autosubmit expid used for the simulation eg: a0py

#This script is meant to be run on the Autosubmit VM on Lumi. For a given autosubmit expid, it checks the autosubmit logs and reports potential gaps in what was sent, in addition to th last transferred chunk. The report is in table format to be included in the description of https://earth.bsc.es/gitlab/digital-twins/de_340/project_management/-/issues/664
#The function check_completion can be used to determine if a chunk is completed or not.

#./check_bridge.bash a11y IFS-NEMO historical a0h3
#./check_bridge.bash a17o IFS-NEMO scenario a0py

cd /appl/AS/AUTOSUBMIT_DATA/$exp_id/tmp/

function check_completion() {

    chunk=$1
    exp_id=$2
    out=""
    complete="FALSE"
    if [[ ! -f /appl/AS/AUTOSUBMIT_DATA/$exp_id/tmp/${exp_id}_${as_sd}_${chunk}_TRANSFER_COMPLETED ]]; then
        complete="FALSE"
    else
        out=$(ls /appl/AS/AUTOSUBMIT_DATA/$exp_id/tmp/LOG_${exp_id}/${exp_id}_${as_sd}_${chunk}_TRANSFER.*.out | tail -1)
        if [[ -n $out ]]; then
            if [[ -n $(grep "NOT SUCCESSFUL" $out) ]]; then
                complete="FALSE"
            else
                complete="TRUE"
            fi
        else
            complete="FALSE"
        fi
    fi
}

as_sd=$(ls /appl/AS/AUTOSUBMIT_DATA/$exp_id/tmp/${exp_id}_*TRANSFER*COMPLETED | awk -F"/" '{print $NF}' | head -1 | cut -f2-3 -d"_")
last_log_completed=$(ls /appl/AS/AUTOSUBMIT_DATA/$exp_id/tmp/${exp_id}_${as_sd}_*TRANSFER*COMPLETED | awk -F"/" '{print $NF}' | cut -f4 -d"_" | sort -n | tail -1)
last_date=$(grep "START_DATE=" /appl/AS/AUTOSUBMIT_DATA/$exp_id/tmp/${exp_id}_${as_sd}_${last_log_completed}_TRANSFER.cmd | tail -1 | awk -F"/" '{print $NF}' | cut -f2 -d"-" | cut -c1-8)

missing=""
results=""
for i in $(seq 1 $last_log_completed); do
    check_completion $i $exp_id
    if [[ $complete == FALSE ]]; then
        date=$(grep "START_DATE=" /appl/AS/AUTOSUBMIT_DATA/$exp_id/tmp/${exp_id}_${as_sd}_${i}_TRANSFER.cmd | tail -1 | awk -F"/" '{print $NF}' | cut -f2 -d"-" | cut -c1-8)
        results+="$i ($date),"
    else
        last_completed=$i
        last_date=$(grep "START_DATE=" /appl/AS/AUTOSUBMIT_DATA/$exp_id/tmp/${exp_id}_${as_sd}_${i}_TRANSFER.cmd | tail -1 | awk -F"/" '{print $NF}' | cut -f2 -d"-" | cut -c1-8)

    fi
done

chunk_size=$(grep "CHUNKSIZE:" /appl/AS/AUTOSUBMIT_DATA/$exp_id/conf/main.yml | cut -f2 -d":")
echo "| $model  | $exp |      $sim_expid            |    $exp_id            |      $last_completed ($last_date)                   |   $results        |     $chunk_size days       |"
