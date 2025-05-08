# ClimateDT Workflow Changelog

<!--
To get the list of tags sorted by the release date:

```bash
git for-each-ref \
    --sort=-creatordate \
    --format '## %(refname) (Released %(creatordate))

%(if)%(subject)%(then)%(subject)%0a%(if)%(body)%(then)%0a%(end)%(end)%(if)%(body)%(then)%(body)%0a%(end)' \
    refs/tags \
    | sed 's#refs/tags/##g'
```

https://git-scm.com/docs/git-for-each-ref

Then went through the tag body/text adjusting it for consistency.
Re-wrote the first tag to have a better explanation for users.
-->

## 5.1.0 (Release Candidate)

### :sparkles: Highlights

This version adds the data retrieval, removes FDB into file creation from REMOTE_SETUP during NEMO-only runs.

### :notebook: List of changes

#### Added

- Data retrieval workflow, similar to the one in apps.

##### Changed

- Clean the opa template.
- Fixed offshore run for chunk > 1
- Updated and expanded the schema/pre-flight tests.
- Removed FDB info file creation from Remote Setup during NEMO-only runs.
- Adapt DQC wallclock to model resolutions
- Hydroland relies on previous Hydroland ouput-files to run for the first time, instead of relying on CHUNK and SPLIT as it was before here.

#### User action required


## v5.0.5 (Released Apr 24 12:00 2025 +0200):

### :sparkles: Highlights
This operational release supports creating the AQUA catalog starting from a different startdate than the one from the experiment. It updates the catalog version to e25.1_v1 and adds the `operational` RUN.TYPE to set up all the operational configurations in MareNostrum5 and LUMI.

### :notebook: List of changes

#### Added:
- `RUN.TYPE: operational` to use the operational projects and configurations in MN5 and LUMI.
- `AQUA.STARTDATE` key to define the catalog startdate. By default, it is the one from the experiment. 

##### Changed
- Fixed offshore run for chunk > 1
- `catalog` version to e25.1_v1.

#### User action required


## 5.0.4 (Released Apr 15 12:00 2025 +0200)

This operational release supports the FDB routing strategy, that was not compatible with our previous runs. In practice, it binds two additional directories in the contianer calls to read the data.

Due to external issues, this version has only been tested in MareNostrum5 and not in LUMI.

## 5.0.3 (Released Apr 07 15:20 2025 +0200)

### :sparkles: Highlights

This version adds support to `clmn` stream in the TRANSFER and WIPE jobs, reduces the size of the logs, updates the DVC to 2025.0.1, and adjusts default wallclocks.

### :notebook: List of changes

#### Added

- Support to transfer and wipe clmn stream.
- Added auxiliary data path for obsall.
- Support to the shared tsuite1 user.
- A check during local setup to ensure needed submodule are correctly cloned.
- Reduced the size of the output logs
  - From the IFS-NEMO SIM hres call.
  - From DQC output by redirecting full output to a different file on HPC. `dqc-report` is called at the end of the execution and the outcome is in the .out.

##### Changed

- Max wallclock values to match the default for each platform.
- OPA wallclock time set by default at 20 min in all platforms.
- Removed unused hardcodded paths in the DN template to read from the DataBridge.
- Removed unused hardcodded paths in the OPA template to read from the DataBridge.
- Updated DVC to 2025.0.1.
- Make the githook not fail silently.
- Removed FDB info file creation from Remote Setup during NEMO-only runs.

#### User action required

## 5.0.2 (Released Mar 26 10:20 2025 +0100)

### :sparkles: Highlights

Updated IFS-NEMO to the final E25.1 cycle version (DE_CY48R1.0_climateDT_20250317). The issues in the Data Bridge were fixed, and we validated that the data sent to the bridge can be read. There were minor improvements in the AQUA workflow.

### :notebook: List of changes

#### Added

- A default retrials value of 5 for the transfer job.

##### Changed

