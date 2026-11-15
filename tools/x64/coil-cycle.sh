#!/usr/bin/env bash
# After a change to the backend, on x86-64 Linux: a Coil compiler with it
# (tools/x64/coil-host.sh), Coil's corpus through that compiler, the compiler
# it builds of itself and whether that rebuilds itself to the same object, the
# corpus through it too, and its run time against the compiler LLVM built.
#   tools/x64/coil-cycle.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
HOST=${X64_HOST:-computer.jimmyhmiller.com}
"$here/coil-host.sh" 2>&1 | tail -1
ssh -o BatchMode=yes $HOST 'cd ~/csd-coil; export COIL_LIBRARY_STATE=0
T=~/stogir-x86/coil-adapter/docs/benchmarks/x86/tools
C=build/x64/llvm/bin/coil
python3 scripts/oracle.py corpus native --compiler $C 2>&1 | grep -E "^FAIL|^corpus" | cut -c1-200
$C emit-obj src/compiler/main.coil --backend native -O2 --no-debug -o build/x64/self1.o 2>&1 | grep -v "^wrote" | head -4
bash $T/link-host-linux.sh . build/x64/self1.o build/x64/self 2>&1 | grep -v "^linked" | tail -3
build/x64/self/bin/coil emit-obj src/compiler/main.coil --backend native -O2 --no-debug -o build/x64/self2.o 2>&1 | grep -v "^wrote" | head -4
cmp -s build/x64/self1.o build/x64/self2.o && echo "selfcheck: the compiler built by the backend rebuilds itself to the same object" || echo "selfcheck: FAILED"
python3 scripts/oracle.py corpus native --compiler build/x64/self/bin/coil 2>&1 | grep -E "^FAIL|^corpus" | cut -c1-200 | sed "s/^corpus/corpus through the self-built compiler/"
[ -x build/x64/llvm-O3/bin/coil ] || MKHOST_SERIAL=0 bash $T/mkhost-linux.sh . $C llvm build/x64/llvm-O3 > /dev/null 2>&1
for c in self llvm-O3; do for r in 1 2 3; do perf stat -x, -e cycles,instructions build/x64/$c/bin/coil check src/compiler/main.coil 2>&1 >/dev/null | awk -F, "{printf \"%s \", \$1}"; echo; done | awk -v c=$c "NR==1||\$1<cy{cy=\$1} NR==1||\$2<ins{ins=\$2} END{printf \"%s %.1f %.1f\n\", c, cy/1e9, ins/1e9}"; done | awk "{n[NR]=\$1; cy[NR]=\$2; ins[NR]=\$3} END{printf \"declarative: %.1f G instructions  %.1f G cycles\nllvm:        %.1f G instructions  %.1f G cycles\nagainst LLVM (goal 1.10): %.2fx cycles, %.2fx instructions\n\", ins[1], cy[1], ins[2], cy[2], cy[1]/cy[2], ins[1]/ins[2]}"
size build/x64/self/bin/coil build/x64/llvm-O3/bin/coil | awk "NR>1{print \"text\", \$1, \$NF}"'
