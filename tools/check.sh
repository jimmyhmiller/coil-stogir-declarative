#!/bin/zsh
# Everything that is claimed: the split holds, every rewrite rule agrees with
# the nodes' meanings, the compiler builds, and random programs give the same
# answers interpreted and compiled.
set -euo pipefail
cd "$(dirname $0)/.."
mkdir -p out
# A build that fails stops the check: nothing stale is run in its place.
build() {
  coil build tests/$1.coil -O1 -o out/$1 > out/build.log 2>&1 || { cat out/build.log; echo "check: tests/$1.coil did not build"; exit 1 }
}
python3 tools/lines.py
build rules
out/rules
# The second client: a calculator built by the same language implementations.
build toy
out/toy
# Linking: in memory, and as an object file through the system's linker.
build link
out/link
clang tests/link-main.c out/link.o -o out/link-aot
out/link-aot
# The tests that are one program each.
for t in variadic results passing; do
  build $t
  out/$t
done
build fuzz
# In chunks under a time limit, so that generated code that never returns fails the check.
count=${1:-2000}
for first in $(seq 1 250 $count); do
  /usr/bin/perl -e 'alarm 300; exec @ARGV' out/fuzz 250 $first | tail -2 | head -1
done
