### IFS-based MODELS

Schema for the MODEL section of the workflow for IFS-based models

| Property | Type | Required | Possible Values | Deprecated | Default | Description |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- |
| NAME | `string` | ✅ | `ifs-fesom` `ifs-nemo`|  |  | Name of the model to run the simulation. |
| ROOT_PATH | `string` | ✅ | string|  |  | Path to the root of the model directory where the different models and there different versions are stored by default. |
| PATH | `string` | ✅ | string|  |  | Path to the model directory, where the version of the model that you will use is/will be stored. |
| INPUTS | `string` | ✅ | string|  |  | Path to the directory where the input files are stored. |
| COMPILE | `string` | ✅ | `False` `True`|  |  | If the model will be compiled before running it. |
| GRID_ATM | `string` | ✅ | `tco79l137` `tc0399l137` `tco1279l137` `tco2559l137`|  |  | Grid for the atmosphere model. |
| GRID_OCE | `string` | ✅ | `eORCA1_Z75` `eORCA12_Z75` `eORCA025_Z75` `eORCA1` `eORCA12` `eORCA025` `CORE2` `NG5` `DARS` `D3`|  |  | Grid for the ocean model. |
| SIMULATION | `string` | ✅ | `control-ifs-nemo` `test-ifs-nemo` `ifs-fesom-projection-ssp370-tco2559` `ifs-fesom-projection-ssp126-tco2559` `historical-ifs-nemo` `SSP370-ifs-nemo`|  |  | Simulation to run. |
| ICMCL_PATTERN | `string` | ✅ | string|  |  | Pattern to search for the ICMCL files. |
| DVC_INPUTS_BRANCH | `string` |  | string|  |  | Branch of the DVC repository where the input files are stored. |
| USE_FIXED_DVC_COMMIT | `string` |  | `False` `True`|  |  | If set to true, the version used is the one pinned as a submodule by the workflow. If set to false, the value of MODEL.DVC_INPUTS_BRANCH (branch or commit) is checked out in the local setup. |
| RESTARTS_FROM_PATH | `string` |  | string|  |  | Path to the directory where the restart files from a previous simulation are stored. |
| BUNDLE_BUILD_DIR | `string` |  | string|  |  | Path to the directory where the IFS/NEMO bundle is or will be built. |
| BUNDLE_SOURCE_DIR | `string` |  | string|  |  | Path to the directory where the IFS/NEMO bundle source code is stored. |
| FDB_DIRS | `string` |  | string|  |  | Path to the directory of the native, healpix and latlon FDB. |
| RAPS | `object` |  | object|  |  | RAPS flags to be used in the simulation. |
