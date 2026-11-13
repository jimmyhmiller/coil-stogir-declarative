#!/bin/zsh
# Build and run the linking test and the fuzzer for x86-64 on the Linux host.
#   tools/x64/remote.sh [count] [first-seed] [classic]
# The host's Coil is the one the existing Stogir's x86 work left there.
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
ssh -o BatchMode=yes $HOST "cd csd && mkdir -p out && $COIL build tests/link-x64.coil -O1 -o out/link 2>&1 | grep -v '^wrote' | tail -20; out/link && gcc tests/link-main.c out/link.o -o out/link-aot && out/link-aot; for t in $SINGLES; do $COIL build tests/\$t-x64.coil -O1 -o out/\$t 2>&1 | grep -v '^wrote' | tail -20; out/\$t; done; $COIL build tests/fuzz-x64.coil ${X64_FLAGS:--O1} -o out/fuzz 2>&1 | grep -v '^wrote' | tail -20; first=${2:-1}; last=\$((first + ${1:-500} - 1)); for s in \$(seq \$first 100 \$last); do timeout 300 out/fuzz 100 \$s ${3:-} 2>&1 | grep -v '^code:' | grep -v ' 0 failed' | grep -v spilled | cut -c1-180 | head -6; rc=\${pipestatus[0]:-0}; done; echo done"
