### App

Schema for the app section of the workflow

#### Type: `object`

| Property | Type | Required | Possible values | Deprecated | Default | Description | Examples |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- | -------- |
| OUTPATH | `string` | ✅ | string |  |  | Path to the output directory |  |
| ENERGY_INDICATORS | `string` |  | `False` `True` |  |  | If energy indicators enabled |  |
| ENERGY_INDICATORS_WRAPPER | `string` |  | `False` `True` |  |  | If the energy indicators wrapper is enabled (loads `conf/additional_jobs/energy_indicators_wrapper-True.yml`). |  |
| ENERGY_OFFSHORE | `string` |  | `False` `True` |  |  | If energy offshore enabled |  |
| ENERGY_OFFSHORE_WRAPPER | `string` |  | `False` `True` |  |  | If the energy offshore wrapper is enabled (loads `conf/additional_jobs/energy_offshore_wrapper-True.yml`). |  |
| HYDROLAND | `string` |  | `False` `True` |  |  | If hydroland enabled |  |
| HYDROLAND_WRAPPER | `string` |  | `False` `True` |  |  | If the hydroland wrapper is enabled (loads `conf/additional_jobs/hydroland_wrapper-True.yml`). |  |
| HYDROMET | `string` |  | `False` `True` |  |  | If hydromet enabled |  |
| HYDROMET_WRAPPER | `string` |  | `False` `True` |  |  | If the hydromet wrapper is enabled (loads `conf/additional_jobs/hydromet_wrapper-True.yml`). |  |
| WILDFIRES_FWI | `string` |  | `False` `True` |  |  | If wildfires FWI enabled |  |
| WILDFIRES_FWI_WRAPPER | `string` |  | `False` `True` |  |  | If the wildfires FWI wrapper is enabled (loads `conf/additional_jobs/wildfires_fwi_wrapper-True.yml`). |  |
| WILDFIRES_WISE | `string` |  | `False` `True` |  |  | If wildfires WISE enabled |  |
| WILDFIRES_WISE_WRAPPER | `string` |  | `False` `True` |  |  | If the wildfires WISE wrapper is enabled (loads `conf/additional_jobs/wildfires_wise_wrapper-True.yml`). |  |
| OBSALL | `string` |  | `False` `True` |  |  | If OBSALL enabled |  |
| OBSALL_WRAPPER | `string` |  | `False` `True` |  |  | If the OBSALL wrapper is enabled (loads `conf/additional_jobs/obsall_wrapper-True.yml`). |  |
| DATA | `string` |  | `False` `True` |  |  | If data workflow enabled |  |
| READ_FROM_DATABRIDGE | `string` |  | `False` `True` |  |  | If the data will be read from the databridge |  |
