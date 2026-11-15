#!/bin/zsh
# Everything that is claimed: the split holds, every rewrite rule agrees with
# the nodes' meanings, the compiler builds, and random programs give the same
# answers interpreted and compiled.
set -euo pipefail
cd "$(dirname $0)/.."
mkdir -p out
# A build that fails stops the check: nothing stale is run in its place.
build() {
  coil build tests/$1.coil --release -O1 -o out/$1 > out/build.log 2>&1 || { cat out/build.log; echo "check: tests/$1.coil did not build"; exit 1 }
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
LINK_BASE=1 out/link
clang tests/link-main.c out/link.o -o out/link-aot
out/link-aot
# The tests that are one program each.
for t in variadic results passing; do
  build $t
  out/$t
done
# The compile straight from CIR: hand-built functions, and random CIR against
# the reference interpreter made from cir.ops.
build cir-interp
out/cir-interp
build direct
out/direct
build cir-fuzz
out/cir-fuzz ${1:-2000}
build fuzz
tools/fuzz-chunks.sh out/fuzz ${1:-2000}
