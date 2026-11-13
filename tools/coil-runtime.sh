#!/bin/zsh
# Run time of the Coil compiler as built by this backend against the one LLVM
# built: each checks the compiler's own source. Instructions and cycles are
# what to compare; wall time moves too much.
#   tools/coil-runtime.sh            (after tools/coil-selfcheck.sh, which builds coil-self)
#   tools/coil-runtime.sh profile    also: time by function in each, largest differences first
set -uo pipefail
tree=${COIL_TREE:-$HOME/Documents/Code/projects/coil/.worktrees/declarative}
cd "$tree"
m() { /usr/bin/time -l "$@" 2>&1 >/dev/null | awk '/instructions retired/{i=$1} /cycles elapsed/{c=$1} /real/{r=$1} END{printf "%.2f s, %.1f G instructions, %.1f G cycles", r, i/1e9, c/1e9}'; }
[[ "${1:-}" == profile-only ]] || echo "declarative: $(m build/bin/coil-self check src/compiler/main.coil)"
[[ "${1:-}" == profile-only ]] || echo "llvm:        $(m build/bin/cmp-llvm-O3 check src/compiler/main.coil)"
size build/bin/coil-self build/bin/cmp-llvm-O3 | awk 'NR>1{print "text", $1, $NF}'
if [[ "${1:-}" == profile* ]]; then
  out=$tree/build/runtime-profile; mkdir -p $out
  for which in coil-self cmp-llvm-O3; do
    build/bin/$which check src/compiler/main.coil >/dev/null 2>&1 &
    pid=$!
    sleep 0.3
    sample $pid 60 1 -file $out/$which.sample >/dev/null 2>&1
    wait $pid
  done
  python3 - $out/coil-self.sample $out/cmp-llvm-O3.sample <<'PY'
import re, sys
def top(path):
    counts, on = {}, False
    for line in open(path, errors="ignore"):
        if line.startswith("Sort by top of stack"): on = True; continue
        if on:
            m = re.match(r"\s+(.*?)\s+\(in (\S+)\)\s+(\d+)\s*$", line)
            if m: counts[m.group(1)] = counts.get(m.group(1), 0) + int(m.group(3))
            elif line.strip() == "" and counts: break
    return counts
ours, theirs = top(sys.argv[1]), top(sys.argv[2])
print(f"samples (ms): declarative {sum(ours.values())}, llvm {sum(theirs.values())}")
rows = sorted(((ours.get(k, 0) - theirs.get(k, 0), ours.get(k, 0), theirs.get(k, 0), k) for k in set(ours) | set(theirs)), reverse=True)
print(f"{'more':>6} {'ours':>6} {'llvm':>6}  function")
for d, a, b, k in rows[:45]: print(f"{d:6} {a:6} {b:6}  {k}")
print("  ...")
for d, a, b, k in rows[-8:]: print(f"{d:6} {a:6} {b:6}  {k}")
PY
fi
