About the project
==================

This repository contains the DE_340 workflow. It is used for production, development and testing in conjunction with `Autosubmit4 <https://earth.bsc.es/gitlab/es/autosubmit>`_.

The Climate DT Workflow provides an integrated and flexible system to manage high-resolution climate simulations and their associated applications. Designed for the Destination Earth Climate Digital Twin (Climate DT), it facilitates production, development, and testing across supported models (ICON, IFS-NEMO, IFS-FESOM) on platforms like LUMI and MareNostrum5.

Basic Purpose and Functionality
-------------------------------

At its core, the workflow orchestrates complex climate simulations by automating model execution, post-processing, data quality checks, and application workflows. It leverages Autosubmit4 to coordinate tasks and supports multiple operational modes:

- Model mode for pure climate model simulations.

- End-to-end mode to run models and applications in a streaming pipeline.

- Applications mode to simulate application processing without running a model.

- Simless mode to process existing data or manage ancillary jobs like backups and transfers.

The workflow supports modular customization via YAML configuration files, allowing users to select models, applications, platforms, resolutions, and job-specific settings dynamically.
