## GSV

Schema for the GSV section of the workflow

### Type: `object`

| Property | Type | Required | Possible values | Default | Description |
| -------- | ---- | -------- | --------------- | ------- | ----------- |
| VERSION | `string` | ✅ | string | `"2.6.0"` | Specify the version of the GSV_interface container used in the workflow. |
| WEIGHTS_PATH | `string` | ✅ | string | `"%CONFIGURATION.HPC_PROJECT_DIR%/gsv_files/gsv_weights"` | Path to the weights. |
| TEST_FILES | `string` | ✅ | string | `"%CONFIGURATION.HPC_PROJECT_DIR%/gsv_files/gsv_test_files"` | Path to the test files. |
| DEFINITION_PATH | `string` | ✅ | string | `"%CONFIGURATION.HPC_PROJECT_DIR%/gsv_files/grid_definitions"` | Path to the grid definitions. |