- Updated IFS-NEMO to DE_CY48R1.0_climateDT_20250317.
- Updated app aux data path version for production runs.
- Minor improvements in the AQUA workflow.
  - A key (AQUA.REGENERATE_CATALOGS) to re-generate the catalog entry for that experiment or not.
  - Git management in AQUA push.
  - Removed description from the config_catalog, AQUA creates it automatically.
  - Customizable bucket.

#### User action required

## 5.0.1 (Released Mar 21 17:05 2025 +0100)

### :sparkles: Highlights

Updated documentation based on schema rules. The path for auxiliary data in the application is now configurable. The DVC version used will be fixed to the one in the submodule.
NOTE: This version does not allow transfering monthly means to the data bridge. Issues in the DataBridge does not allow to read from the data bridge with the Data Notifier.

### :notebook: List of changes

#### Added

- Page of the documentation that shows the configuration keys based on schema rules.
- FDB Purge during the transfer job.
- The workflow will read from the production or test auxiliary data for applications depending on the workflow run.type.
- MODEL.USE_FIXED_DVC_COMMIT will prevent to automatically update the DVC to the latest updates. The DVC used will be the one fixed by the submodule.
- A default retrials value of 5 for the transfer job.

#### Changed

- Updated AQUA to v0.13.5
- Documentation template to ReadTheDocs.
- app energy_offshore new version 0.4.7
- app energy_onshore new version 0.7.9 --> 1.0.0
- Updated GSV to v2.9.7
- Default resource configurations for experiments

#### User action required

- (IFS-NEMO) If the user wants to dinamically update the DVC version, has to set MODEL.USE_FIXED_DVC_COMMIT: "false". The default value is True.

## 5.0.0 (Released Mar 3 13:43 2025 +0100)

### :sparkles: Highlights

This release contains all the changes required to work with the **new data governance**, from the models to the applications. It is meant to be used for the end-to-end runs previous to the e-suite.

NOTE:  This release does NOT support the transfer of montly means to the databridge.

### :notebook: List of changes

#### Added

- A file placed in REQUEST.INFO_FILE_NAME will indicate which data is present in the HPC and which is present in the Data Bridge. <https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/merge_requests/600>
- Placeholder for application postprocessing. i.e. a job at the end of the chunk, after the app execution.

#### Changed

- Updated application versions: <https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/issues/845>
- Use of `ruamel.yaml` instead of `pyyaml` in the githook
- Made application mother request grid configuration (`grid`, `area`, `method`) AS variables, stored in `conf/applications/default_gsv_request.yml`
- Updated AQUA to version 0.13.1. Minor improvements in the AQUA workflow. <https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/merge_requests/634>
- Updated data porfolio to version 1.2.0 <https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/merge_requests/634>
- Updated apps data portfolio to version 1.2.0 <https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/merge_requests/622>
- Updated GSV to version 2.9.3 <https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/merge_requests/641>
- Updated IFS-NEMO to DE_CY48R1-0_climateDT_20250219 <https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/merge_requests/654>
- Activity FDB key:
  - ScenarioMIP -> projections
  - HighResMIP and CMIP6 -> baseline
- Preparation of application HYDROLAND to be used with bias adjustment
- All applications have a default resolution of 10km or less

#### Removed

- Removed energy offshore unused variables from mother request.
- AQUA submodule. Using a venv in the Autosubmit VM (temporal). <https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/merge_requests/634>
- Experimental Maestro implementation.
- `--hugepages` RAPS flag from IFS-FESOM tco79 simulations (`conf/simulations/ifs-fesom-*-tco79.yml`).

#### User action required

## 4.3.0 (Released Fri Feb 7 16:50:50 2025 +0100)

### :sparkles: Highlights

This release freezes the components before the official d-suite updates.

- **Applications workflow**: Several applications can run at the same time. The output is better organized. Reduced complexity by diminishing the number of OPA jobs. Added soft dependencies, allowing an application to fail without affecting the other components.
- **Additional jobs**: AQUA, TRANSFER and WIPE were tested and validated with the testing suite. Support to multiple ensemble members in those tasks.
- Improved the testing coverage, both in python and bash. Pre-flight tests were refactored and now include apps, end-to-end and simless main's.
- Removed legacy submodules.

