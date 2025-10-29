## Configuration section

Schema for the configuration section of the workflow

| Property | Type | Required | Possible Values | Deprecated | Default | Description |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- |
| ADDITIONAL_JOBS | `object` | ✅ | object|  |  |  |
| CONTAINER_DIR | `string` |  | string|  | `"%CURRENT_HPC_PROJECT_ROOT%/%CURRENT_PROJECT%/containers"` | Path to the directory where the containers are stored. |
| PROJECT_SCRATCH | `string` |  | string|  | `"%CURRENT_SCRATCH_DIR%/%CURRENT_PROJECT%"` | Path to the directory where the project's scratch is stored. |
| LIBDIR | `string` |  | string|  | `"%HPCROOTDIR%/%PROJECT.PROJECT_DESTINATION%/lib"` | Path to the directory where the lib directory is, inside the repo. |
| SCRIPTDIR | `string` |  | string|  | `"%HPCROOTDIR%/git_project/runscripts"` | Path to the directory where the runscripts are stored. |
| HPC_PROJECT_DIR | `string` |  | string|  | `"%CURRENT_HPC_PROJECT_ROOT%/%CURRENT_PROJECT%"` | Path to the directory under `projects` (not scratch) of the HPC project in use. |
| FDB_DIR | `string` |  | string|  | `"%CURRENT_SCRATCH_DIR%/%CURRENT_PROJECT%/experiments"` | Path to the experiments folder of the project. It is used by `research` and `test` experiments. |
| IO_ON | `string` |  | `False` `True`|  |  | False will disable the flags for IO in order to run without output in IFS-NEMO experiments. |
| RAPS_EXPERIMENT | `string` |  | `control` `hist` `SSP370` `Tplus2.0K`|  |  | Specifies which experiment to run and RAPS associates the corresponding ACTIVITY. |
| RAPS_USER_FLAGS | `string` |  | string|  |  | Flags for RAPS. |
| ICMCL | `string` |  | `biweekly` `monthly` `yearly` `yearly_extra` `generic`|  |  | Chunking of the ICMCL (surface conditions for IFS) to be loaded in IFS-based models |
| DQC_PROFILE | `string` |  | `develop` `production` `lowres`|  |  | Profile to be used for the data quality checker. |
| DQC_PROFILE_ROOT | `string` |  | string|  | `"%HPCROOTDIR%/profiles"` | Path to the profiles directory, generated in the REMOTE_SETUP, and used in the DQC, TRANSFER, WIPE and CLEAN. |
| DQC_PROFILE_PATH | `string` |  | string|  |  | Path to the specific DQC profile to be used. |
| DATA_PORTFOLIO | `string` |  | `production` `reduced`|  |  | Used to determine the set of variables in the data portfolio. |
| DOWNLOAD_ADDITIONAL_DEPENDENCIES | `string` |  | `False` `True`|  |  | If True, in Local Setup, downloads RAPS or other dependencies. |
| GENERATE_PROFILES | `string` |  | `False` `True`|  |  | If True, in Remote Setup, generates data profiles from the GSV. |
| INPROOT_CHECKER | `string` |  | `False` `True`|  |  | If True, in Remote Setup, checks the inputs. |
| LOAD_FDB | `string` |  | `False` `True`|  |  | If True, in Remote Setup, loads the FDB. |
| CREATE_FDB_INFO_FILE | `string` |  | `False` `True`|  |  | If True, in Remote Setup, creates the FDB info file. |
| IFS | `object` |  | object|  |  |  |
