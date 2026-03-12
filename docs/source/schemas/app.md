## App

Schema for the app section of the workflow

### Type: `object`

| Property | Type | Required | Possible values | Description |
| -------- | ---- | -------- | --------------- | ----------- |
| NAMES | `list` | ✅ | list | List of applications to run |
| OUTPATH | `string` | ✅ | string | Path to the output directory |
| READ_FROM_DATABRIDGE | `string` |  | `False` `True` | If the data will be read from the databridge |
