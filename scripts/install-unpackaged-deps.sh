#!/usr/bin/env bash
#
# Install BlockSci's unpackaged C++ dependencies from source.
#
# These are the dependencies that are not reliably available from system
# package managers (apt/Homebrew). Everything else is a system package; see
# build.md. Versions are pinned to mirror flake.nix, the canonical build.
#
# Usage:
#   scripts/install-unpackaged-deps.sh [PREFIX]
#
# PREFIX is where headers and libraries are installed; it defaults to
# $PWD/install (override via the first argument or the PREFIX env var). Pass
# the same PREFIX to BlockSci's CMake configure step via -DCMAKE_PREFIX_PATH.

set -euo pipefail

PREFIX="${1:-${PREFIX:-$PWD/install}}"
mkdir -p "$PREFIX"
PREFIX="$(cd "$PREFIX" && pwd)"
JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
trap 'exit 130' INT TERM

log() {
  if [ -t 2 ]; then
    printf '\n\033[1m==> %s\033[0m\n' "$*" >&2
  else
    printf '\n==> %s\n' "$*" >&2
  fi
}

# fetch OWNER/REPO REV -> prints the path to the checked-out tree
fetch() {
  local slug="$1" rev="$2" dest="$workdir/${1##*/}"
  git clone --quiet "https://github.com/$slug.git" "$dest"
  git -C "$dest" -c advice.detachedHead=false checkout --quiet "$rev"
  printf '%s\n' "$dest"
}

mkdir -p "$PREFIX/include"

# --- header-only libraries -------------------------------------------------
# Each is copied so the layout matches the find_path() calls in
# external/CMakeLists.txt (e.g. <mpark/variant.hpp>, <clipp.h>).

log "mpark/variant 1.3.0"
src="$(fetch mpark/variant v1.3.0)"
cp -R "$src/include/." "$PREFIX/include/"

log "hkalodner/filesystem (<wjfilesystem/path.h>)"
src="$(fetch hkalodner/filesystem 8cb505d6f51479645e670366df45951eeacb9fc4)"
cp -R "$src/include/." "$PREFIX/include/"

log "hkalodner/mio (<mio/mmap.hpp>)"
src="$(fetch hkalodner/mio 9d2d5f397cad9ca6d2dfa31cd6716fdd98542862)"
cp -R "$src/include/." "$PREFIX/include/"

log "wjakob/dset (<dset/dset.h>)"
src="$(fetch wjakob/dset 7967ef0e6041cd9d73b9c7f614ab8ae92e9e587a)"
mkdir -p "$PREFIX/include/dset"
cp "$src/dset.h" "$PREFIX/include/dset/"

log "steinwurf/endian 10.0.0 (<endian/big_endian.hpp>)"
src="$(fetch steinwurf/endian 10.0.0)"
cp -R "$src/src/endian" "$PREFIX/include/"

log "muellan/clipp 1.2.3 (<clipp.h>)"
src="$(fetch muellan/clipp v1.2.3)"
cp "$src/include/clipp.h" "$PREFIX/include/"

log "HowardHinnant/date 3.0.1 (<date/date.h>, needed by the Python bindings)"
src="$(fetch HowardHinnant/date v3.0.1)"
cp -R "$src/include/." "$PREFIX/include/"

# --- compiled libraries ----------------------------------------------------
# Homebrew installs outside the default search paths on macOS; add its prefix
# when present (jsoncpp and curl come from the system package manager).
prefix_path="$PREFIX"
if command -v brew >/dev/null 2>&1; then
  prefix_path="$PREFIX;$(brew --prefix)"
fi

log "cinemast/libjson-rpc-cpp 1.4.1 (HTTP client only)"
src="$(fetch cinemast/libjson-rpc-cpp v1.4.1)"
for pat in 'cmake_minimum_required(VERSION 3.0)' 'cmake_policy(SET CMP0042 OLD)'; do
  grep -qF "$pat" "$src/CMakeLists.txt" \
    || { echo "libjson-rpc-cpp: expected '$pat' not found" >&2; exit 1; }
done
sed -i.bak \
  -e 's/cmake_minimum_required(VERSION 3.0)/cmake_minimum_required(VERSION 3.10)/' \
  -e '/cmake_policy(SET CMP0042 OLD)/d' \
  "$src/CMakeLists.txt"
cmake -S "$src" -B "$src/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_PREFIX_PATH="$prefix_path" \
  -DHTTP_SERVER=NO -DREDIS_SERVER=NO -DREDIS_CLIENT=NO \
  -DCOMPILE_TESTS=NO -DCOMPILE_STUBGEN=NO -DCOMPILE_EXAMPLES=NO \
  -DWITH_COVERAGE=NO
cmake --build "$src/build" -j "$JOBS"
cmake --install "$src/build"

log "hkalodner/bitcoin-api-cpp"
src="$(fetch hkalodner/bitcoin-api-cpp 952bef34a7ad63f752982afcc6231013db7a19dd)"
# Drop the optional test suite: it pulls Boost (unit tests only) and breaks on
# newer Boost/CMake (Arch). We only need the library.
grep -qF 'FIND_PACKAGE(Boost COMPONENTS unit_test_framework)' "$src/CMakeLists.txt" \
  || { echo "bitcoin-api-cpp: expected Boost test block not found" >&2; exit 1; }
sed -i.bak '/FIND_PACKAGE(Boost COMPONENTS unit_test_framework)/,/ENDIF()/d' "$src/CMakeLists.txt"
cmake -S "$src" -B "$src/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_PREFIX_PATH="$prefix_path"
cmake --build "$src/build" -j "$JOBS"
cmake --install "$src/build"

log "Done. Installed into $PREFIX"
echo "Configure BlockSci with -DCMAKE_PREFIX_PATH=$PREFIX (see build.md)."
