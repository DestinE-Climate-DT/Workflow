## AQUA

Schema for the AQUA section of the workflow

### Type: `object`

| Property | Type | Required | Possible values | Description |
| -------- | ---- | -------- | --------------- | ----------- |
| CONTAINER_VERSION | `string` |  | string | Specify the version of the container used in the workflow. |
| SOURCE_HL | `string` |  | string | Source for hourly-native-hl data. |
| SOURCE_O2D | `string` |  | string | Source for daily-hpz5-oce2d data. |
| SOURCE_O3D | `string` |  | string | Source for daily-hpz5-oce3d data. |
| SOURCE_PL | `string` |  | string | Source for hourly-hpz5-atm3d data. |
| SOURCE_SFC | `string` |  | string | Source for hourly-hpz5-atm2d data. |
| SOURCE_SOL | `string` |  | string | Source for hourly-native-sol data. |
| VARS_HL | `string` |  | string | Variables for hourly-native-hl data. |
| VARS_O2D | `string` |  | string | Variables for daily-hpz5-oce2d data. |
| VARS_O3D | `string` |  | string | Variables for daily-hpz5-oce3d data. |
| VARS_PL | `string` |  | string | Variables for hourly-hpz5-atm3d data. |
| VARS_SFC | `string` |  | string | Variables for hourly-hpz5-atm2d data. |
| VARS_SOL | `string` |  | string | Variables for hourly-native-sol data. |
| WORKERS_HL | `integer` |  | integer | Number of workers for hourly-native-hl data. |
| WORKERS_O2D | `integer` |  | integer | Number of workers for daily-hpz5-oce2d data. |
| WORKERS_O3D | `integer` |  | integer | Number of workers for daily-hpz5-oce3d data. |
| WORKERS_PL | `integer` |  | integer | Number of workers for hourly-hpz5-atm3d data. |
| WORKERS_SFC | `integer` |  | integer | Number of workers for hourly-hpz5-atm2d data. |
| WORKERS_SOL | `integer` |  | integer | Number of workers for hourly-native-sol data. |
