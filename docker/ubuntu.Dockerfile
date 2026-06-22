# Validates the non-nix build (build.md) on Ubuntu 24.04 — the GitHub CI image.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake git \
      libboost-all-dev libssl-dev librocksdb-dev libsparsehash-dev \
      libsecp256k1-dev librange-v3-dev nlohmann-json3-dev libcereal-dev \
      libgtest-dev libcurl4-openssl-dev libjsoncpp-dev \
      python3 python3-dev python3-venv \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

ENV PREFIX=/src/install
RUN ./scripts/install-unpackaged-deps.sh "$PREFIX"

RUN cmake -B release \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$PREFIX" \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_PREFIX_PATH="$PREFIX" \
 && cmake --build release -j"$(nproc)" \
 && cmake --install release

ENV LD_LIBRARY_PATH=/src/install/lib
RUN python3 -m venv "$PREFIX/venv" \
 && . "$PREFIX/venv/bin/activate" \
 && CMAKE_PREFIX_PATH="$PREFIX" pip install ./blockscipy \
 && "$PREFIX/bin/blocksci_parser" --help \
 && python -c "import blocksci; print(blocksci.VERSION)"
