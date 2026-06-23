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
nix build -L
```

Build the Python bindings on memory-constrained machines:

```bash
nix build .#blockscipy -L --cores 1 --max-jobs 1
```

Build the Python bindings with more parallelism on machines with more RAM:

```bash
nix build .#blockscipy -L --cores 4 --max-jobs 1
```

`packages.blockscipy` forwards `NIX_BUILD_CORES` to CMake through
`CMAKE_BUILD_PARALLEL_LEVEL`, so `--cores` controls the internal
CMake/Ninja parallelism used to compile the Python extension. `--max-jobs`
controls how many Nix derivations may build at the same time. Use
`--max-jobs 1` when you want one build running at a time.

## Run flake checks

Run the default checks for the current system:

```bash
nix flake check -L --cores 4 --max-jobs 1
```

On machines with limited RAM, lower the CMake/Ninja parallelism:

```bash
nix flake check -L --cores 1 --max-jobs 1
```

The current flake check intentionally runs the BTC Python regression suite
only. BCH/LTC checks can be added later as separate follow-ups.

## Development shell

Enter the shell. The shell depends on the Nix-built Python bindings, so the
first invocation may compile `blockscipy` before opening the shell.

```bash
nix develop -L --cores 4 --max-jobs 1
```

On memory-constrained machines, use a serial build:

```bash
nix develop -L --cores 1 --max-jobs 1
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
nix develop -L --cores 4 --max-jobs 1
cd test/blockscipy
python -m pytest --btc -q
```

Or run the same test command without entering an interactive shell:

```bash
nix develop -L --cores 4 --max-jobs 1 --command sh -c 'cd test/blockscipy && python -m pytest --btc -q -W error::DeprecationWarning'
```

The tests use synthetic Bitcoin regtest blocks from `test/files/btc/regtest/` and call `blocksci_parser` from the Nix package.

## Run benchmarks

```bash
nix develop -L --cores 4 --max-jobs 1
cd test/benchmark
python -m pytest --btc -v --benchmark-autosave --benchmark-warmup=true --benchmark-warmup-iterations=1 --benchmark-sort=name --benchmark-columns=mean,median,max,rounds,iterations
```

## Logs, cache, and rebuilds

Nix is quiet on success, especially when outputs are already present in the
store. A command that prints no build output may still have passed. Check the
exit status with:

```bash
echo $?
```

After `nix build`, the `result` symlink points to the built output:

```bash
readlink result
```

Inspect logs from existing build outputs:

```bash
nix log .#blockscipy
nix log .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).blockscipy-btc
```

Force a rebuild when you need fresh live output:

```bash
nix build .#blockscipy -L --rebuild --cores 4 --max-jobs 1
nix flake check -L --rebuild --cores 4 --max-jobs 1
```

## Known-pools data

`Blockchain-Known-Pools` is fetched by Nix and exposed through `BLOCKSCI_POOLS_JSON`.
The project no longer requires that repository as a Git submodule.
