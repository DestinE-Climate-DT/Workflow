## IFS-based MODELS

Schema for the MODEL section of the workflow for IFS-based models

### Type: `object`

| Property | Type | Required | Possible values | Description |
| -------- | ---- | -------- | --------------- | ----------- |
| NAME | `string` | ✅ | `ifs-fesom` `ifs-nemo` |  |
| ROOT_PATH | `string` | ✅ | string | Path to the root of the model directory where the different models and there different versions are stored by default. |
| PATH | `string` | ✅ | string | Path to the model directory, where the version of the model that you will use is/will be stored. |
| INPUTS | `string` | ✅ | string | Path to the directory where the input files are stored. |
| COMPILE | `string` | ✅ | `False` `True` | If the model will be compiled before running it. |
| GRID_ATM | `string` | ✅ | `tco79l137` `tc0399l137` `tco1279l137` `tco2559l137` | Grid for the atmosphere model. |
| SIMULATION | `string` | ✅ | `control-ifs-nemo` `test-ifs-nemo` `ifs-fesom-projection-tco2559` `historical-ifs-nemo` `SSP370-ifs-nemo` | Simulation to run. |
| ICMCL_PATTERN | `string` | ✅ | string | Pattern to search for the ICMCL files. |
| GRID_OCE | `string` |  | `eORCA1_Z75` `eORCA12_Z75` | Grid for the ocean model. |
| DVC_INPUTS_BRANCH | `string` |  | string | Branch of the DVC repository where the input files are stored. |
