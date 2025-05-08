from setuptools import setup, find_packages

setup(
    name="climate-dt-workflow",
    version="1.0",
    packages=find_packages(where="."),
    package_dir={"": ".", "conf": "conf", "runscripts": "runscripts", "utils": "utils"},
    install_requires=["pyyaml == 6.*"],
    extras_require={
        "test": [
            "pytest==8.*",
            "pytest-mock",
            "pytest-cov",
            "ruff",
            "pre-commit",
            "pyfdb@git+https://github.com/ecmwf/pyfdb.git@0.0.3",
        ]
    },
    description="Climate DT workflow",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    python_requires=">=3.8",
)
