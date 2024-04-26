# Climate DT (DE_340) workflow
Welcome to the Climate DT Workflow documentation!

Version v4.0.0. includes the possibility to run end-to-end, models, applications, as well as experimental maestro enabled workflows (maestro-end-to-end and maestro-apps).


## Documentation

Basic instructions to execute the workflow with Autosubmit can be found in [How to run](https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/wikis/How-to-run). The rest of the documentation is available in the same [Wiki](https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/wikis/home).

To build the online version of the documentation you must clone the repo (`git clone https://earth.bsc.es/gitlab/digital-twins/de_340/workflow.git`) and:

```bash
cd docs
# Maybe activate a venv or conda environment?
pip install -r requirements.txt
make html 
```

This will build the documentation in the folder `docs/build/html`. To access the documentation you can then click on `index.html` which will open the webpage docs (or open `index.html` in your favourite browser, e.g. `firefox index.html`), or start a web server and server it locally, for instance:

```bash
cd $workflow_code_root/
python -m http.server -d docs/build/html/ 8000
```

And then navigate to <http://localhost:8000/>.

## Contributing

This workflow is work in progress, and suggestions and contributions are greatly appreciated. If you have a suggestion, desire some new feature, or detect a bug, please: 

1. Open an issue in this GitLab explaining it.
2. Once the issue is completely defined and assigned to someone, it will be tagged with the `to do` label.
3. Once someone is working in the issue, it will be tagged with the `working on` label.

If you want to develop yourself:

1. Create an experiment in the VM.
2. Create a branch locally and make the changes that you want to implement. Make use of the [Shell Style Guide](urlhttps://google.github.io/styleguide/shellguide.html).
3. Test your changes.
4. Apply [Shellcheck](https://www.shellcheck.net/) to your code. To run it automatically, you should run `make shellcheck`. To apply `shfmt` and [ruff](https://docs.astral.sh/ruff/) automatically, run `make format`. Those tools need to be installed beforehand. `make all` will run `shellcheck`, `format` and `test` for you.
5. Once you tested the workflow, add, commit and push your changes into a new branch.
6. Create a merge request.
7. The workflow developers will test it and merge.

If you modified template Shell scripts, please remember to run the tests:

```bash
make test
```

The command above binds the current directory to the `/code` directory inside the container. It is recommended to run the command above (or `bats` directly) from the project root directory (e.g. from `./workflow/`).

If you want to see the code coverage for the current tests, you can use:

```bash
make coverage
```

This command uses a `Docker` container with both `bats`, support libraries (`bats-assert` and `bats-support`), and `kcov` installed. It will create a local folder `./coverage/` with the HTML coverage report produced
by `kcov`. You can visualize it by opening `./coverage/index.html` in a browser.

## Contact us!

For any doubts or issues you can contact the workflow developers:

- Miguel Castrillo (Work package leader): miguel.castrillo@bsc.es @mcastril
- Leo Arriola (ICON Workflow developer): leo.arriola@bsc.es @larriola
- Sebastian Beyer (IFS-Fesom Workflow developer): sebastian.beyer@awi.de @sbeyer
- Francesc Roura (Applications Workflow developer): francesc.roura@bsc.es @froura
- Aina Gaya (IFS-Nemo Workflow developer): aina.gayayavila@bsc.es @agayayav

Main Autosubmit support:

- Daniel Beltrán (daniel.beltran@bsc.es) @dbeltral
- Bruno de Paula Kinoshita (bruno.depaulakinoshita@bsc.es) @bdepaula

[Link to the Autosubmit tutorial & Hands-on](https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+introductory+session)


## Getting Started

All the experiments should be created in the [Autosubmit Virtual Machine](https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+VM). To access the VM, you need a user and your SSH key to be authorized. Add your name, e-mail, preferred username, and SSH (local) public key to the [table](https://wiki.eduuni.fi/display/cscRDIcollaboration/Autosubmit+VM+Users). 

Make sure you have a recent Autosubmit version running `autosubmit --version`. This workflow has been developed using the `4.1.2` version of Autosubmit. Otherwise update it by typing  `module load autosubmit/v4.1.2`. You can follow more detailed description about Autosubmit in [Autosubmit Readthedocs](https://autosubmit.readthedocs.io/en/master/). 

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
The workflow can run as a `local` project or as a `git` project.


### Create your own experiment

1. Create an Autosubmit experiment using minimal configurations.

> **NOTE**: you MUST change `<TYPE_YOUR_PLATFORM_HERE>` below with your platform, and add a description.
For example: lumi, marenostrum4, juwels, levnte... 
> Check the available platforms at `/appl/AS/DefaultConfigs/platforms.yml`
> or `~/platforms.yml` if you created this file in your home directory.

```
autosubmit expid \
  --description "A useful description" \
  --HPC <TYPE_YOUR_PLATFORM_HERE> \
  --minimal_configuration \
  --git_as_conf conf/bootstrap/ \
  --git_repo https://earth.bsc.es/gitlab/digital-twins/de_340/workflow \
  --git_branch v4.0.0
```

You will receive the following message: `Experiment <expid> created`, where `<expid>`
is the identifier of your experiment. A directory will be created for your experiment
at: `/appl/AS/AUTOSUBMIT_DATA/<expid>`.

Basic instructions to execute the workflow with Autosubmit can be found in [How to run](https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/wikis/How-to-run). The rest of the documentation is available in the same [Wiki](https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/wikis/home).


2. In `/appl/AS/AUTOSUBMIT_DATA/<expid>/conf/`, create a `main.yml` file (e. g.: `vim main.yml`). Here you can select the workflow you will run by setting:

```
RUN:
  WORKFLOW: end-to-end #model, apps, maestro-end-to-end or maestro-apps
```

Examples for each workflow type can be found in the Sphinx documentation (see Documentation section). Information about what each key does can be found https://earth.bsc.es/gitlab/digital-twins/de_340/workflow/-/wikis/Available-keys-for-main.yml (WIP).

```
RUN:
  WORKFLOW: end-to-end
  ENVIRONMENT: cray
  CLEAN_RUN: true
  PROCESSOR_UNIT: gpu
  # Frequency of the monitoring in seconds
  MEMORY_FREQUENCY: 30

MODEL: 
  NAME: ifs-nemo
  SIMULATION: test-ifs-nemo
  GRID_ATM: tco79l137
  GRID_OCE: eORCA1_Z75
  VERSION: DE_CY48R1.0_climateDT_20231214

APP:
  NAMES: mhm, wildfires_fwi, aqua
  OUTPATH: "/scratch/project_465000454/tmp/%DEFAULT.EXPID%/"

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
  RAPS_EXPERIMENT: "hist"
  ADDITIONAL_JOBS:
    TRANSFER: "False"
    BACKUP: "True"
    MEMORY_CHECKER: "False"
    DQC: "False"

WRAPPERS:
  WRAPPER:
    TYPE: "vertical"
    JOBS_IN_WRAPPER: SIM  

```

3. After your experiment is defined, you can do `autosubmit run $expid` to run your experiment.


## Run apps:

In order to select the number of the applications that you want to run , you need to create the corresponding structure of the workflow, by using a simple python script. In the VM:

```bash
cd $expid/proj/git_project/conf/

python create_jobs_from_mother_request.py
```

And **run** it:

```bash
autosubmit run <expid>
```

If you want to update the git repository refresh your experiment (equivalent to a git pull):

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
