#!/bin/zsh
# The backend as plain Coil: every module the languages make from src/, written
# out as a file of its own, with the runtime and the Coil adapter beside them.
# A project that cannot run the languages (the Coil compiler builds itself
# without a manifest) compiles this tree instead.
#   tools/expand.sh [directory] [package]        default out/expanded, no package
# With a package name, the tree is that package: every module's name begins
# with it (a64.unit is PACKAGE.a64.unit), as Coil asks of a package's modules,
# and a Coil.toml says so.
set -euo pipefail
cd "$(dirname $0)/.."
to=${1:-$PWD/out/expanded}
mkdir -p "$to"
to=$(cd "$to" && pwd)
rm -rf "$to"/{a64,x64,a64-base,x64-base,a64-direct,x64-direct,cir,backend,rt,declarative}
mkdir -p out
sed 's/"a64\./"x64./g; s/x64\.macho/x64.elf/; s/tests\.link/tests.link-x64/' tests/link.coil > tests/link-x64.coil
sed 's/"a64-direct\./"x64-direct./g; s/"a64\.target"/"x64.target"/; s/tests\.direct/tests.direct-x64/' tests/direct.coil > tests/direct-x64.coil
sed 's/"a64-direct\./"x64-direct./g; s/"a64\.target"/"x64.target"/; s/tests\.cir-fuzz/tests.cir-fuzz-x64/' tests/cir-fuzz.coil > tests/cir-fuzz-x64.coil
# Checking a program that uses a target reads every module of that target.
DECLARATIVE_EXPAND="$to" coil check tests/link.coil
DECLARATIVE_EXPAND="$to" coil check tests/link-x64.coil
DECLARATIVE_EXPAND="$to" coil check tests/direct.coil
DECLARATIVE_EXPAND="$to" coil check tests/direct-x64.coil
mkdir -p "$to/rt" "$to/declarative"
cp compiler/rt/*.coil "$to/rt/"
# The adapter is written once and written out for each machine, its
# `machine-pick`s answered by that machine's `target`.
for f in adapter/*.coil; do [[ $f == adapter/machine.coil ]] || cp $f "$to/declarative/"; done
for m in a64 x64; do
  sed "s/^(module declarative\.machine)/(module declarative.machine-$m)/; s/(import \"declarative\.target\" :as target)/(import \"declarative.target-$m\" :as target)/" \
    adapter/machine.coil > "$to/declarative/machine-$m.coil"
  grep -q "^(module declarative.machine-$m)" "$to/declarative/machine-$m.coil" && grep -q "\"declarative.target-$m\"" "$to/declarative/machine-$m.coil" \
    || { echo "expand: declarative.machine-$m was not written" >&2; exit 1; }
done
for unit in a64 x64; do
  for module in unit target lower abi simplify narrow facts cfg promote forward loops switches tails selects copies schedule mach select atomics blocks split alloc frames emit plans; do
    [[ -f "$to/$unit/$module.coil" ]] || { echo "expand: $unit.$module was not written" >&2; exit 1; }
  done
done
for unit in a64 x64; do
  for module in unit lower mach regs select walk frames plans; do
    [[ -f "$to/$unit-direct/$module.coil" ]] || { echo "expand: $unit-direct.$module was not written" >&2; exit 1; }
  done
done
[[ -f "$to/cir/ops.coil" ]] || { echo "expand: cir.ops was not written" >&2; exit 1; }
if [[ -n "${2:-}" ]]; then
  python3 tools/expand-package.py "$to" "$2"
fi
echo "expanded into $to: $(find "$to" -name '*.coil' | wc -l | tr -d ' ') files, $(cat "$to"/**/*.coil | wc -l | tr -d ' ') lines"
