Configuration files
-------------------

Once an experiment is created, two files are present in the Virtual Machine's configuration folder (``%ROOTDIR%/conf``): main.yml and minimal.yml.

These files are used to configure the experiment. The main.yml file is the main configuration file that the user should modify, while the minimal.yml file contains the minimal configurations for Autosubmit to execute a workflow.

main.yml
********

The keys defined in ``main.yml`` are used to configure the experiment. The basic usage of it is so that it loads the rest of the configuration from the versioned configuration files stored in the repository.
The keys that can be set are documented in the :ref:`schemas` section.

Any key defined in the ``main.yml`` file will override the default values defined in configuration files in the repository. Especially in production (or official) experiments, it is recommended to keep only the essential keys in the ``main.yml`` file, and to set the rest of the keys in the configuration files in the repository. This way, the configuration files in the repository can be versioned and tracked, while the ``main.yml`` file can be used to override only the essential keys for a specific experiment.

minimal.yml
***********

The ``minimal.yml`` file is used to define the minimal configuration needed for Autosubmit to execute a workflow. It contains the keys that are required for Autosubmit to run.
The repository, the branch and the main machine that the experiment will use are defined in that file.
