#!/bin/zsh
# Build and run the linking test and the fuzzer for x86-64 on the Linux host.
#   tools/x64/remote.sh [count] [first-seed] [classic]
# The host's Coil is the one the existing Stogir's x86 work left there. A
# build that fails stops the run: nothing stale is run in its place.
set -eu
cd "$(dirname $0)/../.."
HOST=${X64_HOST:-computer.jimmyhmiller.com}
COIL=${X64_COIL:-'$HOME/stogir-x86/coil/build/x86/coil-llvm'}
sed 's/"a64\./"x64./g; s/tests\.fuzz/tests.fuzz-x64/' tests/fuzz.coil > tests/fuzz-x64.coil
sed 's/"a64\./"x64./g; s/x64\.macho/x64.elf/; s/tests\.link/tests.link-x64/' tests/link.coil > tests/link-x64.coil
# The tests that are one program each, the same on every target.
SINGLES=(variadic results passing)
for t in $SINGLES; do sed "s/\"a64\\./\"x64./g; s/tests\\.$t/tests.$t-x64/" tests/$t.coil > tests/$t-x64.coil; done
rsync -a --delete --exclude .git --exclude out ./ ${HOST}:csd/
ssh -o BatchMode=yes $HOST bash -s -- "$COIL" "${X64_FLAGS:--O1}" "${1:-500}" "${2:-1}" "${3:-}" "$SINGLES" <<'REMOTE'
set -euo pipefail
coil=$(eval echo "$1"); flags=$2; count=$3; first=$4; mode=$5; singles=$6
cd csd && rm -rf out && mkdir -p out
build() { "$coil" build "tests/$1.coil" "${@:3}" -o "out/$2" > out/build.log 2>&1 || { grep -v '^wrote' out/build.log | tail -20; echo "remote: tests/$1.coil did not build"; exit 1; }; }
build link-x64 link -O1
out/link
gcc tests/link-main.c out/link.o -o out/link-aot
out/link-aot
for t in $singles; do build "$t-x64" "$t" -O1; "out/$t"; done
build fuzz-x64 fuzz $flags
tools/fuzz-chunks.sh out/fuzz "$count" "$first" "$mode"
REMOTE
