#!/bin/bash

set -xuve

# passing needed arguments
CURRENT_MHM_DIR=${1}
CURRENT_MRM_DIR=${2}
MRM_RESTART_DIR=${3}
INI_DATE=${4}
END_DATE=${5}
NEXT_DATE=${6}
STAT_FREQ=${7}
INIT_FILES=${8}
FORCINGS_DIR=${9}
MHM_FLUXES_DIR=${10}
HYDROLAND_DIR=${11}
MHM_FLUXES=${12}
RESOLUTION=${13}

# PATH to mrm grdc
export MRM_ARG_PATH="${INIT_FILES}/mrm/grdc"
# PATH to subdomain river masks
export MRM_NETWORK_DIR="${INIT_FILES}/mrm/subdomain_river_masks_${RESOLUTION}"
# PATH to id gauges
export MRM_ID_GAUGES_FILE="${INIT_FILES}/mrm/mrm_input"
export MRM_ARG_LIST=('1 3 "'"'${MRM_ARG_PATH}/1196100.day'"','"'${MRM_ARG_PATH}/1259151.day'"','"'${MRM_ARG_PATH}/1599100.day'"'" 1196100,1259151,1599100' '2 0 "'"'XXX'"'" 0' '3 0 "'"'XXX'"'" 0' '4 0 "'"'XXX'"'" 0' '5 0 "'"'XXX'"'" 0' '6 0 "'"'XXX'"'" 0' '7 3 "'"'${MRM_ARG_PATH}/1531100.day'"','"'${MRM_ARG_PATH}/1531450.day'"','"'${MRM_ARG_PATH}/1531550.day'"'" 1531100,1531450,1531550' '8 0 "'"'XXX'"'" 0' '9 1 "'"'${MRM_ARG_PATH}/1495700.day'"'" 1495700' '10 0 "'"'XXX'"'" 0' '11 1 "'"'${MRM_ARG_PATH}/2906300.day'"'" 2906300' '12 0 "'"'XXX'"'" 0' '13 3 "'"'${MRM_ARG_PATH}/2469120.day'"','"'${MRM_ARG_PATH}/2569005.day'"','"'${MRM_ARG_PATH}/2969101.day'"'" 2469120,2569005,2969101' '14 0 "'"'XXX'"'" 0' '15 1 "'"'${MRM_ARG_PATH}/2901201.day'"'" 2901201' '16 0 "'"'XXX'"'" 0' '17 3 "'"'${MRM_ARG_PATH}/2151100.day'"','"'${MRM_ARG_PATH}/2260100.day'"','"'${MRM_ARG_PATH}/2260500.day'"'" 2151100,2260100,2260500' '18 1 "'"'${MRM_ARG_PATH}/5224500.day'"'" 5224500' '19 0 "'"'XXX'"'" 0' '20 4 "'"'${MRM_ARG_PATH}/2907400.day'"','"'${MRM_ARG_PATH}/2908305.day'"','"'${MRM_ARG_PATH}/2909150.day'"','"'${MRM_ARG_PATH}/2909152.day'"'" 2907400,2908305,2909150,2909152' '21 3 "'"'${MRM_ARG_PATH}/2910300.day'"','"'${MRM_ARG_PATH}/2999200.day'"','"'${MRM_ARG_PATH}/2999500.day'"'" 2910300,2999200,2999500' '22 0 "'"'XXX'"'" 0' '23 1 "'"'${MRM_ARG_PATH}/2917920.day'"'" 2917920' '24 0 "'"'XXX'"'" 0' '25 1 "'"'${MRM_ARG_PATH}/4362600.day'"'" 4362600' '26 11 "'"'${MRM_ARG_PATH}/6116200.day'"','"'${MRM_ARG_PATH}/6123400.day'"','"'${MRM_ARG_PATH}/6221100.day'"','"'${MRM_ARG_PATH}/6242401.day'"','"'${MRM_ARG_PATH}/6335020.day'"','"'${MRM_ARG_PATH}/6335050.day'"','"'${MRM_ARG_PATH}/6337515.day'"','"'${MRM_ARG_PATH}/6421100.day'"','"'${MRM_ARG_PATH}/6421500.day'"','"'${MRM_ARG_PATH}/6545800.day'"','"'${MRM_ARG_PATH}/6973300.day'"'" 6116200,6123400,6221100,6242401,6335020,6335050,6337515,6421100,6421500,6545800,6973300' '27 1 "'"'${MRM_ARG_PATH}/6970100.day'"'" 6970100' '28 0 "'"'XXX'"'" 0' '29 0 "'"'XXX'"'" 0' '30 0 "'"'XXX'"'" 0' '31 0 "'"'XXX'"'" 0' '32 0 "'"'XXX'"'" 0' '33 4 "'"'${MRM_ARG_PATH}/6233201.day'"','"'${MRM_ARG_PATH}/6233410.day'"','"'${MRM_ARG_PATH}/6233502.day'"','"'${MRM_ARG_PATH}/6731400.day'"'" 6233201,6233410,6233502,6731400' '34 2 "'"'${MRM_ARG_PATH}/6854700.day'"','"'${MRM_ARG_PATH}/6854702.day'"'" 6854700,6854702' '35 0 "'"'XXX'"'" 0' '36 1 "'"'${MRM_ARG_PATH}/4214051.day'"'" 4214051' '37 0 "'"'XXX'"'" 0' '38 7 "'"'${MRM_ARG_PATH}/4102100.day'"','"'${MRM_ARG_PATH}/4103200.day'"','"'${MRM_ARG_PATH}/4103550.day'"','"'${MRM_ARG_PATH}/4103800.day'"','"'${MRM_ARG_PATH}/4203152.day'"','"'${MRM_ARG_PATH}/4203201.day'"','"'${MRM_ARG_PATH}/4203250.day'"'" 4102100,4103200,4103550,4103800,4203152,4203201,4203250' '39 8 "'"'${MRM_ARG_PATH}/4207310.day'"','"'${MRM_ARG_PATH}/4207900.day'"','"'${MRM_ARG_PATH}/4208005.day'"','"'${MRM_ARG_PATH}/4208150.day'"','"'${MRM_ARG_PATH}/4208270.day'"','"'${MRM_ARG_PATH}/4208271.day'"','"'${MRM_ARG_PATH}/4208280.day'"','"'${MRM_ARG_PATH}/4208730.day'"'" 4207310,4207900,4208005,4208150,4208270,4208271,4208280,4208730' '40 0 "'"'XXX'"'" 0' '41 1 "'"'${MRM_ARG_PATH}/4214520.day'"'" 4214520' '42 0 "'"'XXX'"'" 0' '43 0 "'"'XXX'"'" 0' '44 8 "'"'${MRM_ARG_PATH}/4119300.day'"','"'${MRM_ARG_PATH}/4123050.day'"','"'${MRM_ARG_PATH}/4123202.day'"','"'${MRM_ARG_PATH}/4123300.day'"','"'${MRM_ARG_PATH}/4123301.day'"','"'${MRM_ARG_PATH}/4125804.day'"','"'${MRM_ARG_PATH}/4126800.day'"','"'${MRM_ARG_PATH}/4127800.day'"'" 4119300,4123050,4123202,4123300,4123301,4125804,4126800,4127800' '45 2 "'"'${MRM_ARG_PATH}/4115345.day'"','"'${MRM_ARG_PATH}/4115346.day'"'" 4115345,4115346' '46 7 "'"'${MRM_ARG_PATH}/4147700.day'"','"'${MRM_ARG_PATH}/4149401.day'"','"'${MRM_ARG_PATH}/4149410.day'"','"'${MRM_ARG_PATH}/4149413.day'"','"'${MRM_ARG_PATH}/4149630.day'"','"'${MRM_ARG_PATH}/4149631.day'"','"'${MRM_ARG_PATH}/4149632.day'"'" 4147700,4149401,4149410,4149413,4149630,4149631,4149632' '47 6 "'"'${MRM_ARG_PATH}/5101200.day'"','"'${MRM_ARG_PATH}/5101301.day'"','"'${MRM_ARG_PATH}/5204103.day'"','"'${MRM_ARG_PATH}/5204301.day'"','"'${MRM_ARG_PATH}/5204302.day'"','"'${MRM_ARG_PATH}/5204401.day'"'" 5101200,5101301,5204103,5204301,5204302,5204401' '48 0 "'"'XXX'"'" 0' '49 3 "'"'${MRM_ARG_PATH}/5109151.day'"','"'${MRM_ARG_PATH}/5109200.day'"','"'${MRM_ARG_PATH}/5608096.day'"'" 5109151,5109200,5608096' '50 0 "'"'XXX'"'" 0' '51 3 "'"'${MRM_ARG_PATH}/3663655.day'"','"'${MRM_ARG_PATH}/3664160.day'"','"'${MRM_ARG_PATH}/3669600.day'"'" 3663655,3664160,3669600' '52 30 "'"'${MRM_ARG_PATH}/3618051.day'"','"'${MRM_ARG_PATH}/3618052.day'"','"'${MRM_ARG_PATH}/3618053.day'"','"'${MRM_ARG_PATH}/3618500.day'"','"'${MRM_ARG_PATH}/3618950.day'"','"'${MRM_ARG_PATH}/3618951.day'"','"'${MRM_ARG_PATH}/3620000.day'"','"'${MRM_ARG_PATH}/3621200.day'"','"'${MRM_ARG_PATH}/3622400.day'"','"'${MRM_ARG_PATH}/3623100.day'"','"'${MRM_ARG_PATH}/3624120.day'"','"'${MRM_ARG_PATH}/3624121.day'"','"'${MRM_ARG_PATH}/3624300.day'"','"'${MRM_ARG_PATH}/3625320.day'"','"'${MRM_ARG_PATH}/3625340.day'"','"'${MRM_ARG_PATH}/3625350.day'"','"'${MRM_ARG_PATH}/3625360.day'"','"'${MRM_ARG_PATH}/3625370.day'"','"'${MRM_ARG_PATH}/3627030.day'"','"'${MRM_ARG_PATH}/3627402.day'"','"'${MRM_ARG_PATH}/3627551.day'"','"'${MRM_ARG_PATH}/3627650.day'"','"'${MRM_ARG_PATH}/3628201.day'"','"'${MRM_ARG_PATH}/3629150.day'"','"'${MRM_ARG_PATH}/3629770.day'"','"'${MRM_ARG_PATH}/3629771.day'"','"'${MRM_ARG_PATH}/3629790.day'"','"'${MRM_ARG_PATH}/3630150.day'"','"'${MRM_ARG_PATH}/3630200.day'"','"'${MRM_ARG_PATH}/3631100.day'"'" 3618051,3618052,3618053,3618500,3618950,3618951,3620000,3621200,3622400,3623100,3624120,3624121,3624300,3625320,3625340,3625350,3625360,3625370,3627030,3627402,3627551,3627650,3628201,3629150,3629770,3629771,3629790,3630150,3630200,3631100' '53 1 "'"'${MRM_ARG_PATH}/3649412.day'"'" 3649412')
export OMP_NUM_THREADS=53 # SLURM_CPUS_PER_TASK --> change by number given in slurm request