### :notebook: List of changes

#### Added

- sbatch parameters for OPA can now be tunned in `conf/application/opa.yml`. In this way computing resources can be optimized.
- Missing bindings in AQUA-analysis job, it was working in MN5 but not in LUMI due to different Singularity settings.
- Check to verify if the plots from AQUA-analysis are generated successfully or not.
- Configurable arch and compilation flags for IFS-NEMO.
- Added tests to the helper scripts of the TRANSFER job.
- Several applications can run at the same time (in the same workflow). The applications that can run are energy onshore, Hydroland and Hydromet.
- OPA and APP output structure has been optimized (now all the output is in the HPC under `$HPCROODIR/$expid/output/`)
- New ifs-fesom-control-tco1279 configuration
- `MODEL.RAPS_MIR_CACHE_PATH` and `MODEL.RAPS_MIR_FESOM_CACHE_PATH` parameters to allow overriding the RAPS env variables `MIR_CACHE_PATH` and `MIR_FESOM_CACHE_PATH` from the `main.yml`.
- Extended pre-flight tests for apps, end-to-end and simless main's. Unified the main_examples from different directories of the repository in `mains` directory. Extended the catalog of variables in the schemas.
- BATS tests to SYNCHRONIZE, AQUA, WIPE, TRANSFER, SIM_IFS-NEMO and CLEAN templates.
- ICON Phase-2 runscripts for updated versions of ICON and YACO.
- Separate the checkpoints in the TRANSFER job by members, allowing to transfer multiple realizations.
- Raps/hres flag `--inproot-namelists` in `sim_ifs-fesom.sh` so that namelists are always taken from the INPROOT dir.
- Added retrials to the OPA.
- Implemented soft dependencies in the applications and end to end workflow.
- Implemented histogram production for windspeed for energy (energy onshore).

#### Changed

- Application `MHM` is now `HYDROLAND`.
- `hydromet` is now using the container.
- DVC cache path in MN5 moved from `/gpfs/projects/ehpc01/DestinE/.dvc/cache` to `/gpfs/scratch/ehpc01/data/.dvc/cache`.
- Using `tools` and `base` containers to modify namelists and to perturb restarts.
- Autosubmit version in the CI/CD updated from 4.1.10 to 4.1.11. The pipelines now run faster thanks to performance improvements in the autosubmit inspect command.
- GSV version updated to 2.8.2. This includes updates in the DQCWrapper to allow mixing `clmn` and `clte` profiles, so the workflow call is the same for reduced and production portfolios.
- Refactored TRANSFER, supporting mixing `clmn` and `clte` profiles.
- Using GSV container (base + gsv) to run the Pytest tests.
- Deatached the workflow from ehpc01 project in MN5. Fixed a bug that was preventing to overwrite the PROJECT from `main.yml`.
- Request examples moved from lib to root directory.
- Removed `READ_EXPID` from all templates and conf files. Changed it by `REQUEST.EXPVER`. Updated request_example_test.yml to be able to read from wf type "test" with apps alone.
- `fix_constant_variables` has REALIZATION as argument, so that the constant variables are present in all the ensemble members.
- Remote setup removed from DN dependencies in end-to-end workflow type.
- Update AQUA to v0.13-beta.
- IFS-NEMO version updated to DE_CY48R1.0_climateDT_20241218.
- Support `generation` flag in all the FDB scripts, AQUA catalog generator, added `generation` flag in IFS-NEMO.
- Changed %ICMCL% for %MODEL.ICMCL_PATTERN% variable (transparent to the user).
- Energy onshore default version is now 0.7.6.
- Simplified OPA structure in app workflow. Now there is a single OPA Autosubmit job per application instead of N OPAs per application.
- OPA version is now v0.7.0.
- Simplified ICON simulation template script. Removing unnecesary functions.
- Fixed Wildfires WISE integration.
- Added area selection and grids for energy onshore as parameter in the mother request.
- The number of processes per OPA is platform-dependant now.
- `DATELIST` format in all ifs-fesom configs to comply with YYYYMMDD (before some had YYYYMMDDHH).

