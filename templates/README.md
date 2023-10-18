# Climate DT (DE_340) workflow
Welcome to the Climate DT Workflow documentation!

<details><summary>Table of contents:</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#Current-list-of-steps">Current list of steps</a></li>
        <li><a href="#Selectable-configuration">Selectable configuration</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#create-your-own-experiment">Create your own experiment</a></li>
        <li><a href="#configure-your-experiment">Configure your experiment</a></li>
        <li><a href="#execute-the-workflow">Execute the workflow</a></li>
      </ul>
    </li>
    <li><a href="#contributing">Contributing </a></li>
    <li><a href="#contact-us">Contact us! </a></li>
  </ol>

</details>

## About the project 
This workflow contains a preliminary version of the DE_340 workflow. It is used for development and testing in conjunction with [Autosubmit4](https://earth.bsc.es/gitlab/es/autosubmit). The implemented workflow tasks keep a model-agnostic interface and contain the merged sub-workflows for ICON, IFS-FESOM, and IFS-NEMO. Currently, LUMI is supported for IFS-NEMO and ICON to perform basic simulations. MareNostrum4 is supported for IFS-NEMO.

### Current list of steps:
Each step contains a very short description of its main purpose. The templates are located in `/workflow/templates`.
* `local_setup:` performs basic checks as well as compressing the workflow project in order to be sent through the network. Runs in the Autosubmit VM. 
* `synchronize:` syncs the workflow project with the remote platform. Runs in the Autosubmit VM.
* `remote_setup: ` loads the necessary enviroment and then compiles the diferent models. Performs checks in the remote platform. Runs in the remote platform (login nodes for LUMI, interactive partition for MN4).
* `ini: ` prepares any necessary initial data for the climate model runs. 
* `sim: ` runs one chunk of climate simulation.

### Selectable configuration

We are now running the workflow with the new version of the CUSTOM_CONFIG and the minimal configuration new features
of Autosubmit. This new configuration scheme allows for a distributed, hierarchical parametrization of the workflow, thereby providing a more customizable, modular, and user-friendly workflow. The structure, domain and use of this new configuration scheme will likely evolve as it adapts to the needs of other work packages.

## Getting Started
All the experiments should be created in the [Autosubmit Virtual Machine](https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+VM). To access the VM, you need a user and your SSH key to be authorized. Add your name, e-mail, preferred username, and SSH (local) public key to the [table](https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+VM+Users). 

Make sure you have a recent Autosubmit version running `autosubmit --version`. This workflow has been developed using the `4.0.0b0` version of Autosubmit. You can follow more detailed description in [Autosubmit Readthedocs](https://autosubmit.readthedocs.io/en/master/). 


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
experiments. Further instructions can be found [here](https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+VM)
(Section 4. How to get password-less access from VM to Levante / LUMI / MN4).

### Create your own experiment

1. Create an Autosubmit experiment using minimal configurations.

> **NOTE**: you MUST change `<TYPE_YOUR_PLATFORM_HERE>` below with your platform!
For example: levante, lumi, marenostrum4, juwels...
> etc. Check the available platforms at `/appl/AS/DefaultConfigs/platforms.yml`
> or `~/platforms.yml` if you created this file in your home directory.

```
autosubmit expid \
  --description "A useful description" \
  --HPC <TYPE_YOUR_PLATFORM_HERE> \
  --minimal_configuration \
  --git_as_conf conf/bootstrap/ \
  --git_repo https://earth.bsc.es/gitlab/digital-twins/de_340/workflow \
  --git_branch main
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

> **NOTE**: you need to have access to the corresponding model sources
> repository and your ssh keys must be uploaded there.

3. In `/appl/AS/AUTOSUBMIT_DATA/<expid>/conf/`, create a `main.yml` file (e. g.: `vim main.yml`), copy the following keys and fill the fields with the model, simulation etc. that you want to run:

```
RUN:
  # Sets the EXPERIMENT variables (datelist, number of chunks...). Current options: test-icon, test-ifs-fesom, test-ifs-nemo. 
  SIMULATION: 
  # Physical parameters will be defined here. Current options: default.  
  PARAMETER: default
  # Current options: icon, ifs-fesom, ifs-nemo.
  MODEL: 
  # Current options: none
  APPLICATION: none
  # Current options:
    # ICON: r2b4
    # IFS (Nemo and Fesom): tco79l137, tco1279l137
  GRID_ATM: 
  # Current options:
    # ICON: r2b4
    # Nemo: eORCA1_Z75, eORCA12_Z75 
  GRID_OCEAN: 
  # Leave empty if the model version is not pre-compiled. Current options:
    # ICON: 
    # IFS-Nemo: 
    # IFS-Fesom: 
  MODEL_VERSION: ''
  # openmpo, gcc, intel...
  ENVIRONMENT: 
  # True if you want to delete restarts of previous runs, false if you want to keep them.
  CLEAN_RUN: "true"
  PROCESSOR_UNIT: "gpu"

# Uncomment this keys if you want to run the model for specific dates (not the default setted in SIMULATION)
# EXPERIMENT:
#    DATELIST: yyyymmddhh
#    CHUNKSIZEUNIT: day/month/year
#    CHUNKSIZE: 
#    NUMCHUNKS: 

```

Now that you have created your experiment, the next section shows you how to configure
your experiment and simulation.

### Configure your experiment

1. In your `conf/minimal.yml` file, specify which submodules you want to clone in the `PROJECT_SUBMODULES` key. With this setup you can have autosubmit create the workflow for you:

```bash
autosubmit create <expid>
```

This process can take some time since autosubmit will create the workflow files,
and then clone all the files of the workflow repository and the models' repository
into `<expid>/proj/git_project`.

> **NOTE**: `autosubmit create` may take a while to complete since it may clone
> multiple (and large) Git repositories for the models used. This is unfortunately
> not tracked in the command-line output due to the version of Git used in the
> Climate DT virtual machine.
> [Ref](https://earth.bsc.es/gitlab/digital-twins/de_340/project_management/-/issues/355#note_209009). 

2. Modify the `main.yml` file you created, paying special attention to the values under
`RUN`. Those values define the configuration of the simulation that you will run.

For example:

```yaml
# File: <expid>/conf/main.yml
RUN:
  SIMULATION: test-icon
  # ...
  # ...
```

In the example above, the parameter `RUN.SIMULATION` of the `main.yml` file is a configuration
switch used by the Autosubmit experiment to choose which model to use in the simulation (ICON
in this case). Consult the latest `main.yml` file for the available switches.

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
autosubmit create <expid>
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

## Need more information?
Take a look into our [Readme for advanced users](https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/wikis/Readme-for-advanced-users).

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

### Local project

<details><summary>Instructions for a local project (in case that you don't have access to the model repository): </summary>
Clone this repo (anywhere you like, but I put it in home now)

```bash
git clone https://earth.bsc.es/gitlab/digital-twins/de_340/workflow -b <branch-with-latest-changes> ~/DT_workflow
```

Generate a new experiment:

```bash
autosubmit expid -H LUMI -d "Basic ClimateDT workflow"
```

Set basic config for experiment definition (make sure you put the correct path of your user platform config file here):

```yaml
default:
  CUSTOM_CONFIG: "%ROOTDIR%/proj/proj_model/conf,/albedo/home/user/.config/autosubmit/platforms.yml"
```

Note: this will soon be deprecated and substituted by the `PRE` and `POST` new `COSTUM_CONFIG` logic. In this case,
the user file (e.g. `/albedo/home/user/.config/autosubmit/platforms.yml`) belongs to `POST`.

Set your project type to local and set the project path (must be the one where you cloned this repo into)

```yaml
project:
  PROJECT_TYPE: local
  PROJECT_DESTINATION: 'proj_model'
local:
  PROJECT_PATH: '~/DT_workflow'
```

#### Chunks

To configure chunks of the experiment, you need to set the following in `expdef.yml`:
This means to run a total of 5 days in increments of one day starting from January 20th 2020:

```yaml
experiment:
  MODEL: MODEL_NAME
  DATELIST: 20200120
  MEMBERS: "fc0"
  CHUNKSIZEUNIT: day
  CHUNKSIZE: 1
  NUMCHUNKS: 5
  CHUNKINI: ''
  CALENDAR: standard
```

The `expdef.yml` should look similar to this now:

```yaml
DeFault:
  EXPID: a002
  HPCARCH: LUMI
  CUSTOM_CONFIG: 
    PRE:
     - "%PROJDIR%/conf"
     - "%PROJDIR%/conf/simulation/%RUN.SIMULATION%.yml"
     - "%PROJDIR%/conf/parameter/%RUN.PARAMETER%.yml"
     - "%PROJDIR%/conf/model/%RUN.MODEL%/%RUN.MODEL%.yml"
     - "%PROJDIR%/conf/model/%RUN.MODEL%/%RUN.GRID%.yml"
     - "%PROJDIR%/conf/application/%RUN.APPLICATION%.yml"
    POST:
     - "~/platforms.yml"

experiment:
  MODEL: MODEL_NAME
  DATELIST: 20200120
  MEMBERS: "fc0"
  CHUNKSIZEUNIT: day
  CHUNKSIZE: 1
  NUMCHUNKS: 5
  CHUNKINI: ''
  CALENDAR: standard
project:
  PROJECT_TYPE: local
  PROJECT_DESTINATION: 'proj_model'
local:
  PROJECT_PATH: '~/DT_workflow'
project_files:
  FILE_PROJECT_CONF: ''
  FILE_JOBS_CONF: ''
  JOB_SCRIPTS_TYPE: ''
rerun:
  RERUN: FALSE
  RERUN_JOBLIST: ''
```

#### Initiate the submodule

If you are using a local project (not a git project), make sure you initiate first your model's submodule:

```bash
git init <submodule>
git update <submodule>
```

If you are using a `git` project, that will be done automatically by Autosubmit, and you can skip this step.

</details>

