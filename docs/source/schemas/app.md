### App

Schema for the app section of the workflow

#### Type: `object`

| Property | Type | Required | Possible values | Deprecated | Default | Description | Examples |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- | -------- |
| OUTPATH | `string` | ✅ | string |  |  | Path to the output directory |  |
| ENERGY_INDICATORS | `string` |  | `False` `True` |  |  | If energy indicators enabled |  |
| ENERGY_OFFSHORE | `string` |  | `False` `True` |  |  | If energy offshore enabled |  |
| HYDROLAND | `string` |  | `False` `True` |  |  | If hydroland enabled |  |
| HYDROMET | `string` |  | `False` `True` |  |  | If hydromet enabled |  |
| WILDFIRES_FWI | `string` |  | `False` `True` |  |  | If wildfires FWI enabled |  |
| WILDFIRES_WISE | `string` |  | `False` `True` |  |  | If wildfires WISE enabled |  |
| OBSALL | `string` |  | `False` `True` |  |  | If OBSALL enabled |  |
| DATA | `string` |  | `False` `True` |  |  | If data workflow enabled |  |
| READ_FROM_DATABRIDGE | `string` |  | `False` `True` |  |  | If the data will be read from the databridge |  |