#### Removed

- mhm and mrm submodules and related functions (load_enviroment_mhm)
- Apps workflow configuration key removed: `APP.OUTPATH`. It is now handled internally
- Legacy submodules: bias_adjustment, hydromet, one_pass, urban, energy_onshore, energy_offshore, obsall, icon-mpim, wildfires_fwi, wildfires_spitfire, wildfires_wise. The applications will use containers from now on.
- Old phase-1 ICON runscripts plus old unused icon compilation functions.

#### User action required

Specify the following to run with bsc32:

```
PLATFORMS:
  MARENOSTRUM5:
    PROJECT: bsc32
    FDB_DIR: /gpfs/scratch/ehpc01/experiments
    FDB_PROD: /gpfs/projects/ehpc01/dte/fdb
    HPC_PROJECT_DIR: /gpfs/projects/ehpc01
```

In order to reuse an already existing experiment for `workflow.type` `APPS` or `END-TO-END` remove any `APP.OUTPATH` from `main.yml`.

## v4.2.0 (Released Fri Nov 15 15:37:29 2024 +0100)

### :sparkles: Highlights

In this release, we have introduced several new features and improvements to enhance the overall functionality and user experience. Key highlights include:

- **Refactoring:** Addition of a new lib function `lib/common/util.sh::get_host_for_raps` and configuration parameters that simplify loading of the environment. This substitutes the deleted functions `load_SIM_env_*`.
- **Containarization:** Implementation of container logic for energy offshore, standarized naming for containers version, deleted legacy GSV submodule.
- **AQUA workflow:** Enhanced AQUA-push job to collect and push plots generated by AQUA-analysis to AQUA-web, facilitating better data visualization and sharing.

### :notebook: List of changes

#### Added

- A lib function `lib/common/util.sh::get_host_for_raps` to select the `host` value for RAPS, based on the processing unit chosen.
- Container logic for energy offshore is now implemented.
- AQUA-push job collects the plots generated by AQUA-analysis and pushed them to the AQUA-web.

#### Changed

- `inputs_dvc_checkout` moved from platform-specific libs to `lib/common/util.sh`. Cache dir is now part of the configuration.
- Check data_portfolio == reduced instead of dqc_profile == intermediate for running DQC in reduced output.
- Dealing with standardised naming for container versioning for the different applications is included now in the different templates.
- Standardize GSV container naming. We will use gsv_${VERSION} instead of gsv_v${VERSION}.
- `date` from the GSVREQUEST is now directly coming from AS variables in the `mother_request`.

#### Removed

- GSV submodule.
- The lib functions `load_SIM_env_ifs_cpu`, `load_SIM_env_ifs_gpu` and `load_SIM_env_ifs`, relevant to IFS based models, have been removed, and the parameters that they exported can be now set in the `confs/model/ifs-*/ifs-*.yml` yaml files, under the `PLATFORMS.<platform>.RAPS_<parameter>` keys.
- The lib functions `rm_restarts_icon` and `rm_restarts_ifs` have been removed from all platforms as they where not used anymore.

### :warning: User action required

- `PLATFORMS.<platform>.MODULES_PROFILE_PATH` can be now defined to specify the path to the module profile file in a given HPC. This path is sourced for IFS-based models during the SIM job.

## v4.1.1 (Released Mon Nov 4 09:52:28 2024 +0100)

- Bump AQUA version from 0.11.3 to 0.12.1.
- Bump GSV version from 2.6.0 to 2.6.1.

## v4.1.0 (Released Mon Oct 28 14:07:31 2024 +0100)

### :sparkles: Highlights

