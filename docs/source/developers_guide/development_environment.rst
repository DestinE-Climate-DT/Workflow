Development environment
***********************
To set up the development environment, you need to follow these steps:

1. Create a virtual environment: ``python3 -m venv venv``

2. Activate the virtual environment: ``source venv/bin/activate``

3. Install the dependencies: ``pip install -e .[test]``

4. Install the pre-commit hooks: ``pre-commit install --install-hooks``

After this, the pre-commit hooks will be set up and will run automatically when you make a commit. You can also run them manually with ``pre-commit run --all-files`` to check all files in the repository.
