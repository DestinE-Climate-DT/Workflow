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

## 6.2.6 (Released Aug 2026)

### Added

- Configuration key `CONFIGURATION.IFS.USE_LOCAL_TIME` (true/false) to bypass upgrade of v6.2.5 for backwards-compatibility.

### Changed

- Updated Hydroland v1.2.8, which improves speed and app output volume (see https://jira.eduuni.fi/browse/CSCDESTINCLIMADT-1398)

### Fixed

- Updated the ICON 4xCO2 runscript to use the `CURRENT_RESTART` directory rather than the experiments_dir.

## 6.2.5 (Released August 2026)

### Fixed

- A default IO_SAFE_WAIT of 60 to fix a bug in Autosubmit v4.1.17 and v4.2.0 which causes the default to be 0.
- Changed the IFS SIM start date calculation to use the UTC date instead of the local date to fix an off-by-one-day error during daylight savings transitions.
- Storylines forcing are included in inipath for RESTARTED runs.

## 6.2.4 (Released July 2026)

### Added

- LOCAL_SETUP now validates `EXPERIMENT.MEMBERS`, rejecting member lists where two members map to the same realization (for example `fc0 fc0`, or `fc8 fc08`, which both resolve to realization 9).
- The experiment schema now enforces the `fcN` pattern for `EXPERIMENT.MEMBERS`.

### Changed

- Ensemble realizations are derived from the member name (`fcN` → realization `N+1`), so a member list can start at any index (`MEMBERS: fc10` writes realization 11).
- ICON's `default` member is now `fc0`.

### Fixed

- Over 10 members allowed for OPA+APP input/output paths.
- Removed the AQUA.FIXER_NAME from the AQUA configuration yaml. This value will now be determined by the run type.
- AQUA_SETUP now looks up the catalog entry by experiment name instead of expver.
- `AQUA_PUSH` no longer fails when a member has no new catalog entry to commit.

#### User action needed

- `EXPERIMENT.MEMBERS` must now name every member as `fcN`. Configurations still using
  `MEMBERS: "default"` (the previous ICON default) must be changed to `MEMBERS: fc0`.

## 6.2.3 (Released July 2026)

### Changed

- Updated the default AQUA container version to v0.19.13.
- Updated the AQUA docs to include recent changes.

## 6.2.2 (Released July 2026)

### Highlights

This version includes two bug fixes and an update to the default AQUA catalog tag.

### Changed

- Updated the default value for `AQUA.CATALOG_REF` to e26.1_v2.

### Fixed

- In the LUMI TRANSFER job, the temporary grib file is now being removed again after a successful transfer.
- Bugfix with path slashs for the restart copying.

## 6.2.1 (Released June 2026)

### Highlights

This version is released as a fix for Operational Cycle e26.1, removing the ClimateDT Catalog from the workflow submodules, and working with it as a separate repository (still linked to the experiment).

### Added

- `AQUA.CATALOG_REF` configuration key (default: `e26.1_v0`) to pin the catalog revision.
- Default model resolutions in km to all model resolution files.

### Changed

- The Climate-DT catalog is no longer a workflow git submodule. When AQUA is enabled, `LOCAL_SETUP` clones [Climate-DT-catalog](https://github.com/DestinE-Climate-DT/Climate-DT-catalog) into `$ROOTDIR/tmp/catalog` at the revision set by `AQUA.CATALOG_REF`, tars it separately, and `SYNCHRONIZE` transfers it to `$HPCROOTDIR/catalog`.
- AQUA templates and remote setup now read catalog files from `$HPCROOTDIR/catalog` instead of `$HPCROOTDIR/$PROJDEST/catalog`.
- Updated the AQUA version to 0.19.12.
- Updated the AQUA catalog version to e26.1_v1.
- The e-suite and o-suite catalogs to climatedt-gen2.
- The development catalog to test-phase3.
- Throughout the workflow, the AQUA model name now includes the atmospheric resolution in km.
- AQUA_GRID_BUILD now depends on the 1st chunk of DQC_BASIC.

#### User action needed

- Ensure `AQUA.CATALOG_REF` is set in experiments using AQUA. After upgrading, run `autosubmit refresh` so the experiment picks up the new catalog handling.
- Please note that the current AQUA catalog does not support tco319.

## 6.2.0 (Released June 2026)

### Highlights

This version introduces major AQUA workflow enhancements, including support for reanalyzing past LRA data, configurable analysis behavior, and a decoupled LRA Generator workflow. It also adds new SSP configurations and GPU-aware support for ICON runs, alongside improvements to restart management, run directory organization, wrapper controls, and platform configurations. In addition, numerous fixes enhance performance monitoring, data handling, and workflow synchronization across the supported models and workflows.

### Added

- Clean restarts utility to safely manage restart file retention with configurable `KEEP_EVERY` and `KEEP_LAST` policies, including input validation guards.
- The ability to run the AQUA jobs with past LRA data. Note that the LRA data must be in the main branch of the AQUA catalog.
- The ability to specify an AQUA analysis config file if one other than the default is desired.
- Configurable timeframe logic for determining when AQUA plots are considered generated during analysis.
- Reenabled the tcc variable for AQUA LRA Generator.
- IFS-NEMO SSP2-4.5 simulation configuration file.
- ICON SSP1-2.6 and SSP2-4.5 runscripts.
- ICON new GPU-aware directives added to runscripts.
- Ability to enable/disable APP wrappers via a configuration key, e.g. `APP.HYDROMET_WRAPPER: "True"`.
- `AS_JOBNAME` (from `%JOBNAME%`) to name the run directory in ICON, IFS-FESOM, and IFS-NEMO simulations, following the pattern `<expid>_<sdate>_<member>_<chunk>_<job>` (e.g. `t0qn_19900101_fc0_5_SIM`). This pattern is preserved even when jobs run inside Autosubmit wrappers.

### Changed

- `CONFIGURATION.RUNDIR_PATH` and `CONFIGURATION.RUNDIR_BACKUP_PATH` no longer include `%CHUNK%`, so run directories and their backups are now organised by start date and member only (e.g. `rundir/19900101/fc0/` instead of `rundir/19900101/fc0/<chunk>/`).
- Changed model source path structure
- The AQUA version to v0.19.11.
- The AQUA source variable names to align with the FDB key names (oce3d => o3d, etc).
- The `AQUA_GRID_BUILD` source names updated: `oce2d` → `o2d`, `oce3d` → `o3d` to match AQUA v0.19.11+ catalog naming conventions.
- The LRA Generator job has been decoupled from the other AQUA jobs.
- Fix Constant Variables to run once per member instead of once per chunk.
- Updated DN totaljobs for apps and end to end workflows.
- IFS-FESOM: Updated platform resource configurations for tco1279 (MareNostrum5) and tco2559 (LUMI).
- Updated the Autosubmit image version to v4.1.16.1 for the Gitlab pipelines.
- Updated the default LUMI project and development project from 465000454 to 465002727.
- Removed `CONFIGURATION.DATA_PORTFOLIO` from models and experiments. Enforce addition in `main.yml` (except 'apps' experiments).
- Aqua push script now incorporates `--no-update` flag.

### Fixed

- Added the start date to the Fix Constant Variables grib file to prevent issues in IFS-NEMO experiments with multiple start dates.
- In the bootstrap/include.yml, moved the position of the CONFIGURATION.DATA_PORTFOLIO below the loading of the MODEL.SIMULATION and MODEL.NAME configuration files.
- Changed the e-suite HPCARCH_short from -e26.1 to -o26.1.
- Changed INI back to running on the login node. Users may alter this on an experiment-by-experiment basis in the main.yml if needed.
- Obsall bug on split/chunk execution.
- Removed `AMSUA` datatype from the full `DATA_PORTFOLIO` in the `run_OBSALL` function.
- Made Wipe Check dependent on LRA_GENERATOR+1 so the data is not wiped before it is needed.
- Resource allocation for OPAs.
- Set `RETRIALS: 0` for `WIPE_CHECK` and `WIPE` jobs to prevent unintended retries on failure.
- TASKS hardcoded to 1 in OPAs and APPs.
- AQUA_SETUP job has `install_aqua` arguments wrapped in quotes.
- Split wipe request by realization (https://gitlab.earth.bsc.es/digital-twins/de_340-3/workflow/-/commit/19b0a1d975b44a9e7621890c9e97e10bac48463a).
- Rundir path search for IFS-FESOM and IFS-NEMO in PERFORMANCE_METRICS job.
- Wrappers performance collection for IFS-FESOM and IFS-NEMO.
- Rundir path search for IFS-FESOM, IFS-NEMO and ICON in PERFORMANCE_METRICS job.
- Wrappers performance collection for IFS-FESOM, IFS-NEMO and ICON.
- The collection and computation of several performance metrics and monitoring across the models.
- Fixed race condition between WIPE and LRA Generator jobs concurrently updating the FDB info file for multi-members: `update_fdb_info.py` now uses file locking, and the WIPE template waits for all members to finish wiping a chunk before advancing the data start date.

#### User action needed

- LRA Generator will be enabled if `CONFIGURATION.ADDITIONAL_JOBS.LRA` is True. If AQUA is true but LRA Generator is not enabled, a previous AQUA experiment must be entered to be reanalyzed.
- `CONFIGURATION.DATA_PORTFOLIO` (`'full'`, `'reduced'` or `'minimal'`) must be set in `main.yml`
- Running wrappers for OPA and APP jobs now requires to set `APP.<APPNAME>: "True"` and `APP.<APPNAME>_WRAPPER: "True"` in the workflow configuration.

## 6.1.1 (Released Apr 2026)

### Highlights

This release is validated on LUMI and includes updates to reenable both IFS and ICON models on LUMI.

### Added

- hres output in IFS-FESOM is redirected to a file in the HPC, which can be found in the experiment directory, under `hres_out`. A new function is added to scan for errors in the hres output and report on the AS log.
- Energy indicators update to 2.0.3
- IFS-FESOM: Added `--no-farquhar` flag to abrupt4xCO2 experiment configs.
- The SSP126 simulation yamls for IFS-NEMO.

### Changed

- IFS-FESOM: Replaced `--forcing-SSP` with granular forcing options (`--forcing-aerosols`, `--forcing-aerosols-volcanic`, `--forcing-ghg`, `--forcing-ozone`) to support the new RAPS v0.1.17 bundle (`DE_CY48R1.0_climateDT_20260311`).
- IFS-FESOM: Removed deprecated `RAPS_EXPERIMENT` from all simulation configs in favour of `REQUEST.EXPERIMENT`/`REQUEST.ACTIVITY` and explicit forcing options.
- IFS-FESOM: Removed buggy conditional export of `MULTIO_IFSIO_CONFIG_FILE` which is no longer needed with RAPS v0.1.17 (see !1211).
- IFS-FESOM: Simulation configs follow the naming convention `{atm model}-{ocean model}-{request activity}-{request experiment}-{resolution}.yml` (e.g. `ifs-fesom-baseline-hist-tco79.yml`).
- Updated Wildfires WISE version to 0.2.0, input data to 1.1, update request area
- Updated the IFS bundle for IFS-NEMO to DE_CY48R1.0_climateDT_20260326.
- The forcing flags for IFS-NEMO to be compatible with the new IFS bundle.
- Base OBSALL datatypes and ENERGY_OFFSHORE icing computation on data portfolio
- Allocation of OPA/APP jobs is done using AS variable `THREADS`, enable multiple processes for Energy Indicators
- Energy Indicators parallelism at OS-process level (in app template), with script arguments in runscript.

### Fixed

- Multi member fix for application workflows reading from the Marenostrum5 Data Bridge.
- Changed HealPix grid for IFS-NEMO tco399-eORCA025 to hpz7.
- Added support for higher yaco task mode.
- Add matplotlib environment variable in OPA job to prevent warning.
- Add matplotlib environment variable in APP energy indicators job to prevent warning
- Moved the AQUA VARS_SFC and VARS_O2D to be output portfolio-based since some variables in the full portfolio were not supported by the reduced and minimal portfolios.
- Changed the INI default platform from the login node to the compute nodes.
- Moved the export variables functionality to before the run_experiment call in the IFS-NEMO SIM.
- Added max wrapped variable for opa and apps that run at daily splits.
- A MODEL.PATH substitution error for IFS-NEMO.

### Removed

- MPI support in OPA jobs (superseded by OPA multiprocessing in 6.1.0)

#### User action needed

If the `--forcing-SSP` flag was used for the IFS model in the main.yml, it must be updated to use the new, more granular forcing options (`--forcing-aerosols`, `--forcing-aerosols-volcanic`, `--forcing-ghg`, `--forcing-ozone`).


## 6.1.0 (Released Mar 2026)

### Highlights

This release contains the ability to automatically restart an IFS-FESOM experiment from a previous experiment. Also, the AQUA catalog been updated to e26.1_v0 and AQUA sources now default to monthly.

### Added

- 4xCO2 simulations for IFS-FESOM
- The ability to export variables from an IFS-NEMO SIM by adding a CONFIGURATION.VARS_TO_EXPORT variable to the main.yml. The variable must be in the format `VAR1 VAR2`.
- Support automatic restart from a previous IFS-FESOM experiment (e-suite to o-suite transition).
- IFS-FESOM restarts are now grouped in directories corresponding to their respective chunks.
- OPA multiprocessing with `/dev/shm` (OPA v0.10.0)

### Fixed

- hres output in IFS-NEMO is entirely redirected to a file in the HPC, which can be found in the experiment directory, under `hres_out`. The errors are correctly captured and printed to the LOGs.
- The feature to modify a namelist parameter from the main.yml.
- OBSALL input/output data path separation
- Made the AQUA analysis path to check for created PDF plots more specific to prevent false successes.
- Made SYNC_LRA run once per experiment.
- Set the PUSH_UPDATED_CATALOG job to only run one job of that type at a time.
- Fixed `SYNC_LRA` not running correctly on LUMI: the `sync_lra.sh` template was unconditionally using `${HPCHOST}:` as an SSH prefix in the rsync command, but when the job runs on the LUMI login node the source path is already local. The template now dynamically omits the SSH prefix when the job is executing on LUMI.

### Changed

- IFS-FESOM sim template was changed to use some of the same sim-utils functions that IFS-NEMO uses and keep an equivalent structure.
- Disable exclusivity in the TRANSFER job for LUMI.
- Removed generation and checking of the flag_profiles_generated file. The profiles will be generated every time the GENERATE_PROFILES job is run.
- DVC updated to 2025.0.4.
- Deactivated the inproot checker for restarted runs.
- Hydromet is now running monthly instead of daily.
- Default AQUA sources from hourly or daily to monthly. Also, temporarily removed the tcc variable while related errors are being resolved.
- Updated the AQUA catalog to e26.1_v0.
- Updated AQUA from v0.19.4 to v0.19.8-op to enable monthly LRA sources with a stable version.
- Updated OPA version to v0.9.2
- Tagged data aux data version for wildfires wise 1.0
- AQUA analysis find command from grep to read to be compatible with Autosubmit error handling changes.

## 6.0.0 (Released Dec 2025)

### Highlights

This version contains relevant updates in ICON (produce 100m wind components, multimember support) and a general update in application versions.

### Added

- Support for ICON 100m u,v components.
- Added 4xCO2 ICON runscripts.
- Added support for multimember runs for ICON.
- Added option to restart from another run for ICON.
- Dataflow: add a cleaning request step.
- A singularity environmental variable so that the workflow containers are isolated from the user's personal configurations.
- Workflow variable `OPA_LOG_LEVEL` to set the level of logging of OPA.
- Added two new jobs to monitor a SIM job and compute its CPMIPs

### Changed

- Dataflow: configurable request.
- Wildfires FWI upgraded to v2.2.8
- DQC Basic now includes all the checks except the Negative Space Checker. Previously, the Standard Complience was only in the DQC Full.
- DQC Full runs only after the first chunk of each member. The only difference with the DQC Basic is that it contains the Negative Space Checker. The DQC only updates the FDB_INFO_FILE when the date is greater than the current one in the file.
- Updated to Hydroland 1.2.6.
- Updated Energy Offshore to v0.5.0
- Add variable for Energy Offshore: "COMPUTE_ICING"
- Added soft dependencies in tdigest OPAs in energy indicators.
- Energy indicators updated to v2.0.2, output has been reorganized.

### Fixed

- Fixed the way variables are set for checker_ifs-nemo in Local Setup.
- Set a nemorwdist flag when calling hres so rank weights are only created once per IFS-NEMO exp.
- DQC dependencies.
- Metadata for spatial mask applied to OPA

## 5.6.0 (Released Nov 2025)

### Added

- Improved the operational configuration and created specific configuration files for e-suite and o-suite.
- Dataflow support to download data from the data bridge.
- Support to run OPA using MPI for stats "percentile" and "histogram" (needs container with MPI installed).
- A set of additional jobs, enabled with CONFIGURATION.ADDITIONAL_JOBS.SYNC_LRA: "True", will rsync the LRA to a common directory in LUMI when the simulation finishes. It will also update the paths in the catalog and push it to the repository.
- Restarts for OPA at end of chunk and year
- Spatial mask applied to OPA. Adaptation of the application template for energy indicators to use the same mask.
- Storyline support (control, historical, plus2K) for IFS-FESOM with multiple members.
- A default DVC_INPUTS_BRANCH for all IFS-NEMO simulations.

### Changed

- Now only one key (CONFIGURATION.DATA_PORTFOLIO) is needed to set the MULTIO plans for IFS and NEMO for IFS-NEMO simulations. The default is full.
- Deprecated RAPS_EXPERIMENT in favour of REQUEST.EXPERIMENT and REQUEST.ACTIVITY.
- Split Remote Setup into multiple jobs.
- Energy Indicators v1.1.6, histograms for the 4 turbine types (I,II,III,S).
- One_Pass v0.9.1
- Updated AQUA to v0.19.4.
- Updated the AQUA catalog to the latest version.
- Updated IFS-NEMO to DE_CY48R1.0_climateDT_20251105.
- Updated WILDFIRES_FWI to 2.2.7.
- Standardized IFS-NEMO model and simulation configurations.
- Adapted mask energy indicators to 10km and 25 km.
- Energy indicators updated to v2.0.1.1
- Hydroland data version updated to 1.1

### Fixed

- Simless experiments with DQC don't require FDB_INFO_FILE.
- Dates definition of WIPE and WIPE-CHECK.
- AQUA_PUSH, by default, has the same FREQUENCY as AQUA_ANALYSIS.
- Removed the CONFIGURATION.IFS.START_DATE default values from the test IFS-NEMO file so that the SIM start date will be substituted correctly if no IFS start date is specified by the user.
- Renamed SIMLUATION_START_DATE to SIM_START_DATE in the TRANSFER job.

#### User action needed

Reminder: If you are running AQUA and you don't have an active LUMI-O token in your ~/.aws/credentials file, you will need to generate one and add it in order to push to the aqua-web catalog.

To run SYNC_LRA, add this in your .ssh/config file in LUMI:

```
aayaiavi@uan04:~> cat .ssh/config
Host mn5-cluster1
    HostName glogin2.bsc.es
    User bscXXXX # change to your MN5 user
```

## 5.5.0 (Released Oct 2025)

### Highlights

This version allows support for multi-member runs in the end2end workflow mode. Additionally, for IFS-NEMO, automatic restarting from previous experiments is enabled and the RAPS flags have been parameterised allowing users to control them through the configuration files. Finally, the lib utils.sh file has been refactored and divided into more clear job oriented files.

### Added

- Now the apps workflow is able to read from a specific ensemble member in a more organized way.
- Support for multimember run in end to end (apps part).
- Support automatic restart from a previous IFS-NEMO experiment.
- Energy indicators OPA separated between standard and t-digest statistics.
- Documentation for multiple IFS-NEMO start dates and EXPID changes on the transfer machine.
- Integration of OBSALL

### Changed

- Split utils.sh into separate utils files.
- Energy indicators version v1.1.5
- RAPS flags moved from the `sim_ifs-nemo.sh` template to configuration files.
- One Pass updated to v0.8.2

### Fixed

- The documentation for how to set up the DN job based on the platform to be used.
- The substitution of the model version if it's specified in the main.yml.

## 5.4.0 (Released October 2025)

### Highlights

In this release, the Negative Space Check was added to the Data Quality Checker. Also, the backup job has been enabled in MareNostrum (previously it was only enabled in LUMI) and the restarts can now be automatically backed up with a configurable frequency and deleted after they have been used. Finally, Hydroland has been integrated as a Python package in the workflow.

### Added

- Enabled Negative Space Check in the Data Quality Checker (FULL). This checker reports on variables that are present in the FDB but are not part of the data portfolio. It is only enabled by default in the DQC_FULL.
- Start date, member, and chunk to the rundir path of IFS-NEMO and the backup job.
- Made TRANSFER depend on DQC.
- Enabled the backup job in Marenostrum5.
- Some restarts will now be backed up and then deleted if the Backup and Clean Restarts jobs are set to True.

### Changed

- Updated IFS-NEMO to DE_CY48R1.0_climateDT_20250826
- Energy indicators updated to v1.1.3
- All reading tasks use REQUEST.MODEL instead of MODEL.NAME.
- (TEMPORAL) AQUA-PUSH is disabled until the environment in the Autosubmit VM is updated to >v0.17.0.
- Integrated the HydroLand Python package into the workflow. Python HydroLand runscript; the workflow no longer bundles HydroLand scripts.
- Updated AQUA to v0.17.0.
- Updated the Data Portfolio to v2.1.0.
- Updated GSV to v2.13.1.
- OPA version 0.8.2a1 and energy indicators default resolution to 10km (temporarily).

### Fixed

- Made the model name uppercase in the AQUA push job.

## 5.3.0 (Released August 2025)

#### :sparkles: Highlights

This version enables reading from the Data Bridge of MareNostru5. At the same time, it disables AQUA from reading from the data bridge by updating the available dates in the WIPE.

### :notebook: List of changes

### Added

- Support to reading from MareNostrum5 data bridge.

### Updated

- Updated the AQUA version to v0.16.0.
- Updated the Data Portfolio version to v1.3.2.
- Updated the GSV version to v2.11.0.
- Update Energy Offshore to 0.4.8
- Disable AQUA reading from the data bridge by updating the available dates in the WIPE.

## 5.2.2 (Released August 2025)

#### :sparkles: Highlights

This version **fixes** the DN template to read again from DATABRIDGE

### Fixed

- DN sets proper `FDB_HOME` to platform's Databridge `FDB_HOME`.
- Fix missing file dependency in DATA retrieval workflow
- A conditional that determined whether to use the BRIDGE_EXPVER or the EXPVER for the transfer.

## 5.2.1 (Released August 2025)

#### :sparkles: Highlights

The NEMO and IFS-NEMO workflows can now run multiple start dates in one experiment.

### :notebook: List of changes

### Added

- The ability to run multiple start dates in one experiment in NEMO and IFS-NEMO (AQUA not supported at this time).
- A separate task for fix constant variables.
- Dataflow for DE_393.

### Changed

- The NEMO standalone SIM to use mpirun.
- Improve error handling in `hres` of IFS-NEMO.
- WIPE CHECK depends on TRANSFER+10, giving an automatic buffer of 10 chunks of data in the HPC.
- Removed legacy dependency in apps alone workflows.
- Deleted the `mother_request.yml`. Now the requests are defined in separated conf files. A file per application.
- `energy_indicators` updated to version 1.1.2.
- The transfer job to be able to update the EXPVER in the Marenostrum5-transfer machine.

## 5.2.0 (Released July 2025)

#### :sparkles: Highlights

In this new version there is an important rework on how the applications are configured, now as additional jobs. Relevant additions to ICON (volcanic aerosol forcing and lowres hist testcase option).

#### User action needed

If you are running applications and you are updating to 5.2.0, make sure that you adapt how the applciations are configured under your conf/main.yml.

### :notebook: List of changes

### Added

- Added daily max for energy windspeed 100m.
- Added `avg_sdswrf` to the data request for energy indicators.
- Added volcanic aersol forcings for ICON
- Added ICON R2B8 hist testcase option
- Option to run `wipe` with --unsafe-wipe-all, disabled by default.

### Changed

- Cleaned up if/else logic in Local and Remote Setup and moved logic into configuration files.
- Renamed `energy_onshore` by `energy_indicators` everywhere.
- Request is now global for energy indicators. Statistics that use t-digest inside the OPA have been temporarily disabled due to performance degradation.
- Applications are now treated as additional jobs. No more auxiliary python scripts for the joblist.
- Container calls were standardized.
- Parametrize ICON sim env variables
- Absolute paths in SYNCHRONIZE step to allow re-running it.
- Minor fixes in simless WIPE workflow.
- The MN5 databridge transfer to use FDB copy.

## 5.1.6 (Released August 2025)

#### :sparkles: Highlights

Release used in production that introduces fixes in the EXPVER of the WIPE.

## 5.1.5 (Released August 2025)

#### :sparkles: Highlights

Release used in production that introduces fixes in the bindings of the WIPE for the operational project.

## 5.1.4 (Released July 2025)

#### :sparkles: Highlights

Release used in production that introduces fixes that allow correctly changing the metadata (expver) of the data before transferring it, in LUMI.

## 5.1.3 (Released June 2025)

#### :sparkles: Highlights

This release includes upgrades in the TRANSFER jobs, environment variables for MN5 bridge performance, and email notifications for job failures. The OPA version was update, and a dependency was removed from the apps workflow.

### :notebook: List of changes

### Added

- Possibility to change metadata before the TRANSFER step.
- A check at the end of WIPE when WIPE_DOIT is not set.
- Intermediate checkpoint in TRANSFER that avoids unnecessary repetition of the retrieve step during retrials.
- Environment variables requested by ECMWF for MN5 bridge performance.
- Email notifications when jobs fail.
- Remote Setup as a dependency for more jobs so that jobs run in the correct order.

### Changed

- Updated OPA to v0.7.4
- LRA using second to last date instead of end date to update the catalog.
- Only sync with `datamover` when TRANSFER task is enabled.
- Removed legacy data request from energy onshore.
- Removed legacy dependency in app jobs template.
- Removed auxiliaty files for OPA `*_used`.
- Cleaned up if/else logic in Local and Remote Setup and moved logic into configuration files.

## 5.1.2 (Released June 2025)

#### Highlights

- First version of Tier 3 CPMIP metrics: Memory bloat, Data Intensity, Resolution and Complexity
- Integration of MareNostrum5 Data Bridge, using an intermediate VM (datamover).

### :notebook: List of changes

- Use HPC AS var prefix for catalog names
- WIPE job was split in 2: `wipe_check`, that is executed in the HPC and checks that the data is correctly transferred to the bridge, and `wipe`, which deletes the data.
- Fix for ICON "tcc" and "wind stress" data glitches
- Output for energy onshore is now yyyy/mm/dd directory structure.
- Fine-grained dependencies between different CHUNKs in OPAs and APPs.
- Add missing bindings to the sim_ifs-fesom template

#### Autosubmit version

- Tested with Autosubmit v4.1.14

## 5.1.1 (Released May 2025)

### :notebook: List of changes

#### Highlights

Minor improvements in the configuration.

#### Changed

- The logic to generate profiles comes from a configuration key, `CONFIGURATION.GENERATE_PROFILES`.
- Mains work now out of the box for mn5: apps alone, ifs-nemo alone and ifs-nemo-apps end-to-end.
- Simplified githook.
- Updated Autosubmit version to 4.1.14 in the pipelines.
- Made IO_NODES platform dependent for IFS-NEMO.
- Re-enabled NEMO standalone with precompiled versions.

## 5.1.0 (Released May 2025)

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
- Hydroland relies on previous Hydroland output-files to run for the first time, instead of relying on CHUNK and SPLIT as it was before here.

#### Removed

- References to Levante and Juwels as they are no longer supported.

#### User action required

## v5.0.5 (Released Apr 24 12:00 2025 +0200)

### :sparkles: Highlights

This operational release supports creating the AQUA catalog starting from a different startdate than the one from the experiment. It updates the catalog version to e25.1_v1 and adds the `operational` RUN.TYPE to set up all the operational configurations in MareNostrum5 and LUMI.

### :notebook: List of changes

#### Added

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
