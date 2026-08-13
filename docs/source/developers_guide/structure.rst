File and Directory Structure
****************************

This section provides an overview of the file and directory structure of the Climate DT Workflow project. Below is a tree view of the main files and directories, followed by a detailed explanation of their purpose.

Project Structure
================

.. code-block:: none

    .
    ├── catalog/                 # Catalog of datasets or configurations
    ├── CHANGELOG.md             # Log of changes made to the project
    ├── conf/                    # Configuration files for the workflow
    │   ├── additional_jobs/     # Definitions for additional jobs
    │   │   ├── aqua-True.yml    # AQUA job configuration
    │   │   ├── backup-True.yml  # Backup job configuration
    │   │   └── ...              # Other additional job configurations
    │   ├── applications/        # Application-specific configurations
    │   │   ├── container_versions.yml  # Container version mappings
    │   │   ├── energy_indicators/  # Directory for energy indicators application configuration
    │   │   ├── request/         # Directory to set data request details for all apps
    │   │   └── ...              # Other application configurations
    │   ├── bootstrap/           # Internal bootstrap configurations
    │   │   └── include.yml      # Entry point for loading workflow configuration
    │   ├── data_gov/            # Data governance-related configurations
    │   │   ├── production.yml   # Production data governance rules
    │   │   └── ...              # Other data governance configurations
    │   ├── defaults/            # Default configuration files
    │   │   ├── defaults_model.yml  # Default model configuration
    │   │   └── ...              # Other default configurations
    │   ├── model/               # Model-specific configurations
    │   │   ├── icon/            # ICON model configurations
    │   │   ├── ifs-fesom/       # IFS-FESOM model configurations
    │   │   └── ifs-nemo/        # IFS-NEMO model configurations
    │   ├── simulation/          # Simulation-specific configurations
    │   │   ├── control-ifs-nemo.yml  # Control simulation for IFS-NEMO
    │   │   └── ...              # Other simulation configurations
    │   └── platforms.yml        # Platform-specific configurations
    ├── data-portfolio/          # Submodule: Data portfolio for model output
    ├── docs/                    # Documentation source files
    │   ├── source/              # Sphinx documentation source
    │   │   ├── developers_guide/  # Developer guide documentation
    │   │   ├── schemas/         # Schema documentation
    │   │   └── users_guide/     # User guide documentation
    ├── dvc-cache-de340/         # Submodule: DVC cache for managing IFS inputdata
    ├── ifs-nemo/                # Submodule: IFS-NEMO model sources
    ├── lib/                     # Shared libraries and utilities
    │   ├── common/              # Common utility scripts
    │   │   ├── checkers.sh      # Script for validation checks
    │   │   └── util.sh          # General utility functions
    │   ├── LUMI/                # LUMI-specific configurations
    │   │   └── config.sh        # Configuration script for LUMI
    │   └── ...                  # Other platform-specific configurations
    ├── mains/                   # Main configuration examples
    │   ├── main_example_app.yml  # Example configuration for applications workflow
    │   └── ...                  # Other main configuration examples
    ├── Makefile                 # Build automation file
    ├── nemo/                    # Submodule: NEMO model sources
    ├── pyproject.toml           # Python project configuration
    ├── pytest.ini               # Pytest configuration
    ├── README.md                # Project overview and getting started guide
    ├── runscripts/              # Additional scripts for APPS, ICON, FDB
    │   ├── dn/                  # Data Notifier scripts
    │   │   └── run_dn.py        # Script to run the Data Notifier
    │   ├── icon                 # ICON model runscripts
    │   │   ├── control          # Control runscripts for ICON
    │   │   ├── historical       # Historical runscripts for ICON
    │   │   └── ...              # Other ICON runscripts
    │   ├── hydroland/           # Hydroland application scripts
    │   │   ├── run_hydroland.sh  # Script to run Hydroland
    │   │   └── ...              # Other Hydroland scripts
    │   └── ...                  # Other application-specific scripts
    ├── setup.py                 # Python package setup script
    ├── templates/               # Main workflow jobs bash templates
    │   ├── aqua/                # AQUA-specific templates
    │   │   ├── aqua_analysis.sh  # AQUA analysis script template
    │   │   └── ...              # Other AQUA templates
    │   └── ...                  # Other templates
    ├── tests/                   # Unit and integration tests
    │   ├── bats_tests/          # BATS tests for job shell scripts
    │   ├── schemas/             # JSON schema validation tests
    │   │   ├── run.schema.json  # Schema for the RUN section
    │   │   └── ...              # Other schema files
    │   └── workflow_mock/       # Mock workflow tests
    └── utils/                   # Utility scripts and helper functions
        ├── logger.py            # Logging utilities
        ├── update_changelog.sh  # Script to update the changelog
        └── ...                  # Other utility scripts