# adding extra day to current mHM_Fluxes_States.nc if run daily
python3 ${HYDROLAND_DIR}/run_mhm/data_preparation.py --in_dir ${MHM_FLUXES_DIR} --in_file ${MHM_FLUXES} \
    --out_dir ${CURRENT_MRM_DIR} --out_file ${MHM_FLUXES} --stat_freq ${STAT_FREQ} --mRM TRUE
if [ "$STAT_FREQ" = "daily" ]; then
    MHM_OUTFILE="${CURRENT_MRM_DIR}/${MHM_FLUXES}"
else
    MHM_OUTFILE="${MHM_FLUXES_DIR}/${MHM_FLUXES}"
fi

# Extract components using parameter expansion.
# characters 0-3 for year, 5-6 for month, and 8-9 for day.
INI_YEAR="${INI_DATE:0:4}"
INI_MONTH="${INI_DATE:5:2}"
INI_DAY="${INI_DATE:8:2}"
END_YEAR="${END_DATE:0:4}"
END_MONTH="${END_DATE:5:2}"
END_DAY="${END_DATE:8:2}"

# --------------- creating nml for mrm
chmod 770 ./generate_mrm_nml.sh
./generate_mrm_nml.sh \
    "${INI_YEAR}" \
    "${INI_MONTH}" \
    "${INI_DAY}" \
    "${END_YEAR}" \
    "${END_MONTH}" \
    "${END_DAY}" \
    "${CURRENT_MRM_DIR}" \
    "${MRM_RESTART_DIR}" \
    "${MHM_OUTFILE}" \
    "${MRM_ARG_PATH}" \
    "${MRM_NETWORK_DIR}" \
    "${MRM_ID_GAUGES_FILE}" \
    "${STAT_FREQ}" \
    "${FORCINGS_DIR}" \
    "${NEXT_DATE}" \
    "${RESOLUTION}"
chmod 770 ${CURRENT_MRM_DIR}/run_parallel_mrm.sh

# -N $EC_tasks_per_node -n $EC_total_tasks -d $OMP_NUM_THREADS -j $EC_hyperthreads
# optional args to srun, did not try those yet: --ntasks=${SLURM_NTASKS} --ntasks-per-node=${SLURM_NTASKS_PER_NODE}
# --cpus-per-task=$OMP_NUM_THREADS --hint=nomultithread --dist=block:cyclic
python3 "${CURRENT_MRM_DIR}/parallel_mrm.py" \
    -e "${CURRENT_MRM_DIR}/run_parallel_mrm.sh" \
    -o "${CURRENT_MRM_DIR}" \
    --thr_glob $OMP_NUM_THREADS \
    --thr_prog 1 \
    --arg_list "${MRM_ARG_LIST[@]}"
