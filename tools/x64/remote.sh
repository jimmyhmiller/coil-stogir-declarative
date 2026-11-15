#!/bin/zsh
# Build and run the linking test and the fuzzer for x86-64 on the Linux host.
#   tools/x64/remote.sh [count] [first-seed] [classic]
# The host's Coil is the checkout tools/x64/coil-host.sh builds there. A
# build that fails stops the run: nothing stale is run in its place.
set -eu
cd "$(dirname $0)/../.."
HOST=${X64_HOST:-computer.jimmyhmiller.com}
COIL=${X64_COIL:-'$HOME/csd-coil/build/x64/llvm/bin/coil'}
sed 's/"a64\./"x64./g; s/tests\.fuzz/tests.fuzz-x64/' tests/fuzz.coil > tests/fuzz-x64.coil
sed 's/"a64\./"x64./g; s/x64\.macho/x64.elf/; s/tests\.link/tests.link-x64/' tests/link.coil > tests/link-x64.coil
# The tests that are one program each, the same on every target.
SINGLES=(variadic results passing)
for t in $SINGLES; do sed "s/\"a64\\./\"x64./g; s/tests\\.$t/tests.$t-x64/" tests/$t.coil > tests/$t-x64.coil; done
rsync -a --delete --exclude .git --exclude out ./ ${HOST}:csd/
# ssh hands the far side one line: each argument is quoted for its shell, so
# that an empty one stays an argument.
args=("$COIL" "${X64_FLAGS:--O1}" "${1:-500}" "${2:-1}" "${3:-}" "$SINGLES")
ssh -o BatchMode=yes $HOST "bash -s -- ${(j: :)${(qq)args[@]}}" <<'REMOTE'
set -euo pipefail
coil=$(eval echo "$1"); flags=$2; count=$3; first=$4; mode=$5; singles=$6
cd csd && rm -rf out && mkdir -p out
# CIR comes from the Coil checkout tools/x64/coil-host.sh keeps on the host.
sed -i 's|path = "[^"]*/src/compiler/native"|path = "../csd-coil/src/compiler/native"|' Coil.toml
build() { "$coil" build "tests/$1.coil" "${@:3}" -o "out/$2" > out/build.log 2>&1 || { grep -v '^wrote' out/build.log | tail -20; echo "remote: tests/$1.coil did not build"; exit 1; }; }
build link-x64 link -O1
out/link
gcc tests/link-main.c out/link.o -o out/link-aot
out/link-aot
for t in $singles; do build "$t-x64" "$t" -O1; "out/$t"; done
# Compiled straight from CIR: the cases written out, then random functions
# against the reference interpreter.
build direct-x64 direct -O1
out/direct
build cir-fuzz-x64 cir-fuzz -O1
out/cir-fuzz "$count" "$first"
build fuzz-x64 fuzz $flags
tools/fuzz-chunks.sh out/fuzz "$count" "$first" "$mode"
REMOTE
