## Model Icon

Schema for the MODEL section of the workflow, if the model is ICON.

### Type: `object`

| Property | Type | Required | Possible values | Description |
| -------- | ---- | -------- | --------------- | ----------- |
| NAME | `string` | ✅ | `icon` |  |
| ROOT_PATH | `string` | ✅ | string | Path to the root of the model directory where the different models and there different versions are stored by default. |
| PATH | `string` | ✅ | string | Path to the model directory, where the version of the model that you will use is/will be stored. |
| INPUTS | `string` | ✅ | string | Path to the directory where the input files are stored. |
| COMPILE | `string` | ✅ | `False` `True` | If the model will be compiled before running it. |
| GRID_ATM | `string` | ✅ | `r2b4` | Grid for the atmosphere model. |
| GRID_OCE | `string` | ✅ | `r2b4` | Grid for the ocean model. |
| SIMULATION | `string` | ✅ | `test-icon` | Simulation to run. |
