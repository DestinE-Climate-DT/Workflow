# Running Hydroland application within the workflow

This guide will not cover how to generally create an experiment using Autosubmit & how to get access to the Virtual Machine (VM). For more information related to that, please visit the [ Workflow - Getting Started](https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/tree/main#documentation) section in the main workflow repository, and [How to access to the VM](https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+Virtual+Machine).

Instead, this short guide is intended to show how to execute the Hydroland application within the workflow and explain how it works.

## Running Hydroland

In this example, we will execute Hydroland on [LUMI HPC](https://docs.lumi-supercomputer.eu) using historic data from [IFS-NEMO](https://www.ecmwf.int/en/elibrary/75709-coupling-nemo-and-ifs-models-single-executable). After creating your experiment with minimal configurations, the following files located at `/appl/AS/AUTOSUBMIT_DATA/${exp_id}/conf` must be edited.

1. **main.yml**: Running Hydroland for one month starting at 1991-01-01
```
ENVIRONMENT: cray
  CLEAN_RUN: true
  PROCESSOR_UNIT: cpu
  TYPE: "production"

APP:
  NAMES: ['HYDROLAND']
  READ_FROM_DATABRIDGE: "true"
  OUTPATH: "/scratch/project_465000454/tmp/%DEFAULT.EXPID%/"

EXPERIMENT:
   DATELIST: 19910101
   MEMBERS: fc0
   CHUNKSIZEUNIT: month
   SPLITSIZEUNIT: day
   CHUNKSIZE: 1
   NUMCHUNKS: 1
   CALENDAR: standard

# optional to change the partition and SLURM parameters for the application
PLATFORMS:
  LUMI:
    TYPE: slurm
    APP_PARTITION: debug
    CUSTOM_DIRECTIVES: "['#SBATCH --time=00:15:00']"
```

**request.yml**: Selecting the wanted Climate DT model data, in this case IFS-NEMO Historic high resolution data. For more info about Climate DT data [see here](https://confluence.ecmwf.int/display/DDCZ/Climate%20DT%20overview). Short name of variable available [here](https://earth.bsc.es/gitlab/digital-twins/de_340-2/gsv_interface/-/blob/main/gsv/requests/shortname_to_paramid.yaml). More information about the [GSV request](https://earth.bsc.es/gitlab/digital-twins/de_340-2/gsv_interface/-/wikis/GSV-request-syntax).
```
REQUEST:
  EXPERIMENT: hist
  ACTIVITY: baseline
  RESOLUTION: high
  REALIZATION: 1
  GENERATION: 2
  MODEL: ifs-fesom
  ```

  By default Hydroland will be executed on daily time-steps, using variable short names `tp` and `2t`, and running at a `0.1` grid resolution without executing Bias adjustment. However, this can be changed by accessing the file at `/appl/AS/AUTOSUBMIT_DATA/${exp_id}/proj/git_project/conf/mother_request.yml` and modify Hydroland section (see comments (#) below):
  ```HYDROLAND:
  1:
    GSVREQUEST:
      .
      .
      .
      param: "2t"                               # change if needed
      grid: "0.1/0.1" # change if needed
      method: nn
    OPAREQUEST:
      # Hardcoded parameters:
      variable: "2t"
      stat: "raw"                               # raw for hourly, mean for daily
      bias_adjustment: none                     # True or None
      stat_freq: "hourly"                       # daily or hourly
     .
     .
     .
 2:
    GSVREQUEST: #raw data
      .
      .
      .
      param: "tp"                               # change if needed
      grid: "0.1/0.1"                           # change if needed
      method: nn
    OPAREQUEST:
      # Hardcoded parameters:
      variable: "tp"
      stat: "raw"                               # raw for hourly, mean for daily
      bias_adjustment: none                     # True or None
      stat_freq: "hourly"                       # daily or hourly
     .
     .
     .
  ```

After that you should create and run the experiement as explained in the [Getting Started guide](https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/tree/main#documentation) and execute hydroland.

Climate DT has a Autosubmit [visualization website](https://climatedt-wf.csc.fi) were all experiments can be seen.

For more detailed & general data please go to the [workflow wiki page}(https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/wikis/home).

## Hydroland structure

- All final results will be store in `${OUT_PATH}`, which will change depending on the HPC you are using. In lumi the current path is `/scratch/project_465000454/tmp/${exp_id}`. However, this will change as the workflow develops.
- the current structure run hydroland output is shown below. Nevertheless, the folders `current_run` and their content wil lbe deleted and the end of all hydroland execution since they will not longer needed
```
.${OUT_PATH}
├── forcings
└── hydroland
        mhm/
            log_files/
            restart_files/
            current_run/
                input/
                    meteo/
                    restart/
                output/
            fluxes/
        mrm/
            log_files/
                subdomain_1/
                subdomain_2/
                ...
                subdomain_53/
            restart_files/
                subdomain_1/
                subdomain_2/
                ...
                subdomain_53/
            current_run/
            fluxes/
```
- In order to be executed, Hydroland uses so-called `restart files` to store all the initial data. These `restart files` can take up to `3GB` for each time step, which, in a long execution, could lead to memory issues. Furthermore, `log files` and `forcing files` are also created at every time step. To avoid memory issues, Hydroland will keep a single set of files per month (`restart, log, and forcing files`), plus the current and previous files being used if Hydroland has not been completely executed. This way, we maintain restart capabilities while reducing memory storage as much as possible.

- The location of these {re-start files} also change depending on the HPC. For LUMI: `/project/project_465000454/applications/hydroland` and for MN5: `/gpfs/projects/ehpc01/applications/hydroland`.

- The re-start and forcing files for Hydroland will be deleted for time step `n-1` if time step `n` is successfully completed, except for the first and last days of the month. This ensures that the user always keeps at least two re-start files per month, along with the re-start files for the two most recent time steps, in case the workflow stops unexpectedly. This approach allows Hydroland to resume from where it left off or restart from the beginning of any previously executed month. For example, if the run fails on 2020-03-27, the user can re-run the workflow from 2020-03-26 or 2020-03-01. At the same time, if a user runs hydroland until `X` date, the user could later continue the run if data availabe and start the new run from date `X+1`.

# Future upgrates

Within the plans for Hydroland there are three main goal to be integrated before February 2025:
1. Integration of Bias adjusted data before lunching hydroland application.
2. Integration of the indicators scripts.
3. Separation of mHM and mRM jobs to reduce Hydroland execution time.
4. Adding funtionality to run Hydroland with monthly chunks, instead of only daily chunks.
