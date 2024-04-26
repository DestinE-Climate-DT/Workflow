.PHONY: shellcheck
shellcheck:
	find lib -name "*.sh" -exec shellcheck --severity error '{}' +;
	find templates -name "*.sh" -exec shellcheck --severity error '{}' +;


.PHONY: format
format:
	find templates -name "*.sh" -exec shfmt -w -i 4 '{}' +;
	find lib -name "*.sh" -exec shfmt -w -i 4 '{}' +;
	ruff check --fix lib
	ruff format lib

.PHONY: test
test:
	sudo docker run --rm -it -v "${PWD}:/code" bats/bats:latest --verbose-run --recursive ./

.PHONY: coverage
coverage:
	cd ./.gitlab/dockerfiles/; sudo docker build -t climatedt/workflow:latest .; 
	sudo docker run --rm -it -v "${PWD}:/code" climatedt/workflow:latest \
    	/usr/local/bin/kcov --include-path=./ ./coverage/ \
    	/usr/local/bin/bats --verbose-run  --recursive ./


.PHONY: all
all:
	make shellcheck
	make format
	make test
	make coverage
