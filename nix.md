# Building and Testing BlockSci with Nix

This repository is Nix-first. The flake provides:

- `packages.default`: libblocksci and command-line tools, including `blocksci_parser`.
- `packages.blockscipy`: Python bindings for BlockSci.
- `devShells.default`: a ready-to-use development/test shell with BlockSci, pytest, and benchmark dependencies.

The flake is pinned to `nixpkgs-25.11` and targets the four default systems
(`x86_64`/`aarch64` × Linux/macOS).

## Build packages

Build the C++ library and command-line tools:

```bash
nix build
```

Build the Python bindings:

```bash
nix build .#blockscipy
```

## Development shell

Enter the shell:

```bash
nix develop
```

Inside the shell, Python imports the Nix-built `blocksci` package directly. No `pip install`, `LOCAL_PIP`, `.nix-pip`, or manual `PYTHONPATH` setup is required.

Useful smoke checks:

```bash
python -c 'import blocksci; print(blocksci.__file__)'
which blocksci_parser
```

Both should point into `/nix/store`.

## Run Python regression tests

```bash
nix develop
cd test/blockscipy
python -m pytest --btc -q
```

The tests use synthetic Bitcoin regtest blocks from `test/files/btc/regtest/` and call `blocksci_parser` from the Nix package.
The initial flake check intentionally covers BTC regtest only; BCH/LTC checks can be added later as separate follow-ups.

## Run benchmarks

```bash
nix develop
cd test/benchmark
python -m pytest --btc -v --benchmark-autosave --benchmark-warmup=true --benchmark-warmup-iterations=1 --benchmark-sort=name --benchmark-columns=mean,median,max,rounds,iterations
```

## Known-pools data

`Blockchain-Known-Pools` is fetched by Nix and exposed through `BLOCKSCI_POOLS_JSON`.
The project no longer requires that repository as a Git submodule.
