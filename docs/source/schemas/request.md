### Request

Request that is used by APPS to retrieve data from the fdb, and for the MODEL to find the correct data in the fdb (used in DQC, AQUA).

#### Type: `object`

| Property | Type | Required | Possible values | Deprecated | Default | Description | Examples |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- | -------- |
| CLASS | `string` | ✅ | `d1` `rd` |  |  | Experiment class for data government. `d1` is production(?), `rd` is research. |  |
| EXPVER | `string` | ✅ | [`^[A-Za-z0-9]{4}$`](https://regex101.com/?regex=%5E%5BA-Za-z0-9%5D%7B4%7D%24) |  |  | Experiment version string used to identify experiments. Needs to be `0001` for production experiments. |  |
| FDB_HOME | `string` | ✅ | string |  |  | Home directory of the fdb that is to be used. |  |
| ACTIVITY | `string` | ✅ | `baseline` `projections` |  |  | Activity key in the FDB |  |
| REALIZATION | `integer` | ✅ | integer |  |  | Realization key in the FDB |  |
| GENERATION | `integer` | ✅ | `1` `2` |  |  | Generation key in the FDB |  |
| EXPERIMENT | `string` | ✅ | `cont` `hist` `SSP3-7.0` |  |  | Experiment key in the FDB |  |
| MODEL | `string` | ✅ | `icon` `ifs-nemo` `ifs-fesom` |  |  | Model key in the FDB |  |
| INFO_FILE_PATH | `string` |  | string |  |  | Path to the FDB directory within the experiment folder |  |
| INFO_FILE_NAME | `string` |  | string |  |  | Path to the YAML file within the FDB directory of the experiment folder |  |
| RESOLUTION | `string` |  | `standard` `high` |  |  | Sets the resolution |  |
