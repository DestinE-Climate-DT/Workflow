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

## Unreleased

### Added

### Changed

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
- Memory monitoring tools: https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/113
- Automatise the compilation in the common directory: https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/128
- Set different number of IO nodes for IFS and for NEMO: https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/124
- RAPS is now part of the ifs-bundle & writing to 3 FDBs: https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/130 & https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/merge_requests/94
- Using inputs from the DVC repository: https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/105

## DE_CY48R1.0_climateDT_20231214 (Released Thu Jan 11 17:28:30 2024 +0100)

Workflow version compatible with tag DE_CY48R1.0_climateDT_20231214 of ifs-bundle. Includes:  - Memory monitoring tools: https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/113 - Automatise the compilation in the common directory: https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/128 - Set different number of IO nodes for IFS and for NEMO: https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/124 - RAPS is now part of the ifs-bundle & writing to 3 FDBs: https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/130 & https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/merge_requests/94 - Using inputs from the DVC repository: https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/105

## app-v0.2.1 (Released Thu Jan 11 12:02:18 2024 +0100)

**What is new:**

New release app-v.0.2.1:
* allows using the new Data Governance
* Renewed README
* New versions GSV_interface 11.1, OPA 0.5.1
* Improvements in applications: AQUA, MHM, URBAN.

## v3.0.0 (Released Fri Dec 22 12:03:33 2023 +0100)

Tag corresponding to deliverable D340.8.3.1.

It contains the v2.0.0 (D340.6.2.2) plus the applications workflow.

## v.2.1.0 (Released Tue Dec 19 11:24:17 2023 +0100)

Contains:  - Writing to a common FDB, with 3 FDBs with different resolutions in case of IFS-NEMO. - Memory monitoring tools. - Usage of DVC inputs. - Collection of bug-fixes.

## app-v0.2.0 (Released Mon Nov 20 12:10:27 2023 +0100)

*What is new:*

+ Capability to read from different FDBs
+ End to end can be used
+ Updates in app integration
+ Containerisation of some of the components 
+ Ported successfully to MN4
+ More robust way to run an experiment explained in a renovated README

## end2end-0.0.1 (Released Fri Oct 27 14:16:50 2023 +0200)

Code from used to run the first version of the end to end workflow (model+application) (IFS-NEMO-Tco79-eORCA1), from the dev branch: `dev-model-app`

Successfully run in LUMI on 19th Oct

## app-v0.1.10 (Released Wed Oct 18 18:29:13 2023 +0200)

*What is new:*

* FWI, MHM and AQUA totally integrated.
FWI: fully integrated
MHM: mrm integration nearly done
AQUA: run in container. Dummy runscript. ready to add any non dummy aqua runscript.

* improvements in the implementation of other apps even though not finished

## v2.0.0 (Released Wed Oct 18 09:15:04 2023 +0200)

LUMI is supported for IFS-NEMO and ICON to perform test and development simulations. IFS-FESOM can run in LUMI for test resolution (tco79). MareNostrum4 is supported for IFS-NEMO to perform all types of simulations. ICON runs using hetjobs, and IFS-NEMO can run both in LUMI-C and LUMI-G.

## v1.1.1 (Released Mon Oct 16 16:36:52 2023 +0200)

Stable IFS-NEMO workflow, before the merge with changes from ICON workflow. Linked to DE340_CY48R1_BSC_experimental branch of ifs-bundle and raps. Can run in LUMI-G and LUMI-C with automatic compilation, and in MareNostrum4 with a precompiled version. Includes: - Custom configurations https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/10 - Restarts handling https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/18 - Yeartly ICMCL files https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/20#note_213402 - Checkers https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/61 - Automatically switching MultIO plans: https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/67 - Enable retrials inside wrappers https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/merge_requests/34 - Running in GPU partition of LUMI https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/issues/71

## app-v0.1.9 (Released Mon Oct 9 15:12:41 2023 +0200)

*What is new:*

* Energy offshore added as submodule

## app-v0.1.8 (Released Thu Oct 5 15:35:35 2023 +0200)

**What is new:**

* Issue with AQUA cloning fixed 

AQUA can be cloned as usual now, using "aqua" in main.yml

## app-v0.1.7 (Released Thu Sep 28 14:21:19 2023 +0200)

**What is new:**

* new versions of GSV_interface (0.7.0), OPA (0.4.2). And changes in the workflow changed accordingly.
* Submodules for wildfires_wise and wildfire_fwi created
* DN is now faster

## app-v0.1.6 (Released Fri Sep 1 14:50:27 2023 +0200)

**What is new:**

- energy_onshore, mHM, AQUA integrated.
- AQUA is integrated using a container. First application to be deployed in the WF using this method.

## app-v0.1.5 (Released Tue Aug 8 17:53:45 2023 +0200)

**What is new:**

*  gsv_interface includes the new, faster version tag = v0.5.0
* `mhm` included as a submodule

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

* Requests can contain several variables and statistics and will be computed at once, using the OPA new parallelisation.   
* This workflow uses the new FDB with 4yr of data. It is more stable and contains more data (vversions < v0.1.2 use 2 yrs).
* Internally the workflow uses steps instead of dates.

## app-v0.1.2 (Released Wed Jul 5 12:06:30 2023 +0200)

*WHAT IS NEW:*

- Unified configuration: streaming, opa request and gsv request
- Option to get the raw data using OPA by `stats: "raw"`

## app-v0.1.1 (Released Thu Jun 29 18:06:39 2023 +0200)

* Bug fixed. One pass submodule now pointing to the correct commit. * Variables in the template files passed using correct syntax

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

