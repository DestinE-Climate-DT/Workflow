### Jobs

Schema for the jobs section of the workflow

#### Type: `object`

| Property | Type | Required | Possible values | Deprecated | Default | Description | Examples |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- | -------- |
| LOCAL_SETUP | `object` | ✅ | object |  |  |  |  |
| REMOTE_SETUP | `object` | ✅ | object |  |  |  |  |
| SYNCHRONIZE | `object` | ✅ | object |  |  |  |  |
| INI | `object` |  | object |  |  |  |  |
| SIM | `object` |  | object |  |  |  |  |
| CHECK_MEM | `object` |  | object |  |  |  |  |
| DQC_BASIC | `object` |  | object |  |  |  |  |
| DQC_FULL | `object` |  | object |  |  |  |  |
| LRA_GENERATOR | `object` |  | object |  |  | Job for generating the Low Resolution Archive (LRA). |  |
| AQUA_ANALYSIS | `object` |  | object |  |  |  |  |
| AQUA_PUSH | `object` |  | object |  |  |  |  |
| CLEAN | `object` |  | object |  |  |  |  |
| APP_DATA | `object` |  | object |  |  |  |  |