In this version we are getting ready for the trial runs. For this, we **removed hard-coded references to the project in LUMI** and added the mechanism in the SPLITS that allows for obtaining **calendar information** from them. For now we assume model chunks of one month and application splits of one day.
As part of the refactoring, all the **functions have a comment** before the call that indicate where the function is **defined**. The workflow is doing extensive use of the **GSV container** and the workflow is also containerised for **one_pass** step end **energy_onshore** application, and the **paths** related to the pre-compiled models and inputs are moved from a function to a **configuration file**, allowing more flexibility to the users.

### :warning: User Action Required

- `MODEL.ROOT_PATH` can now be used to specify a different root path other than the default one.
- `MODEL.PATH` can now be used to specify a different path to the model than the default one. Same happens with `MODEL.INPUTS`.
- To compile a new model version in IFS-NEMO, insted of `INSTALL.SHARED: True` use `MODEL.COMPILE: "True"`.

### :notebook: List of changes

#### Added

- All function calls have a comment indicating where they are defined.
- Implemented calendar splits in the application workflow.

#### Changed

- Removed hard-coded references to `project_465000454`.
- GSV-related tasks (dqc, transfer, wipe, clean) use a singularity container instead of pip installation/conda environment.
- Moved the lib/ruscript directory to the root of the project. Now it is `runscripts`, that contains subdirectories for each task.
- New configuration files for GSV-related configurations and for general configurations. Both are always loaded.
- AQUA will read healpix by default. This can be changed specifying %AQUA.SOURCE_*%.
- Default catalogs for AQUA are `mn5-phase2` for MareNostrum5 and `lumi-phase2` for LUMI.

#### Removed

- The lib function `load_model_dir` function was removed. Now using `MODEL.ROOT_PATH` in `defaults/default_model.yml`.
- The lib function `load_inproot_precomp_path` funciton was removed. Now using `MODEL.PATH`, and `MODEL.INPUTS` in `defaults/default_model.yml`.

## v4.0.5 (Released Tue Oct 8 16:48:01 2024 +0200)

### Added

- Support for tco2559 projection on MN5.
- AQUA as additional job in MN5 and LUMI. If its not already present in the catalog, creates a catalog entry for the experiment and runs the LRA creation. Runs aqua-analysis.
- AQUA default container uses v.0.11.3.
- Simless workflow support in the Git Hook, examples, and defaults.
- Added HPC-FDB for MN5.
- CICD pipelines to run linters, tests, and build the docs for every merge request/commit.
- Function fix_constant_variables copies the sfc_daily variables to the first day of the chunk.
- --no-home call in DVC container calls.
- %CONFIGURATION.IO_ON%: False will disable the flags for IO in order to run without output.
- Energy application run in container in MN5
- Checker for RUN.TYPES.
- Support for multiple members in the DN.
- Added calendar splits in the application workflow. Applications are meant to run every simulated day. gsv_interface pip installation is no longer supported.
- Yamlfmt and yamllint to the CI/CD to ensure correctly formatted YAML files.
- Baseline and pre-flight tests

### Changed

- Interactively set up the request for applications-only workflow.
- Also allow using environment variables instead of an interactive session.
- Nemo standalone: forcing files change eppending on the resolution.
- Use of EXCLUSIVE key instead of --exclusive in the CUSTOM_DIRECTIVES.
- GSV_interface version to v2.6.1.
- Updated energy_onshore version.
- SIMULATION.DGOV parameters are under REQUEST.
- Use -- instead of - in python parsers
- Delete load_dirs function, use CURRRENT variables instead.
- DQC profiles are created in the REMOTE_SETUP and stored in DQC_PROFILE_ROOT path.
- Deleted set_data_gov function. All the data_gov parameters come from the configuration.
- Dropped FDB5_CONFIG_FILE. FDB_HOME is always used.
- The paths of local FDBs are uniformed with the production ones.
- Data Listening mechanism is now running with containers (DN and OPA)
- IFS-NEMO version: DE_CY48R1.0_climateDT_20240723
- Data portfolio (v0.0.4 --> v0.1.1)
- Refactored the simulations and models files for ifs-fesom
- Changed FDB paths to use /appl/local/destine
- Changed Singularity contanier bindings to use new FDB paths
- Using common FDB_HOME variable in ICON sim script

