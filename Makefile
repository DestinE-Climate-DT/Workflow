OS := $(shell uname)
ifeq ($(OS), Linux)
 YQ_BINARY := yq_linux_amd64
else ifeq ($(OS), Darwin)
 YQ_BINARY := yq_darwin_arm64
endif

# GitHub authentication variables
GITHUB_USER ?= <GITHUB_USER>
GITHUB_TOKEN_FILE ?= ${HOME}/keys/github_token
TEMP_GITHUB_USER_FILE := /tmp/.github_user_$(shell basename $(PWD))

.PHONY: set-github-user
set-github-user:
	@if [ ! -f "$(TEMP_GITHUB_USER_FILE)" ]; then \
		read -p "Enter your GitHub username: " input_username; \
		if [ -n "$$input_username" ]; then \
			echo "Using provided GitHub username: $$input_username"; \
			echo "$$input_username" > $(TEMP_GITHUB_USER_FILE); \
		else \
			echo "Error: No input provided. Please provide your GitHub username"; \
			exit 1; \
		fi; \
	else \
		echo "Using GitHub username from temporary file: $$(cat $(TEMP_GITHUB_USER_FILE))"; \
	fi

.PHONY: github-login
github-login: set-github-user
	@GITHUB_USER=$$(cat $(TEMP_GITHUB_USER_FILE)); \
	if [ ! -f "$(GITHUB_TOKEN_FILE)" ]; then \
		echo "Error: GitHub token file not found at $(GITHUB_TOKEN_FILE)" >&2; \
		exit 1; \
	fi; \
	cat $(GITHUB_TOKEN_FILE) | sudo docker login ghcr.io -u $$GITHUB_USER --password-stdin

.PHONY: clean
clean:
	@if [ -f "$(TEMP_GITHUB_USER_FILE)" ]; then \
		rm -f $(TEMP_GITHUB_USER_FILE); \
		echo "Temporary GitHub username file removed."; \
	fi

.PHONY: install-yq
install-yq:
	wget https://github.com/mikefarah/yq/releases/download/v4.44.3/$(YQ_BINARY) -O ./tests/yq && chmod +x ./tests/yq

.PHONY: install-jsonschema
install-jsonschema:
	sudo apt-get -yq install pipx
	pipx install check-jsonschema --force
	pipx install jsonschema-markdown==0.2.1 --force

.PHONY: test-schema
test-schema:
	./tests/validate_schemas.sh

.PHONY: docs-schema
docs-schema: install-jsonschema
	./tests/generate_docs.sh

.PHONY: docs-html
docs-html:
	pip install ".[docs]" && make docs-schema && cd docs && make html

.PHONY: docs-latexpdf
docs-latexpdf:
	sed -i 's/✅/YES_CHECKMARK/g' docs/source/schemas/*.md;
	sudo docker run --rm -it -v "$(shell pwd):/code" -w /code sphinxdoc/sphinx-latexpdf bash -c "sed -i 's/✅/YES_CHECKMARK/g' docs/source/schemas/*.md; pip install .[docs] && cd docs && make latexpdf"
	sed -i 's/YES_CHECKMARK/✅/g' docs/source/schemas/*.md;

.PHONY: container
container: github-login
	cd ./.gitlab/dockerfiles/; sudo -E docker build -t climatedt/workflow:latest .;

.PHONY: shellcheck
shellcheck: container
	find lib -name "*.sh" -exec shellcheck --severity error '{}' +;
	find runscripts -name "*.sh" -exec shellcheck --severity error '{}' +;
	find templates -name "*.sh" -exec shellcheck --severity error '{}' +;
	find utils -name "*.sh" -exec shellcheck --severity error '{}' +;

.PHONY: format
format: container
	find templates -name "*.sh" -exec shfmt -w -i 4 '{}' +;
	find lib -name "*.sh" -exec shfmt -w -i 4 '{}' +;
	find runscripts -name "*.sh" -exec shfmt -w -i 4 '{}' +;
	find utils -name "*.sh" -exec shfmt -w -i 4 '{}' +;
	ruff check --fix runscripts
	ruff check --fix lib
	ruff check --fix utils
	ruff format runscripts
	ruff format lib
	ruff format utils

.PHONY: test-shell
test-shell: container
	sudo docker run --rm -it -v "${PWD}:/code" climatedt/workflow:latest \
		/usr/local/bin/bats --verbose-run --recursive ./

.PHONY: coverage-shell
coverage-shell: container
	sudo docker run --rm -it -v "${PWD}:/code" climatedt/workflow:latest \
		/bin/bash -c "/usr/local/bin/kcov --include-path=./ --dump-summary ./coverage/ \
		/usr/local/bin/bats --verbose-run --recursive ./"

.PHONY: test-python
test-python: container
	sudo docker run --rm -it -v "${PWD}:/code" climatedt/workflow:latest \
		/bin/bash -c "pip install -e.[all] && \
		pip install pyfdb gsv-interface==2.9.0 && \
		pytest tests/bats_tests/"

.PHONY: coverage-python
coverage-python: container
	sudo docker run --rm -it -v "${PWD}:/code" climatedt/workflow:latest \
		/bin/bash -c "pip install -e.[all] && \
		pip install pyfdb gsv-interface==2.9.0 && \
		pytest tests/bats_tests/ --cov"

.PHONY: test
test: container
	make test-shell
	make test-python

.PHONY: coverage
coverage: container
	make coverage-shell
	make coverage-python

.PHONY: all
all: container
	make shellcheck
	make format
	make coverage # coverage runs the tests as well

# Always run clean after any target
.DELETE_ON_ERROR:
.DEFAULT_GOAL := all
finalize: clean