Detailed Descriptions
====================

Configuration System (``conf/``)
-------------------------------

The ``conf/`` directory contains all configuration files used by the workflow system to define behavior across different environments, models, and applications.

Model Configurations (``conf/model/``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This directory contains settings specific to each climate model:

- ``icon/``: Configuration files for the ICON (ICOsahedral Nonhydrostatic) atmospheric model, including:

  - Model resolution settings depending on the processing unit
  - Wallclock and timestepping configurations
  - Physical parameterization options
  - Default request resolutions

- ``ifs-fesom/``: Configuration for the IFS-FESOM coupled model:

  - IFS model parameters depending on the processing unit
  - Wallclock, IO tasks, and additional setup configuration
  - ICMCL configurations
  - Default request resolutions

- ``ifs-nemo/``: Configuration for the IFS-NEMO coupled model:

  - IFS model parameters depending on the processing unit
  - Wallclock, IO tasks, and additional setup configuration
  - Default request resolutions

Application Configurations (``conf/applications/``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Contains settings specific to downstream applications:

- ``container_versions.yml``: Maps application names to container versions.

- ``default_gsv_request.yml``: Configuration for the GSV, including:

  - Grid resolutions
  - Area to process
  - Method (e.g., nn)

- ``opa/opa.yml``: Configuration for the opa, including:

  - Apps output directory
  - Retries
  - Platform specific settings

- ``energy_indicators/``: Directory for energy indicators application configurable physical parameters.
- ``hydroland/``: Directory for hydroland application configurable physical parameters.
- ``hydromet/``: Directory for hydromet application configurable physical parameters.
- ``wildfires_fwi/``: Directory for wildfires FWI application configurable physical parameters.
- ``wildfires_wise/``: Directory for wildfires WISE application configurable physical parameters.
- ``obsall/``: Directory for OBSALL application configurable physical parameters.
- ``data/``: Directory to set details of the data workflow.

- ``request/``: Directory to set data request details for all apps. A file per app.

  - Contains detailed specifications for GSV and OPA requests
  - Defines parameters like activity, resolution, generation, and realization
  - Includes hardcoded settings for datasets, grids, and methods

Workflow Job Management (``conf/additional_jobs/``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Defines auxiliary workflows that can be attached to the main simulation workflow:

- ``aqua-True.yml``: Configuration for the AQUA jobs, including:

  - Adds AQUA to the jobs definitions
  - Additional parameters for the analysis

- ``dqc-True.yml``: Configuration for DQC jobs, including:

  - Adds the DQC to the jobs definitions
  - Additional DQC parameters (e.g., profiles)

- ``backup-True.yml``: Configuration for backup jobs.
- ``cleanup-True.yml``: Configuration for cleanup jobs.
- ``transfer-True.yml``: Configuration for transfer jobs.
- ``memory_checker-True.yml``: Configuration for memory checking job.
- ``transfer-True.yml``: Configuration for transferring FDB data between systems.
- ``wipe-True.yml``: Configuration for cleaning up transferred data.
- ``size_checker-True.yml``: Configuration for checking the size of generated data.
- ``scaling-True.yml``: Configuration for performance scaling job.
- ``energy_indicators-True.yml``: Configuration for energy indicators jobs.
- ``hydroland-True.yml``: Configuration for jobs of Hydroland.
- ``hydromet-True.yml``: Configuration for jobs of Hydromet.
- ``wildfires_fwi-True.yml``: Configuration for jobs of Wildfires FWI.
- ``wildfires_wise-True.yml``: Configuration for jobs of Wildfires WISE.
- ``obsall-True.yml``: Configuration for jobs of OBSALL.
- ``data-True.yml``: Configuration for data retrieval workflow.
- ``postproc_hydroland-True.yml``: Configuration for post-processing jobs of Hydroland.
- ``postproc_energy_indicators-True.yml``: Configuration for post-processing jobs of energy_indicators.
- ``<APP>_wrapper-True.yml``: Enables the wrapper for the specified application.

Bootstrap System (``conf/bootstrap/``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``include.yml``: Bootstrap entry point that:

  - Establishes configuration loading order
  - Sets up environment-specific overrides
  - Initializes the workflow context

Data Governance (``conf/run_types/``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Defines data management policies and rules for each workflow mode:

- ``production.yml``: Production environment data governance rules for:

  - FDB keys (EXPVER: 0001, CLASS: d1, FDB Path, etc.)
  - Application specifics

- ``research.yml``: Research environment data governance rules for:

  - GSV Requests (expid, d1, FDB Path, etc.)
  - Application specifics

Additional files for other types of runs:

- ``pre-production.yml``
- ``test.yml``
- ``operational-read``

Default Settings (``conf/defaults/``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Base configurations that can be overridden by more specific files:

- ``defaults_model.yml``: Default parameters for all models, including:

  - Model paths
  - Resquest and AQUA configurations
  - I/O settings

Additional files for other modes of the workflow:

- ``defaults_end-to-end.yml``
- ``defaults_simless.yml``

Simulation Configurations (``conf/simulation/``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Defines standard simulation types and scenarios. Each file contains chunking
information, forcing settings, RAPS configuration, DQC profile, and GSV Request
definitions.

**Naming Convention**

Simulation configuration files follow a structured naming pattern (currently for IFS-FESOM) to ensure clarity and consistency. The format is as follows:

.. code-block:: text

   <atmospheric model>-<ocean model>-<activity>-<experiment>-<resolution>.yml

For IFS-FESOM, the components are:

- **atmospheric model**: ``ifs``
- **ocean model**: ``fesom``
- **activity**: The request activity (e.g., ``baseline``, ``projections``, ``story-nudging``)
- **experiment**: The request experiment (e.g., ``hist``, ``cont``, ``ssp126``, ``ssp370``, ``plus2K``)
- **resolution**: The atmospheric resolution (e.g., ``tco79``, ``tco319``, ``tco399``, ``tco1279``, ``tco2559``)

Examples:

- ``ifs-fesom-baseline-hist-tco79.yml``
- ``ifs-fesom-projections-ssp126-tco2559.yml``
- ``ifs-fesom-story-nudging-hist-tco1279.yml``
- ``ifs-fesom-baseline-spinup-tco2559.yml``

**Referencing in main.yml**

Simulation configs are referenced in ``mains/*.yml`` files via the ``MODEL.SIMULATION``
key (without the ``.yml`` extension). The simulation name must match the filename
in ``conf/simulation/``:

.. code-block:: yaml

   MODEL:
     NAME: ifs-fesom
     SIMULATION: ifs-fesom-baseline-hist-tco79
     GRID_ATM: tco79l137

See existing examples in the ``mains/`` directory (e.g., ``mains/ifs-fesom-baseline-hist-tco79.yml``).

**Existing configurations:**

- ``control-ifs-nemo.yml``: Configuration for IFS-NEMO control simulations, including:

  - Chunking information, calendar, etc.
  - IFS-NEMO Multi-IO Plans, RAPS conf, etc.
  - GSV Request definitions

- ``control-r2b9-icon-1990.yml``: Configuration for ICON 5km control simulations, including:

  - Chunking information, calendar, etc.
  - Simulation timestepping definitions
  - GSV Request definitions

- ``ifs-fesom-control-tco79.yml``: Configuration for IFS-FESOM tco79 control simulations, including:

  - Chunking information, calendar, etc.
  - RAPS, Portoflio, DQC settings
  - GSV Request definitions

Platform Configurations (``conf/platforms.yml``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``platforms.yml``: Settings for different computing platforms:

  - Defines platform-specific parameters (e.g., LUMI, MN5)
  - Includes queue names
  - Wallclock limits
  - SBATCH options
  - Components paths and version

General Configuration (``conf/general.yml``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``general.yml``: Contains global configuration settings for the workflow:

  - Defines paths for containers, scratch directories, and libraries
  - Sets up default directories for HPC projects and FDB (Field Database)
  - Includes general tools and ensemble versioning information

Job Templates (``conf/jobs_<mode>.yml``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``jobs_model.yml``: Defines job configurations for model workflows:

  - Specifies dependencies, wallclock limits, and platform settings.

- ``jobs_simless.yml``: Defines job configurations for simulation-less workflows:

  - Specifies dependencies, wallclock limits, and platform settings, does not include SIM.

- ``jobs_end-to-end.yml``: Defines basic job configurations for end-to-end workflows.

  - Specifies dependencies, wallclock limits, and platform settings, does include up to DN.

- ``jobs_apps.yml``: Defines job configurations for application workflows.

  - Specifies dependencies, wallclock limits, and platform settings, does include up to DN

GSV Configuration (``conf/gsv.yml``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``gsv.yml``: Configuration file for the GSV:

  - Maps paths for grid definitions, weights, and test files
  - Defines GSV version
  - Defines model grid definitions paths

Libraries and Utilities (``lib/``)
---------------------------------

Collection of shared scripts and libraries used across the workflow:

Common Utilities (``lib/common/``)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``checkers.sh``: Contains validation functions for:

  - Verifying configuration file integrity
  - Checking environment setup for required dependencies
  - Validating input data for workflows

- ``util.sh``: General utility functions for:

  - Logging and error handling
  - File system operations, such as creating directories or managing files
  - String manipulation and other helper functions

Platform-Specific Configurations (``lib/LUMI/`` and others)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- ``LUMI/config.sh``: Configuration settings specific to the LUMI supercomputing platform:

  - Defines queue configurations and module loading for LUMI
  - Sets up environment variables and I/O path mappings for workflows
  - Includes functions for loading Singularity containers and managing dependencies

- ``MARENOSTRUM5/config.sh``: Configuration for MareNostrum5:

  - Defines HPC-specific settings, such as module loading and queue names
  - Manages paths for input/output data and temporary directories

Runtime Components
-----------------

Runscripts (``runscripts/``)
~~~~~~~~~~~~~~~~~~~~~~~~~~

Contains scripts for ICON, applications, and other components:

- ``icon/``

  - ``control/``: ICON model execution scripts for control simulations:

    - Manages namelists, input data, and output paths
    - Handles processing of restart files and log files
    - Configures process mappings
    - Handles job submission ICON control runs

  - ``historical/``: ICON model execution scripts for historical simulations:

    - Similar to control scripts but tailored for historical data processing
    - Manages specific configurations for historical runs
    - Handles job submission for ICON historical runs

  - ``test/``: ICON scripts for testing

- ``dn/run_dn.py``: Script for the Data Notifier, which:

  - Monitors for new data availability in the system
  - Triggers downstream workflows based on data readiness
  - Sends notifications to ensure workflow synchronization

- ``hydroland/run_hydroland.sh``: Script for the Hydroland application, which:

  - Processes meteorological inputs and runs hydrological models
  - Generates outputs such as river discharge and soil moisture
  - Manages restart files and log files to optimize memory usage

- ``opa/run_opa.py``: Scripts for the OPA (One Pass algorithm)

- ``wildfires_fwi/``: Scripts for running the Wildfires FWI application

- ``wildfires_wise/``: Scripts for running the Wildfires WISE application

- ``ensembles/``: Scripts for ensemble simulations:

  - ``perturb_nemo_restart.py``: Perturbs NEMO restart files for ensemble simulations
  - ``perturb_var.py``: Perturbs specific variables for ensemble runs

- ``energy_onshore/run_energy_indicators.py``: Scripts for the Energy Indicators application:

  - Processes data and runs simulations for energy indicators energy application.

- ``FDB/``: Scripts for managing the Field Database (FDB):

  - ``count_expected_messages.py``: Counts expected messages in the FDB
  - ``yaml_to_mars.py``: Converts YAML configurations to MARS requests
  - ``update_fdb_info.py``: Updates FDB metadata and configurations

Templates (``templates/``)
~~~~~~~~~~~~~~~~~~~~~~~~

The ``templates/`` directory contains the bash scripts that define the behavior of the workflow jobs and components. Additionally it includes configuration files for the FDB and AQUA.

- ``aqua/``: Templates for AQUA-related workflows:

  - ``aqua_analysis.sh``: Template for AQUA analysis jobs, which:

    - Performs quality analysis on model outputs, such as consistency checks
    - Generates diagnostic metrics and visualizations
    - Supports containerized execution for portability

  - ``aqua_push.sh``: Template for pushing AQUA outputs to external storage or databases
  - ``lra_generator.sh``: Template for generating LRA (Low Resolution Archive) configurations for AQUA

- ``sim_ifs-nemo.sh``: Template for IFS-NEMO simulation jobs, which:

  - Configures model-specific parameters, such as grid resolution and timestepping
  - Manages input/output paths and restart files
  - Executes the simulation in chunks to optimize resource usage

- ``sim_ifs-fesom.sh``: Template for IFS-FESOM simulation jobs, which:

  - Configures IFS and FESOM coupling parameters, including MIR cache paths and FESOM I/O allocation
  - Manages restart files for both IFS (``rcf``, ``waminfo``) and FESOM (``fesom_raw_restart/``, which contains ``fesom.clock``), with automatic backup and restore on retrials
  - Supports restarted runs from another experiment, ensemble perturbation (``FESOM_PERTURB``), nudging (``--destine-enable-nudging``), and configurable forcing flags

- ``sim_icon.sh``: Template for ICON simulation jobs, which:

  - Configures ICON-specific parameters, such as grid identifiers and refinement levels
  - Manages timestepping and coupling configurations
  - Handles restart files and output paths

- ``sim_nemo.sh``: Template for standalone NEMO simulation jobs, which:

  - Configures ocean model parameters, such as grid resolution and timestepping
  - Manages input data and restart files
  - Executes the simulation and handles output generation

- ``application.sh``: General template for running application-specific workflows, including:

  - **Energy Indicators**: Processes data and runs simulations for energy indicators.
  - **Hydroland**: Runs hydrological models and processes meteorological inputs
  - **Wildfires FWI**: Calculates fire weather indices for wildfire risk assessment
  - **Wildfires WISE**: Simulates wildfire spread and behavior

- ``dqc.sh``: Template for running Data Quality Checker (DQC) jobs, which:

  - Validates data compliance with predefined standards
  - Checks spatial completeness, consistency, and physical plausibility

- ``dn.sh``: Template for the Data Notifier (DN) service, which:

  - Monitors for new data availability
  - Triggers downstream workflows based on data readiness
  - Sends notifications to ensure workflow synchronization

- ``transfer.sh``: Template for transferring data between systems, which:

  - Manages data movement to and from HPC environments
  - Ensures data integrity during transfers
  - Supports integration with the Field Database (FDB)

- ``remote_setup.sh``: Template for setting up remote environments, which:

  - Loads HPC-specific configurations and modules
  - Prepares directories and dependencies for job execution
  - Handles compilation and installation of models

- ``local_setup.sh``: Template for setting up local environments, which:

  - Prepares the local directory structure for workflows
  - Validates configuration files and dependencies
  - Compresses and transfers project files to remote systems

- ``ini.sh``: Template for initializing simulations, which:

  - Configures initial conditions for models
  - Prepares namelists and other input files
  - Handles dependencies for simulation startup

- ``synchronize.sh``: Template for synchronizing data across systems, which:

  - Ensures consistency between local and remote environments
  - Manages file transfers and updates

- ``wipe.sh``: Template for cleaning up data that has already been transferred to the bridge.

  - Removes intermediate files generated during workflows
  - Frees up storage space on HPC systems

Testing Framework (``tests/``)
----------------------------

Comprehensive test suite for validating workflow components:

- ``bats_tests/``: BATS (Bash Automated Testing System) tests for shell scripts that:

  - Verify the functionality of job templates and utility scripts
  - Test error handling and edge cases in shell scripts
  - Ensure compatibility with different HPC environments

- ``schemas/``: JSON schema validation tests:

  - ``run.schema.json``: Schema definition for validating the ``RUN`` section of the workflow configuration
  - Other schemas for validating model, application, and platform configurations

- ``workflow_mock/``: Mock tests for workflow execution that:

  - Simulate workflow scenarios without requiring full execution
  - Test job dependencies and sequencing logic
  - Validate the correctness of workflow configurations and outputs

Documentation (``docs/``)
-----------------------

Comprehensive documentation for the project:

- ``source/developers_guide/``: Documentation for developers, including:

  - Details on the architecture and structure of the workflow
  - Guidelines for contributing to the project
  - API references for internal tools and libraries

- ``source/users_guide/``: Documentation for end users, including:

  - Tutorials for setting up and running experiments
  - Examples of workflow configurations for different use cases
  - Troubleshooting common issues

- ``source/schemas/``: Documentation of JSON schemas, including:

  - Schema definitions for workflow configuration files
  - Validation rules for ensuring configuration correctness
  - Example configurations for reference

Submodules
---------

Data Management
~~~~~~~~~~~~~~~~

- ``catalog/``: Catalog of available datasets and configurations for AQUA:

  - Contains metadata and configuration files for datasets
  - Defines paths and parameters for accessing and processing data

- ``data-portfolio/``: Submodule containing the data portfolio for model output:

  - Manages metadata and configurations for model-generated data
  - Ensures consistency and traceability of data across workflows

- ``dvc-cache-de340/``: DVC (Data Version Control) cache for managing IFS input data:

  - Stores versioned input data for reproducibility
  - Tracks changes to input datasets over time

Model Source Code
~~~~~~~~~~~~~~~~~

The project integrates multiple model codebases as Git submodules:

- ``ifs-nemo/``: Source code for the IFS-NEMO coupled Earth system model:

  - Combines the IFS atmospheric model with the NEMO ocean model
  - Includes configuration files, scripts, and source code for running coupled simulations

.. note::
   IFS-FESOM is not included as a submodule. Pre-installed versions are stored directly on the HPC platforms.

- ``nemo/``: Standalone NEMO ocean model source code:

  - Includes configuration files, scripts, and source code for running ocean-only simulations
  - Supports various resolutions and configurations for ocean modeling
