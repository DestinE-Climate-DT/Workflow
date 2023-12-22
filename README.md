# Climate DT (DE_340) workflow
Welcome to the Climate DT Workflow documentation!

Version v3.0.0. Which includes v2.0.0 + applications

## About the project 
This workflow contains a preliminary version of the DE_340 workflow. It is used for development and testing in conjunction with [Autosubmit4](https://earth.bsc.es/gitlab/es/autosubmit). The implemented workflow tasks keep a model-agnostic interface and contain the merged sub-workflows for ICON, IFS-FESOM, and IFS-NEMO. Currently, LUMI is supported for IFS-NEMO and ICON to perform basic simulations. MareNostrum4 is supported for IFS-NEMO.

### Current list of steps:
Each step contains a very short description of its main purpose. The templates are located in `/workflow/templates`.
* `local_setup:` performs basic checks as well as compressing the workflow project in order to be sent through the network. Runs in the Autosubmit VM. 
* `synchronize:` syncs the workflow project with the remote platform. Runs in the Autosubmit VM.
* `remote_setup: ` loads the necessary enviroment and then compiles the diferent models. Performs checks in the remote platform. Runs in the remote platform (login nodes for LUMI, interactive partition for MN4).
* `ini: ` prepares any necessary initial data for the climate model runs. 
* `sim: ` runs one chunk of climate simulation.
* `dn: ` notifies when the wanted data is already produced by the model.
* `opa:` creates the statistics required by the data consumers (Apps)
* `applications:` creates usable output using the applications from the different use cases 

### Selectable configuration

We are now running the workflow with the new version of the CUSTOM_CONFIG and the minimal configuration new features of Autosubmit. This new configuration scheme allows for a distributed, hierarchical parametrization of the workflow, thereby providing a more customizable, modular, and user-friendly workflow. The structure, domain and use of this new configuration scheme will likely evolve as it adapts to the needs of other work packages.

## Getting Started
All the experiments should be created in the [Autosubmit Virtual Machine](https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+VM). To access the VM, you need a user and your SSH key to be authorized. Add your name, e-mail, preferred username, and SSH (local) public key to the [table](https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+VM+Users). 

Make sure you have a recent Autosubmit version running `autosubmit --version`. This workflow has been developed using the `4.1.0` version of Autosubmit. Otherwise update it by typing  `module load autosubmit/v4.1.0-beta`. You can follow more detailed description about Autosubmit in [Autosubmit Readthedocs](https://autosubmit.readthedocs.io/en/master/). 

### Prerequisites
Inside the Autosubmit VM, you need to put your user configurations for platforms somewhere (we recommend `~/platforms.yml`):
```
# personal platforms file 
# this overrides keys the default platforms.yml

Platforms:
  lumi-login:
    USER: <USER> 
  lumi:
    USER: <USER>
  marenostrum4:
    USER: <USER>
  marenostrum4-login:
    USER: <USER>
```

You also need to configure password-less access to the platforms where you want to run
experiments. Further instructions can be found [here](https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+VM) (Section 4. How to get password-less access from VM to Levante / LUMI / MN4).

### Create your own experiment

1. Create an Autosubmit experiment using minimal configurations.

> **NOTE**: you MUST change `<TYPE_YOUR_PLATFORM_HERE>` below with your platform!
For example: lumi, marenostrum4, juwels, levnte... **For the current deliverable the platform is meant to run in lumi.**
> Check the available platforms at `/appl/AS/DefaultConfigs/platforms.yml`
> or `~/platforms.yml` if you created this file in your home directory.

```
autosubmit expid \
  --description "A useful description" \
  --HPC <TYPE_YOUR_PLATFORM_HERE> \
  --minimal_configuration \
  --git_as_conf conf/bootstrap/ \
  --git_repo https://earth.bsc.es/gitlab/digital-twins/de_340/workflow \
  --git_branch v3.0.0
```

You will receive the following message: `Experiment <expid> created`, where `<expid>`
is the identifier of your experiment. A directory will be created for your experiment
at: `/appl/AS/AUTOSUBMIT_DATA/<expid>`.

2. The command `autosubmit expid` above will create a `minimal.yml` file for you.
Modify this file (e.g. `/appl/AS/AUTOSUBMIT_DATA/<expid>/conf/minimal.yml`) as needed.

In the `GIT` section in the `minimal.yml`, you can use `PROJECT_SUBMODULES` to set
the Git submodules for the models you want to run (e.g.: `icon-mpim`, `ifs-fesom`,
`ifs-nemo`). Or leave it empty to select all the models. Autosubmit will clone
them when you run `autosubmit create` (first run) or `autosubmit refresh`.

**For the current deliverable you should use the following submodules:**
 `  PROJECT_SUBMODULES: 'one_pass gsv_interface aqua mhm wildfires_fwi urban'`

> **NOTE**: you need to have access to the corresponding model sources
> repository and your ssh keys must be uploaded there.

**For the current deliverable you should set `TOTALJOBS: 2` and `MAXWAITINGJOBS: 2` As for testing purposes we are using the debug queue so that waitig time is avoided**
```
CONFIG:
  # Current version of Autosubmit.
  AUTOSUBMIT_VERSION: "4.1.0"
  # Total number of jobs in the workflow.
  TOTALJOBS: 2
  # Maximum number of jobs permitted in the waiting status.
  MAXWAITINGJOBS: 2

```

3. In `/appl/AS/AUTOSUBMIT_DATA/<expid>/conf/`, create a `main.yml` file (e. g.: `vim main.yml`), copy the following keys and fill the fields with the model, simulation etc. that you want to run:

```
RUN:
  SIMULATION: test-ifs-nemo
  # Physical parameters will be defined here. Current options: default.  
  # Current options: ifs-nemo.
  MODEL: ifs-nemo
  # Current options: none
  READ_EXPID: #<----------*Update with the expid that you were given after creating the experiment*
  GRID_ATM: tco79l137
  # Current options:
    # ICON: r2b4
    # Nemo: eORCA1_Z75
  GRID_OCEAN: eORCA1_Z75
  MODEL_VERSION: "dev-aina" 
  # openmpo, gcc, intel...
  ENVIRONMENT: "cray"
  CLEAN_RUN: "true"
  PROCESSOR_UNIT: "gpu"

APP:
  OUTPATH: "/scratch/project_465000454/tmp/%RUN.READ_EXPID%/"

JOBS:
   SIM:
     WALLCLOCK: "00:10"
     NODES: 4


EXPERIMENT:
   DATELIST: 19900101 #Startdate
   MEMBERS: fc0
   CHUNKSIZEUNIT: day
   CHUNKSIZE: 3
   NUMCHUNKS: 1
   CALENDAR: standard


CONFIGURATION:
        IFS:
                MULTIO_PLANS: "historical"
        NEMO:
                MULTIO_PLANS: "historical"

```

### Execute the workflow

Now you can run the workflow:

```bash
autosubmit run <expid>
```

Whenever you change something in the git repository make sure you refresh your experiment:

> **BE CAREFUL!** This command will overwrite any changes in the local project folder.
> Note that this is doing the same thing that the `autosubmit create` did in a previous
> step, but `autosubmit create` only refreshes the git repository the first time it is
> executed:

```bash
autosubmit refresh <expid>
```

Then you need autosubmit to create the updated the workflow files again:

```bash
autosubmit create <expid> -v -np
```

This resets the status of all the jobs, so if you do not want to run everything from
the beginning again, you can set the status of tasks, for example:

```bash
autosubmit setstatus a002 -fl "a002_LOCAL_SETUP a002_SYNCHRONIZE a002_REMOTE_SETUP" -t COMPLETED -s
```

`-fl` is for filter, so you filter them by job name now, `-t` is for target status(?)
so, we set them to `COMPLETED` here. `-s` is for save, which is needed to save the
results to disk.

You can add a `-np` for “no plot” to most of the commands to not have the error with
missing `xdg-open`, etc.

## Contributing
This workflow is work in progress, and suggestions and contributions are greatly appreciated. If you have a suggestion, desire some new feature, or detect a bug, please: 

1. Open an issue in this GitLab explaining it. 
2. Once the issue is completely defined and assigned to someone, it will be tagged with the `to do` label.
3. Once someone is working in the issue, it will be tagged with the `working on` label.

If you want to develop yourself:
1. Create an experiment in the VM.
2. Create a branch locally and make the changes that you want to implement. Make us of the [Shell Style Guide](urlhttps://google.github.io/styleguide/shellguide.html). 
3. Test your changes.
4. Apply [Shellcheck](https://www.shellcheck.net/) to your code. 
4. Once you tested the workflow, add, commit and push your changes into a new branch.
5. Create a merge request. 
6. The workflow developers will test it and merge.

## Contact us!
For any doubts or issues you can contact the workflow developers:

- Miguel Castrillo (Work package leader): miguel.castrillo@bsc.es
- Leo Arriola (ICON Workflow developer): leo.arriola@bsc.es
- Sebastian Beyer (IFS-Fesom Workflow developer): sebastian.beyer@awi.de
- Francesc Roura (Applications Workflow developer): francesc.roura@bsc.es
- Aina Gaya (IFS-Nemo Workflow developer): aina.gayayavila@bsc.es

Main Autosubmit support:

- Daniel Beltrán (daniel.beltran@bsc.es)
- Bruno de Paula Kinoshita (bruno.depaulakinoshita@bsc.es)

[Link to the Autosubmit tutorial & Hands-on](https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+introductory+session)

</details>


