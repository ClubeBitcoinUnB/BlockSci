# Running BlockSci with Docker

This repository is Nix-first. Prefer the reproducible flake build in
[nix.md](nix.md) when Nix is available.

Docker is the supported Ubuntu-based path for contributors who do not use Nix
or who want a Linux development environment that follows the manual build in
[build.md](build.md).

## Build the image

From the repository root:

```bash
docker build -f docker/ubuntu.Dockerfile -t blocksci:ubuntu .
```

On memory-constrained machines, lower CMake/Python extension parallelism:

```bash
docker build \
  -f docker/ubuntu.Dockerfile \
  --build-arg BUILD_JOBS=2 \
  -t blocksci:ubuntu \
  .
```

The image installs BlockSci into `/opt/blocksci` and keeps the build tree under
`/workspace/BlockSci` for debugging.

The container runs as a non-root `blocksci` user with UID/GID `10001` by
default. Override `USER_UID` and `USER_GID` at build time only if you need a
specific container user identity.

## Start a shell

```bash
docker run --rm -it blocksci:ubuntu
```

Inside the container, the CLI tools and Python environment are already on
`PATH`:

```bash
blocksci_parser --help
python -c 'import blocksci; print(blocksci.VERSION)'
```

## Mount data

Use `/data` for BlockSci output and mount a full-node data directory read-only
when parsing real chain data:

```bash
docker run --rm -it \
  -v "$PWD/blocksci-data:/data" \
  -v "$HOME/.bitcoin:/bitcoin:ro" \
  blocksci:ubuntu
```

Example parser flow inside the container:

```bash
blocksci_parser /data/config.json generate-config bitcoin /data --disk /bitcoin
blocksci_parser /data/config.json doctor
blocksci_parser /data/config.json update
```

For the repository's synthetic BTC regtest data:

```bash
blocksci_parser /tmp/btc.json generate-config bitcoin_regtest /tmp/btc --disk test/files/btc/regtest/
blocksci_parser /tmp/btc.json doctor
blocksci_parser /tmp/btc.json update
blocksci_check_integrity /tmp/btc.json -t -n
```

## Run tests in the image

Quick smoke checks:

```bash
docker run --rm blocksci:ubuntu blocksci_parser --help
docker run --rm blocksci:ubuntu python -c 'import blocksci; print(blocksci.VERSION)'
```

Parser plus integrity smoke using the bundled BTC regtest chain:

```bash
docker run --rm blocksci:ubuntu sh -lc '\
  cd /workspace/BlockSci/test && \
  blocksci_parser btc.json generate-config bitcoin_regtest bitcoin_regtest --disk files/btc/regtest/ && \
  blocksci_parser btc.json doctor && \
  blocksci_parser btc.json update && \
  blocksci_check_integrity btc.json -t -n'
```

BTC Python regression smoke test:

```bash
docker run --rm blocksci:ubuntu \
  sh -lc 'cd /workspace/BlockSci/test/blockscipy && python -m pytest --btc -q'
```

The image also builds the C++ unit-test binary explicitly, matching the active
legacy CircleCI behavior:

```bash
docker run --rm blocksci:ubuntu sh -lc '\
  cd /workspace/BlockSci/test && \
  blocksci_parser btc.json generate-config bitcoin_regtest bitcoin_regtest --disk files/btc/regtest/ && \
  blocksci_parser btc.json doctor && \
  blocksci_parser btc.json update && \
  cd /workspace/BlockSci && \
  ./release/test/blocksci/blocksci_unittest test/btc.json'
```

## Docker Compose

For an interactive development shell with the repository and `/data` mounted:

```bash
docker compose run --build --rm blocksci
```

The compose workflow uses the same `docker/ubuntu.Dockerfile` image. Installed
tools remain in `/opt/blocksci`, so mounting the source tree does not hide the
CLI tools or Python bindings.

`blocksci:ubuntu` is a local image tag, not a published registry image. The
`--build` flag ensures Docker Compose builds it from this repository instead of
trying to pull it from Docker Hub on a fresh setup.

## CI parity contract

Future GitHub Actions should preserve active Travis/CircleCI feature coverage
using the current build system:

- C++ build and install.
- BTC/BCH/LTC parser `generate-config`, `doctor`, and `update` checks.
- BTC/BCH/LTC `blocksci_check_integrity` checks.
- Explicit `blocksci_unittest` build and gtest XML output.
- `blockscipy` build via `pyproject.toml` and Python >= 3.11.
- Python pytest suite.
- Benchmarks and test-artifact upload.

Commented-out legacy Travis jobs, including macOS/Homebrew and docs generation,
are historical references and are not part of active parity by default.
