## Experiment

Schema for the Experiment section of the workflow

### Type: `object`

| Property | Type | Required | Possible values | Description |
| -------- | ---- | -------- | --------------- | ----------- |
| DATELIST | `integer` | ✅ | integer | List of dates to run the simulation. |
| CHUNKSIZEUNIT | `string` | ✅ | `hour` `day` `month` `year` | Unit of the chunk size. |
| CHUNKSIZE | `integer` | ✅ | integer | Size of the chunk, in CHUNKSIZEUNITs. |
| NUMCHUNKS | `integer` | ✅ | integer | Number of chunks to run. |
| CALENDAR | `string` | ✅ | `noleap` `standard` | Calendar to use. |
| MEMBERS | `string` |  | string | Name of ensemble members. (Example: fc0 fc1 fc2) |