### Removed

- Set_data_gov function. Replaced by configuration parameters REQUEST.ACTIVITY and REQUEST.EXPERIMENT.
- Support to MareNostrum4.
- Default run.types.

## PROJECTION-PHASE2-IFS-FESOM-MN5_v1 (Released Fri Aug 9 17:11:50 2024 +0300)

increasing NUMCHUNKS to 24 for ifs-fesom projection (~1 year of 15-day chunks)

## v4.0.4 (Released Fri Jun 28 14:09:40 2024 +0200)

### Added

- MHM re-integrated in main after a long time
- Support for scaling tests.
- Possibility to modify namelists for IFS-NEMO.
- Nemo standalone support.
- Energy onshore support.

### Changed

- Updated GSV_interface to v2.0.3.
- Two DQC jobs: BASIC (subsets of checks, blocking) and FULL (all the checks, non-blocking).

### Removed

## v4.0.3 (Released Thu Jun 13 11:09:30 2024 +0200)

### Added

- The githook allows to choose which model the user is running.

### Changed

- In MareNostrum5, the default project is ehpc01 (before, it was bsc32).
- In Lumi, changed the paths of the FDB and mars binaries, and FDB HOME of the HPC-FDB and the data bridge.

### Removed

## v4.0.2 (Released Fri Jun 7 12:18:18 2024 +0200)

### Added

- Support for DVC in MareNostrum5 for IFS-NEMO.
- The githook allows to choose which type of workflow user is running. It also creates the `request.yml` if needed.
- Autosubmit variables in the mother request, so the keys are set in the `request.yml` for all the variables requested.
- Data listening mechanism in MareNostrum5, using conda environments for OPA and GSV.

### Changed

- Updated ifs-nemo submodule to DE_CY48R1.0_climateDT_20240523.
- DN time and retrials depends on the type of run that is being performed.

### Removed

## v.4.0.1-bsc32 (Released Tue Jun 4 09:59:37 2024 +0200)

IFS-NEMO end-to-end works in MN5 with bsc32 quota.

## v4.0.1 (Released Mon May 13 12:49:47 2024 +0200)

### Added

- Wrappers to the transfer jobs.
- Support for IFS-NEMO in MareNostrum5 (using pre-compiled model).
- Githook to automatically run create_jobs_from_mother_request.py
- Bias Adjustment added for the first time, with tp available.

### Changed

- DQC: By default run DataAvailableChecker, use get_member_number to get realization, reduced wallclock to 00:30.
- Syntax fix in CHECK_MEM.
- Fix GPU directives.
- GSV version to v1.5.1
- energy_onshore capable to run daily.
- Default partitions for ICON in LUMI updated.
- Reduced number of auxiliary files in applications workflow.

### Removed

## v4.0.0 (Released Fri Apr 26 15:14:01 2024 +0200)

Version corresponding to D340.6.2.3 : BSC : Climate simulations workflow implementation v4 (final version).

### Added

- Allow Reading from the Data Bridge
- Allow DQC profile resolution selection
- Added automatic Sphinx documentation generation and code formatting
- Added more Bats tests, and make coverage and instructions to run kcov #334
- Added workflow requiremnts.txt file
- Added WIPE job
- Added experiment backup job

APPLICATION WORKFLOW:

- Added application workflow to main
- Allow the possibility to change type of workflow
- Experimental Maestro integration

IFS-NEMO:

- Added tco399-ORCA025 resolution
- Possibility to run ensembles

ICON:

- Stable YACO integration
- Added R2B8-R2B9 resolution

IFS-FESOM:

- Updated current workflow for IFS-FESOM

### Changed

