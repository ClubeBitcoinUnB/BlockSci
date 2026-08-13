# Ubuntu 24.04 developer image for contributors who do not use Nix.
#
# The Nix flake remains the canonical/reproducible build. This image follows
# build.md, keeps the build toolchain available for debugging, and installs the
# CLI tools plus Python bindings into /opt/blocksci.
#
# Layers are ordered so that expensive dependency installation is cached and
# only the final source COPY is invalidated when application code changes.
# COPY --chown replaces a separate chown -R RUN to avoid duplicating image
# content in an extra layer.
FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ca-certificates cmake git ninja-build pkg-config \
      libboost-all-dev libssl-dev librocksdb-dev libsparsehash-dev \
      libsecp256k1-dev librange-v3-dev nlohmann-json3-dev libcereal-dev \
      libgtest-dev libcurl4-openssl-dev libjsoncpp-dev \
      python3 python3-dev python3-pip python3-venv \
 && rm -rf /var/lib/apt/lists/*

ARG BUILD_JOBS
ARG USERNAME=blocksci
ARG USER_UID=10001
ARG USER_GID=10001

ENV PREFIX=/opt/blocksci \
    VIRTUAL_ENV=/opt/blocksci/venv \
    CMAKE_PREFIX_PATH=/opt/blocksci \
    LD_LIBRARY_PATH=/opt/blocksci/lib \
    PATH=/opt/blocksci/bin:/opt/blocksci/venv/bin:$PATH

WORKDIR /workspace/BlockSci

# Create the non-root user and group before any COPY so --chown can reference
# numeric UID/GID.  /data is also pre-created and owned by that user.
RUN groupadd --gid "$USER_GID" "$USERNAME" \
 && useradd --uid "$USER_UID" --gid "$USER_GID" --create-home --shell /bin/bash "$USERNAME" \
 && mkdir -p /data \
 && chown "$USERNAME:$USERNAME" /data

# Build unpackaged/pinned dependencies before copying the full source tree so
# normal source changes can reuse the dependency layer.
COPY --chown=$USER_UID:$USER_GID scripts/install-unpackaged-deps.sh /tmp/install-unpackaged-deps.sh
RUN bash /tmp/install-unpackaged-deps.sh "$PREFIX" \
 && rm /tmp/install-unpackaged-deps.sh

RUN python3 -m venv "$VIRTUAL_ENV" \
 && "$VIRTUAL_ENV/bin/python" -m pip install --upgrade pip setuptools wheel \
 && "$VIRTUAL_ENV/bin/python" -m pip install \
      pytest \
      pytest-benchmark \
      pytest-regtest \
      pytz \
      tzlocal

COPY --chown=$USER_UID:$USER_GID . .

RUN jobs="${BUILD_JOBS:-$(nproc)}" \
 && cmake -B release \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_PREFIX_PATH="$PREFIX" \
 && cmake --build release -j"$jobs" \
 && cmake --build release --target blocksci_unittest -j"$jobs" \
 && cmake --install release

RUN jobs="${BUILD_JOBS:-$(nproc)}" \
 && CMAKE_BUILD_PARALLEL_LEVEL="$jobs" \
      "$VIRTUAL_ENV/bin/python" -m pip install ./blockscipy \
 && blocksci_parser --help >/tmp/blocksci_parser_help.txt \
 && python -c "import blocksci; print(blocksci.VERSION)"

USER $USERNAME

CMD ["bash"]
