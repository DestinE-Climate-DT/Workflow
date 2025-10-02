# -----------------------------------------------------------------------------
# Start from the GSV container as our base
FROM ghcr.io/destine-climate-dt/gsv:2.9.0_fdb-5.12.1_eccodes-2.39.0_python-3.11_ubuntu-22.04_8dbc13ec4e39

# -----------------------------------------------------------------------------
# kcov is a coverage tool for binaries that works with Bash shell
# scripts too. It uses the Dwarf standard debugging library to
# retrieve coverage values, and produce the final report for CICD.
FROM kcov/kcov AS kcov

# -----------------------------------------------------------------------------
# bats is an old (one of the oldest?) Shell unit test libraries. It
# contains extensions for assertions that should look similar to
# those familiar with libraries like unittest or JUnit.
FROM debian:bullseye-slim AS bats

# Install build-time dependencies.
RUN apt-get update && \
    apt-get install --yes --no-install-suggests --no-install-recommends \
      build-essential \
      ca-certificates \
      git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Bats.

RUN git clone https://github.com/bats-core/bats-core.git && \
    cd bats-core && \
    ./install.sh /usr/local

# Install Bats support tools.

RUN mkdir /usr/lib/bats && \
    cd /usr/lib/bats && \
    git clone https://github.com/bats-core/bats-support.git && \
    git clone https://github.com/bats-core/bats-assert.git

# -----------------------------------------------------------------------------
# Micromamba to install a specific version of Python so that
# we can use GSV and run our tests with pytest.
FROM mambaorg/micromamba:bullseye-slim AS micromamba

# -----------------------------------------------------------------------------
# Final stage
FROM ghcr.io/destine-climate-dt/gsv:2.9.0_fdb-5.12.1_eccodes-2.39.0_python-3.11_ubuntu-22.04_8dbc13ec4e39

# Install run-time dependencies.

RUN apt-get update && \
    apt-get install --yes --no-install-suggests --no-install-recommends \
      binutils \
      ca-certificates \
      git \
      jq \
      libcurl4 \
      libdw1 \
      python3-pip \
      zlib1g && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
# Copy bats.

COPY --from=bats /usr/local/bin/bats* /usr/local/bin/
COPY --from=bats /usr/local/lib/bats-core/ /usr/local/lib/bats-core/
COPY --from=bats /usr/local/libexec/bats-core/ /usr/local/libexec/bats-core/
COPY --from=bats /usr/lib/bats/bats-assert/ /usr/lib/bats/bats-assert/
COPY --from=bats /usr/lib/bats/bats-support/ /usr/lib/bats/bats-support/

# Copy kcov.

COPY --from=kcov/kcov:latest /usr/local/bin/kcov* /usr/local/bin/
COPY --from=kcov/kcov:latest /usr/local/share/doc/kcov /usr/local/share/doc/kcov

WORKDIR "/code"

# ENTRYPOINT ["/bin/sh", "-c"]
CMD ["/usr/local/bin/bats"]
