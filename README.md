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
        <li><a href="#Create-your-own-experiment">Create your own experiment</a></li>
        <li><a href="#Execute-the-workflow">Execute the workflow</a></li>
      </ul>
    </li>
    <li><a href="#contributing">Contributing </a></li>
    <li><a href="#contact-us">Contact us! </a></li>
  </ol>

</details>

## About the project 
This workflow contains a preliminary version of the DE_340 workflow. It is used for development and testing in conjunction with [Autosubmit4](https://earth.bsc.es/gitlab/es/autosubmit). The implemented workflow tasks keep a model-agnostic interface and contain the merged sub-workflows for ICON, IFS-FESOM, and IFS-NEMO. Currently, MareNostrum4 is supported for ICON and IFS-NEMO to perform basic simulations. LUMI, JUWELS and Levante can be used to run IFS-FESOM with similar configurations.

### Current list of steps:
Each step contains a very short description of its main purpose. The templates are located in `/workflow/templates`.
* `local_setup` 
* `synchronize` 
* `remote_setup`
* `ini`
* `sim`
* `gsv`
* `application`

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
  juwels-login:
    USER: <USER>
  juwels:
    USER: <USER>
  marenostrum4:
    USER: <USER>
  marenostrum4-login:
    USER: <USER>
  levante:
    PROJECT: <PROJECT>
    USER: <USER>
  levante-login:
    PROJECT: <PROJECT>
    USER: <USER>
```

You also need to configure password-less access to the platforms where you want to run experiments. Further instructions can be found [here](https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+VM) (Section 4. How to get password-less access from VM to Levante / LUMI / MN4).

### Create your own experiment

1. Create an Autosubmit experiment using minimal configurations:

```
autosubmit expid -min -repo https://earth.bsc.es/gitlab/digital-twins/de_340/workflow -b main -d "A description"
```

You will receive the following message: `Experiment <expid> created`, where `<expid>` is the identifyer of your experiment. 

A directory will be created : 

- In the Autosubmit's VM used at BSC, the path is `/esarchive/autosubmit/<expid>`
- In the ClimateDT VM used at CSC, the path is: `/appl/AS/AUTOSUBMIT_DATA/<expid>`.

2. Copy the `minimal_example.yml` and the `main_example.yml` into your experiment `conf` folder, making sure that the default `minimal.yml` created by the previous command is overwritten:
```shell
cp minimal_example.yml <autosubmit_experiments_path>/<expid>/conf/minimal.yml
cp main_example.yml <autosubmit_experiments_path>/<expid>/conf/main.yml
```

And edit them accordingly, paying special attention to the variables `DEFAULT.EXPID` in the `minimal_example.yml` file, and the `RUN` dictionary in the `main_example.yml` file, that defines the configuration of the simulation that you will run.

In the `git` section in the `minimal_example.yml`, fill the `PROJECT_SUBMODULES` with the models you want to run (`icon-mpim`, `ifs-fesom`, `ifs-nemo`). Autosubmit will clone them (Note: you need to have access to the correspondent model sources repostory and your ssh keys must be uploaded there). 

### Execute the workflow

With this set up you can have autosubmit create the workflow for you:
```
autosubmit create <expid>
```
This process can take some time, because autosubmit is cloning all the files of the WF repostory and the models' repostory.

Now you can run the workflow:
```
autosubmit run <expid>
```

Whenever you change something in the git repostory make sure you refresh your experiment. Be careful! This command will overwrite any changes in the local project folder.

```
autosubmit refresh <expid>
```

and then you need autosubmit to create the updated files again:
```
autosubmit create <expid>
```

This resets the status of all the jobs, so if you don't want to run everything from the beginning again, you can set the status like this:
```
autosubmit setstatus a002 -fl "a002_LOCAL_SETUP a002_SYNCHRONIZE a002_REMOTE_SETUP" -t COMPLETED -s
```
(`-fl` is for filter, so you filter them by job name now, `-t` is for target status(?) so, we set them to `COMPLETED` here. `-s` is for save, 
which is needed to save the results to disk.)

You can add a `-np` for no plot to most of the commands to not have the error with missing xdg-open etc.


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
- Miguel Andrés (IFS-Fesom Workflow developer): miguel.andres-martinez@awi.de
- Sebastian Beyer (IFS-Fesom Workflow developer): sebastian.beyer@awi.de
- Julian Berlin (IFS-Fesom Workflow developer): julian.berlin@bsc.es
- Francesc Roura (Applications Workflow developer): francesc.roura@bsc.es
- Aina Gaya (IFS-Nemo Workflow developer): aina.gayayavila@bsc.es

Main Autosubmit support:

- Daniel Beltrán (daniel.beltran@bsc.es)
- Bruno de Paula Kinoshita (bruno.depaulakinoshita@bsc.es)

[Link to the Autosubmit tutorial & Hands-on](https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+introductory+session)

### Local project

<details><summary>Instructions for a local project (in case that you don't have access to the model repostory): </summary>
Clone this repo (anywhere you like, but I put it in home now)
```
git clone https://earth.bsc.es/gitlab/digital-twins/de_340/workflow -b <branch-with-latest-changes> ~/DT_workflow
```

Generate a new experiment:
```
autosubmit expid -H LUMI -d "Basic ClimateDT workflow"
```

Set basic config for experiment definition (make sure you put the correct path of your user platform config file here):
```
default:
  CUSTOM_CONFIG: "%ROOTDIR%/proj/proj_model/conf,/albedo/home/user/.config/autosubmit/platforms.yml"
```
Note: this will soon be deprecated and substituted by the `PRE` and `POST` new `COSTUM_CONFIG` logic. In this case,
the user file (e.g. `/albedo/home/user/.config/autosubmit/platforms.yml`) belongs to `POST`.

Set your project type to local and set the project path (must be the one where you cloned this repo into)
```
project:
  PROJECT_TYPE: local
  PROJECT_DESTINATION: 'proj_model'
local:
  PROJECT_PATH: '~/DT_workflow'
```

#### Chunks

To configure chunks of the experiment, you need to set the following in `expdef.yml`:
This means to run a total of 5 days in increments of one day starting from January 20th 2020:
```
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
```
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
```
git init <submodule>
git update <submodule>
```
If you are using a `git` project, that will be done automatically by Autosubmit, and you can skip this step.

</details>

