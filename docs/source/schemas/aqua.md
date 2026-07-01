### AQUA

Schema for the AQUA section of the workflow

#### Type: `object`

| Property | Type | Required | Possible values | Deprecated | Default | Description | Examples |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- | -------- |
| REGENERATE_CATALOGS | `string` | ✅ | `False` `True` |  |  | Flag to determine if catalogs should be regenerated. |  |
| CONTAINER_VERSION | `string` | ✅ | string |  |  | Specify the version of the container used in the workflow. |  |
| LOCAL_LRA_OUTPUT_PATH | `string` | ✅ | string |  |  | Local path to store LRA output data. |  |
| CENTRAL_LRA_OUTPUT_PATH | `string` | ✅ | string |  |  | Centralized path to store LRA output data. |  |
| INSTALL_DIR | `string` | ✅ | string |  |  | Directory to install AQUA. |  |
| SOURCE_HL | `string` | ✅ | string |  |  | Source for hourly-native-hl data. |  |
| SOURCE_O2D | `string` | ✅ | string |  |  | Source for daily-hpz5-oce2d data. |  |
| SOURCE_O3D | `string` | ✅ | string |  |  | Source for daily-hpz5-oce3d data. |  |
| SOURCE_PL | `string` | ✅ | string |  |  | Source for hourly-hpz5-atm3d data. |  |
| SOURCE_SFC | `string` | ✅ | string |  |  | Source for hourly-hpz5-atm2d data. |  |
| SOURCE_SOL | `string` | ✅ | string |  |  | Source for hourly-native-sol data. |  |
| VARS_HL | `string` | ✅ | string |  |  | Variables for hourly-native-hl data. |  |
| VARS_O2D | `string` | ✅ | string |  |  | Variables for daily-hpz5-oce2d data. |  |
| VARS_O3D | `string` | ✅ | string |  |  | Variables for daily-hpz5-oce3d data. |  |
| VARS_PL | `string` | ✅ | string |  |  | Variables for hourly-hpz5-atm3d data. |  |
| VARS_SFC | `string` | ✅ | string |  |  | Variables for hourly-hpz5-atm2d data. |  |
| VARS_SOL | `string` | ✅ | string |  |  | Variables for hourly-native-sol data. |  |
| WORKERS_HL | `integer` | ✅ | integer |  |  | Number of workers for hourly-native-hl data. |  |
| WORKERS_O2D | `integer` | ✅ | integer |  |  | Number of workers for daily-hpz5-oce2d data. |  |
| WORKERS_O3D | `integer` | ✅ | integer |  |  | Number of workers for daily-hpz5-oce3d data. |  |
| WORKERS_PL | `integer` | ✅ | integer |  |  | Number of workers for hourly-hpz5-atm3d data. |  |
| WORKERS_SFC | `integer` | ✅ | integer |  |  | Number of workers for hourly-hpz5-atm2d data. |  |
| WORKERS_SOL | `integer` | ✅ | integer |  |  | Number of workers for hourly-native-sol data. |  |
| RESOLUTION_OCE | `string` | ✅ | string |  |  | Resolution for ocean data. |  |
| RESOLUTION_ATM | `string` | ✅ | string |  |  | Resolution for atmosphere data. |  |
| GRID_OCE | `string` |  | string |  |  | Ocean grid name for AQUA grid building. For IFS-FESOM inherited from MODEL.GRID_OCE; for IFS-NEMO set explicitly (e.g., eORCA12). | `CORE2` `NG5` `eORCA12` |
| GRID_VERSION | `integer` |  | `3` `4` |  |  | Grid version number for AQUA grid building. v4 for IFS-FESOM, v3 for IFS-NEMO/ICON. |  |
| START_DATE | `string` |  | string |  |  | Override catalog start date for LRA processing (format: YYYYMMDD). If not set, defaults to experiment start date (SDATE). LRA will process all available data from this date onwards, intelligently skipping already-processed months. |  |
| BUCKET | `string` |  | string |  |  | Bucket to push the data in AQUA-push. |  |
