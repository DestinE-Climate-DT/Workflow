### Run

Schema for the RUN section of the workflow

| Property | Type | Required | Possible Values | Deprecated | Default | Description |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- |
| TYPE | `string` | ✅ | `production` `research` `pre-production` `test`|  |  | The type of run to be executed, it will set the data governance |
| WORKFLOW | `string` | ✅ | `end-to-end` `model` `apps` `simless`|  |  | The type of workflow to run, it will set the joblist |
| ENVIRONMENT | `string` | ✅ | `cray` `intel`|  |  | The environment in which the workflow is run |
| PROCESSOR_UNIT | `string` | ✅ | `cpu` `gpu` `gpu_gpu`|  |  | The processor unit used to run the workflow |
| if | `None` |  | None|  |  |  |
| then | `None` |  | None|  |  |  |
| else | `None` |  | None|  |  |  |
| SUITE | `string` |  | `e-suite` `o-suite`|  |  | The suite to be used for the run, it will set the model and the joblist |