- Move DQC, TRANSFER, CLEAN to additional jobs
- IFS-NEMO IO server redistribution
- Adapt DQC, TRANSFER, CLEAN, WIPE for ICON
- Changed main keys

### Removed

- Removed clean run flag

## PRODUCTION-PHASE1-IFS-NEMO (Released Thu Feb 22 11:42:42 2024 +0100)

Production runs of Phase 1 using only model workflow.

## v2.2.1 (Released Wed Feb 14 10:23:22 2024 +0100)

Minor updates.

Includes:

- Default nproma to 32.
- Update GSV.
- DQC profiles depending on the model.

## v2.2.0 (Released Fri Feb 9 17:32:06 2024 +0100)

Model's workflow freezed before production runs.

Includes:

- New jobs: Data quality checker and transfer to the data bridge.
- Writing HPC-FDB and sets production EXPID.
- Memory monitoring tools: <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/113>
- Automatise the compilation in the common directory: <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/128>
- Set different number of IO nodes for IFS and for NEMO: <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/124>
- RAPS is now part of the ifs-bundle & writing to 3 FDBs: <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/130> & <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/merge_requests/94>
- Using inputs from the DVC repository: <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/105>

## DE_CY48R1.0_climateDT_20231214 (Released Thu Jan 11 17:28:30 2024 +0100)

Workflow version compatible with tag DE_CY48R1.0_climateDT_20231214 of ifs-bundle. Includes:  - Memory monitoring tools: <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/113> - Automatise the compilation in the common directory: <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/128> - Set different number of IO nodes for IFS and for NEMO: <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/124> - RAPS is now part of the ifs-bundle & writing to 3 FDBs: <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/130> & <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/merge_requests/94> - Using inputs from the DVC repository: <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/105>

## app-v0.2.1 (Released Thu Jan 11 12:02:18 2024 +0100)

**What is new:**

New release app-v.0.2.1:
- allows using the new Data Governance
- Renewed README
- New versions GSV_interface 11.1, OPA 0.5.1
- Improvements in applications: AQUA, MHM, URBAN.

## v3.0.0 (Released Fri Dec 22 12:03:33 2023 +0100)

Tag corresponding to deliverable D340.8.3.1.

It contains the v2.0.0 (D340.6.2.2) plus the applications workflow.

## v.2.1.0 (Released Tue Dec 19 11:24:17 2023 +0100)

Contains:  - Writing to a common FDB, with 3 FDBs with different resolutions in case of IFS-NEMO. - Memory monitoring tools. - Usage of DVC inputs. - Collection of bug-fixes.

## app-v0.2.0 (Released Mon Nov 20 12:10:27 2023 +0100)

*What is new:*

- Capability to read from different FDBs
- End to end can be used
- Updates in app integration
- Containerisation of some of the components
- Ported successfully to MN4
- More robust way to run an experiment explained in a renovated README

## end2end-0.0.1 (Released Fri Oct 27 14:16:50 2023 +0200)

Code from used to run the first version of the end to end workflow (model+application) (IFS-NEMO-Tco79-eORCA1), from the dev branch: `dev-model-app`

Successfully run in LUMI on 19th Oct

## app-v0.1.10 (Released Wed Oct 18 18:29:13 2023 +0200)

*What is new:*

- FWI, MHM and AQUA totally integrated.
FWI: fully integrated
MHM: mrm integration nearly done
AQUA: run in container. Dummy runscript. ready to add any non dummy aqua runscript.

- improvements in the implementation of other apps even though not finished

## v2.0.0 (Released Wed Oct 18 09:15:04 2023 +0200)

LUMI is supported for IFS-NEMO and ICON to perform test and development simulations. IFS-FESOM can run in LUMI for test resolution (tco79). MareNostrum4 is supported for IFS-NEMO to perform all types of simulations. ICON runs using hetjobs, and IFS-NEMO can run both in LUMI-C and LUMI-G.

## v1.1.1 (Released Mon Oct 16 16:36:52 2023 +0200)

