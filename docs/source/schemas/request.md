## Request

Request that is used by APPS to retrieve data from the fdb (currently also used by model to find fdb etc. :(

### Type: `object`

| Property | Type | Required | Possible values | Description |
| -------- | ---- | -------- | --------------- | ----------- |
| CLASS | `string` | ✅ | `d1` `rd` | Experiment class for data government. `d1` is production(?), `rd` is research. |
| EXPVER | `string` | ✅ | [`^[A-Za-z0-9]{4}$`](https://regex101.com/?regex=%5E%5BA-Za-z0-9%5D%7B4%7D%24) | Experiment version string used to identify experiments. Needs to be `0001` for production experiments. |
| FDB_HOME | `string` | ✅ | string | Home directory of the fdb that is to be used. |
| ACTIVITY | `string` | ✅ | `ScenarioMIP` `CMIP6` `HighResMIP` | Activity key in the FDB |
| REALIZATION | `integer` | ✅ | integer | Realization key in the FDB |
| GENERATION | `integer` | ✅ | integer | Generation key in the FDB |
| EXPERIMENT | `string` | ✅ | `cont` `hist` `SSP3-7.0` | Experiment key in the FDB |
| MODEL | `string` | ✅ | `ICON` `IFS-NEMO` `IFS-FESOM` | Model key in the FDB |
