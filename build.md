# Building BlockSci from source

This guide builds BlockSci on Linux or macOS using your system toolchain and
package manager, for environments where [Nix](nix.md) is not available.

The Nix flake remains the canonical, reproducible build — it pins every
dependency and is what CI builds. Prefer it when you can; see [nix.md](nix.md).
This document is the supported manual path for everyone else.

BlockSci is built in two halves:

- `libblocksci` and the command-line tools (`blocksci_parser`,
  `blocksci_clusterer`, …), built with CMake.
- `blockscipy`, the Python bindings, built on top of the installed C++ library
  via `scikit-build-core`.

## Requirements

- A C++17 compiler (recent GCC or Clang)
- CMake ≥ 3.15
- Python ≥ 3.11 with `pip`
- `git`

Both halves and the from-source dependencies install into a single prefix so
they find each other. By default we use a disposable, project-local prefix — run
this from the repository root:

```bash
export PREFIX="$PWD/install"
```

For a system-wide install, use `PREFIX=/usr/local` with `sudo`; it's on the
default loader path, so you can skip the `LD_LIBRARY_PATH` step at the end.

## Dependencies

BlockSci's dependencies fall into two groups: those your package manager
provides, and a handful that are not packaged and are built from source by a
helper script.

### System packages

#### **Debian / Ubuntu:**

```bash
sudo apt install \
  build-essential cmake git \
  libboost-all-dev libssl-dev librocksdb-dev libsparsehash-dev \
  libsecp256k1-dev librange-v3-dev nlohmann-json3-dev libcereal-dev \
  libgtest-dev libcurl4-openssl-dev libjsoncpp-dev
```

#### **macOS (Homebrew):**

```bash
brew install \
  cmake git boost openssl rocksdb google-sparsehash libsecp256k1 \
  range-v3 nlohmann-json cereal googletest curl jsoncpp
```

#### **Arch Linux:**

> **Note:** Arch is not supported yet. Its rolling `rocksdb` (≥ 11) removed the
> `DB**` `Open` API that BlockSci still uses, so the library fails to compile.
> Use Ubuntu or macOS until BlockSci's rocksdb usage is modernized.

```bash
sudo pacman -S --needed \
  base-devel cmake git boost openssl rocksdb sparsehash libsecp256k1 \
  range-v3 nlohmann-json cereal gtest curl jsoncpp
```

### Unpackaged dependencies

A few small libraries are not available from apt or Homebrew. The helper script
builds them from source — pinned to the same revisions as the Nix flake — and
installs them into `$PREFIX`:

```bash
./scripts/install-unpackaged-deps.sh "$PREFIX"
```

This installs the header-only libraries `mpark/variant`, `wjfilesystem`, `mio`,
`dset`, `steinwurf/endian`, `clipp`, and Howard Hinnant's `date`, plus the
compiled libraries `libjson-rpc-cpp` and `bitcoin-api-cpp`.

## Build libblocksci and the tools

```bash
cmake -B release \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_PREFIX_PATH="$PREFIX"
cmake --build release
cmake --install release
```

`CMAKE_PREFIX_PATH` points CMake at the unpackaged dependencies installed above.
On macOS, append Homebrew's prefix so its packages are found, and point CMake at
the keg-only OpenSSL:
`-DCMAKE_PREFIX_PATH="$PREFIX;$(brew --prefix)" -DOPENSSL_ROOT_DIR="$(brew --prefix openssl)"`.

## Build the Python bindings

On Debian/Ubuntu the bindings also need `python3-dev` (Python headers) and, for
the step below, `python3-venv` — both split out from the base `python3` package
(other platforms' `python` already includes them).

Install into a virtual environment so the build does not touch system Python:

```bash
python3 -m venv "$PREFIX/venv"
source "$PREFIX/venv/bin/activate"
```

`pip` reads `blockscipy/pyproject.toml`, builds the pybind11 module against the
installed C++ library, and pulls the Python runtime dependencies from PyPI:

```bash
CMAKE_PREFIX_PATH="$PREFIX" pip install ./blockscipy
```

## Make the library findable at runtime

The tools and the Python module load `libblocksci` at run time. Unless `$PREFIX`
is a standard system location, add its library directory to the loader path:

```bash
# Linux
export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"
# macOS
export DYLD_LIBRARY_PATH="$PREFIX/lib:$DYLD_LIBRARY_PATH"
```

## Verify

```bash
"$PREFIX/bin/blocksci_parser" --help
python -c "import blocksci; print(blocksci.VERSION)"
```