Stable IFS-NEMO workflow, before the merge with changes from ICON workflow. Linked to DE340_CY48R1_BSC_experimental branch of ifs-bundle and raps. Can run in LUMI-G and LUMI-C with automatic compilation, and in MareNostrum4 with a precompiled version. Includes: - Custom configurations <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/10> - Restarts handling <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/18> - Yeartly ICMCL files <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/20#note_213402> - Checkers <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/61> - Automatically switching MultIO plans: <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/67> - Enable retrials inside wrappers <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/merge_requests/34> - Running in GPU partition of LUMI <https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/71>

## app-v0.1.9 (Released Mon Oct 9 15:12:41 2023 +0200)

*What is new:*

- Energy offshore added as submodule

## app-v0.1.8 (Released Thu Oct 5 15:35:35 2023 +0200)

**What is new:**

- Issue with AQUA cloning fixed

AQUA can be cloned as usual now, using "aqua" in main.yml

## app-v0.1.7 (Released Thu Sep 28 14:21:19 2023 +0200)

**What is new:**

- new versions of GSV_interface (0.7.0), OPA (0.4.2). And changes in the workflow changed accordingly.
- Submodules for wildfires_wise and wildfire_fwi created
- DN is now faster

## app-v0.1.6 (Released Fri Sep 1 14:50:27 2023 +0200)

**What is new:**

- energy_onshore, mHM, AQUA integrated.
- AQUA is integrated using a container. First application to be deployed in the WF using this method.

## app-v0.1.5 (Released Tue Aug 8 17:53:45 2023 +0200)

**What is new:**

- gsv_interface includes the new, faster version tag = v0.5.0
- `mhm` included as a submodule

## CONTROL_HISTORICAL_DEVELOPMENT_CONFIGURATION (Released Mon Aug 7 09:35:16 2023 +0200)

Workflow used for (at least) the first 10 years of the Control simulation, and the 1st year of the Historical simulation.

## v1.1.0 (Released Mon Jul 31 09:13:55 2023 +0200)

Workflow version used in control and historical runs of IFS-Nemo. Successfully tested all the steps, including running the model with automatic compilation.

## app-v0.1.4 (Released Tue Jul 25 14:12:00 2023 +0200)

*What is new:*

- Waiting routine has been added to the data notifier, to be ready for the real streaming coming from the model workflow.

- Extra variables can be checked in the data notifier even if the variables are not used in the OPA request

## app-v0.1.3 (Released Mon Jul 10 11:42:18 2023 +0200)

Changes in the data request:

- Requests can contain several variables and statistics and will be computed at once, using the OPA new parallelisation.
- This workflow uses the new FDB with 4yr of data. It is more stable and contains more data (vversions < v0.1.2 use 2 yrs).
- Internally the workflow uses steps instead of dates.

## app-v0.1.2 (Released Wed Jul 5 12:06:30 2023 +0200)

*WHAT IS NEW:*

- Unified configuration: streaming, opa request and gsv request
- Option to get the raw data using OPA by `stats: "raw"`

## app-v0.1.1 (Released Thu Jun 29 18:06:39 2023 +0200)

- Bug fixed. One pass submodule now pointing to the correct commit. * Variables in the template files passed using correct syntax

## app-v0.1 (Released Wed Jun 28 19:13:20 2023 +0200)

First release of the applications workflow using data streaming from FDB, with `NextGEMS` data. More info in the `README`

## app-simple-urban-a041 (Released Thu Jun 15 11:26:25 2023 +0200)

Tag including the `expid` related to it. It is a checkpint to see that the DN and the OPA are working properly. People will be asked to run it as long as there is no new version with a more sophisticated streaming.

## app-basic-subworkflow (Released Fri May 5 15:48:03 2023 +0200)

To test the most basic APP workflow.

## v1.0.0 (Released Fri Apr 28 15:43:43 2023 +0200)

Update README.md

## vanilla_workflow (Released Fri Mar 24 11:43:53 2023 +0100)

The vanilla version of the Climate DT workflow.
