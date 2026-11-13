#!/bin/zsh
# Everything that is claimed: the split holds, every rewrite rule agrees with
# the nodes' meanings, the compiler builds, and random programs give the same
# answers interpreted and compiled.
set -euo pipefail
cd "$(dirname $0)/.."
mkdir -p out
python3 tools/lines.py
coil build tests/rules.coil -O1 -o out/rules | grep -v '^wrote' || true
out/rules
# Linking: in memory, and as an object file through the system's linker.
coil build tests/link.coil -O1 -o out/link | grep -v '^wrote' || true
out/link
clang tests/link-main.c out/link.o -o out/link-aot
out/link-aot
coil build tests/fuzz.coil -O1 -o out/fuzz | grep -v '^wrote' || true
# In chunks under a time limit, so that generated code that never returns fails the check.
count=${1:-2000}
for first in $(seq 1 250 $count); do
  /usr/bin/perl -e 'alarm 300; exec @ARGV' out/fuzz 250 $first | tail -2 | head -1
done
