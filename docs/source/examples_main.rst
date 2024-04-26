==============
Main Examples
==============

Model-only workflow, running low resolution IFS-NEMO in cpu
=====================================================================================
.. code-block:: yaml

    RUN:
        WORKFLOW: model
        ENVIRONMENT: cray
        PROCESSOR_UNIT: cpu

    MODEL: 
        NAME: ifs-nemo
        SIMULATION: test-ifs-nemo
        GRID_ATM: tco79l137
        GRID_OCE: eORCA1_Z75
        VERSION: DE_CY48R1.0_climateDT_20240215


    CONFIGURATION:
        INPUTS: "experiment/scenario-20y-2020-debug-configuration-2y-coupled-spinup"

    EXPERIMENT:
        DATELIST: 20200101



Applications-only workflow, reading data from a0h3 with Urban and Aqua applications
=====================================================================================
.. code-block:: yaml

    RUN:
    WORKFLOW: apps
    ENVIRONMENT: cray
    PROCESSOR_UNIT: cpu

    APP:
    NAMES: "[URBAN, AQUA]"
    OUTPATH: "/scratch/project_465000454/tmp/%DEFAULT.EXPID%/"
    READ_EXPID: a0h3

    EXPERIMENT:
    DATELIST: 20200101 #Startdate
    MEMBERS: fc0
    CHUNKSIZEUNIT: day
    CHUNKSIZE: 15
    NUMCHUNKS: 1
    CALENDAR: standard



End-to-end workflow, running IFS-NEMO in cpu with Urban, Mhm and Aqua applications
=====================================================================================
.. code-block:: yaml

    RUN:
        WORKFLOW: end-to-end
        ENVIRONMENT: cray
        CLEAN_RUN: true
        PROCESSOR_UNIT: cpu

    MODEL: 
        NAME: ifs-nemo
        SIMULATION: test-ifs-nemo
        GRID_ATM: tco79l137
        GRID_OCE: eORCA1_Z75
        VERSION: DE_CY48R1.0_climateDT_20240215

    APP:
        NAMES: "MHM, WILDFIRES_FWI, AQUA"
        OUTPATH: "/scratch/project_465000454/tmp/%DEFAULT.EXPID%/"

    JOBS:
        SIM:
            WALLCLOCK: "00:10"
            NODES: 4


    EXPERIMENT:
        DATELIST: 20180101 #Startdate
        MEMBERS: fc0
        CHUNKSIZEUNIT: month
        CHUNKSIZE: 1
        NUMCHUNKS: 3
        CALENDAR: standard

    CONFIGURATION:
        INPUTS: "experiment/coupled-spinup-2y-2018-debug-configuration"
