# Building BlockSci with Nix

This project ships a Nix flake that provides:

- Two package derivations (`packages.default` for libblocksci + tools,
  `packages.blockscipy` for the Python bindings).
- A development shell (`devShells.default`) that reproduces the upstream
  build manual with all native dependencies preinstalled, no system pollution.

The flake is pinned to `nixpkgs-25.11` and targets the four default systems
(`x86_64`/`aarch64` × Linux/macOS).

## Build libblocksci and the command-line tools

```
nix build
```

## Build the Python bindings

```
nix build .#blockscipy
```

## Building in the development shell

This workflow builds the project step by step, self-contained under
`.nix-install/`, `.nix-pip/` and `release`.

1. Enter the shell:

```
nix develop
```

2. Build and install libblocksci:

```bash
mkdir release && cd release
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=../.nix-install ..
make
make install
cd ..
```

3. Build the Python bindings:

```
pip install --no-build-isolation --prefix=$LOCAL_PIP ./blockscipy
```

`LOCAL_PIP`, `CMAKE_PREFIX_PATH` and the dynamic-linker search path
(`LD_LIBRARY_PATH`, or `DYLD_LIBRARY_PATH` on macOS) are exported by the
shellHook so the two halves find each other at build and run time.
`--no-build-isolation` makes pip use the `scikit-build-core` backend from the
shell instead of fetching it from PyPI.
