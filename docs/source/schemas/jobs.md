### Jobs

Schema for the jobs section of the workflow

| Property | Type | Required | Possible Values | Deprecated | Default | Description |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- |
| LOCAL_SETUP | `object` | ✅ | object|  |  |  |
| REMOTE_SETUP | `object` | ✅ | object|  |  |  |
| SYNCHRONIZE | `object` | ✅ | object|  |  |  |
| INI | `object` |  | object|  |  |  |
| SIM | `object` |  | object|  |  |  |
| CHECK_MEM | `object` |  | object|  |  |  |
| DQC_BASIC | `object` |  | object|  |  |  |
| DQC_FULL | `object` |  | object|  |  |  |
| LRA_GENERATOR | `object` |  | object|  |  | Job for generating the Low Resolution Archive (LRA). |
| AQUA_ANALYSIS | `object` |  | object|  |  |  |
| AQUA_PUSH | `object` |  | object|  |  |  |
| CLEAN | `object` |  | object|  |  |  |
| APP_DATA | `object` |  | object|  |  |  |
| SYNC_LRA | `object` |  | object|  |  | Job to synchronize LRA output data to a centralized location |
| UPDATE_CATALOG | `object` |  | object|  |  | Job to update the AQUA catalog after LRA data has been synchronized |
| PUSH_UPDATED_CATALOG | `object` |  | object|  |  | Job to push the updated AQUA catalog with the central LRA path to the repository |
