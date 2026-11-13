#!/usr/bin/env bash
# The fuzzer in chunks of 250 seeds under a time limit, so that generated code
# that never returns fails. A chunk that fails or crashes is run again a seed
# at a time, to name the seeds. At the end, what each transformation did over
# the whole run: one that never fired was not tested, and fails the run.
#   tools/fuzz-chunks.sh FUZZER [count] [first-seed] [classic]
set -euo pipefail
fuzz=$1
count=${2:-2000}
first=${3:-1}
mode=${4:-}
limit() { if command -v timeout > /dev/null; then timeout "$@"; else /usr/bin/perl -e 'alarm shift; exec @ARGV' "$@"; fi }
fired=$(mktemp)
trap 'rm -f "$fired"' EXIT
for start in $(seq "$first" 250 $((first + count - 1))); do
  n=$(( first + count - start < 250 ? first + count - start : 250 ))
  if ! out=$(limit 300 "$fuzz" "$n" "$start" $mode 2>&1); then
    printf '%s\n' "$out" | grep -E '^seed|panic' | head -20 || true
    for s in $(seq "$start" $((start + n - 1))); do
      limit 60 "$fuzz" 1 "$s" $mode > /dev/null 2>&1 || echo "fuzz: seed $s fails ($fuzz 1 $s $mode shows it)"
    done
    exit 1
  fi
  printf '%s\n' "$out" | grep 'programs,'
  printf '%s\n' "$out" | grep '^fired:' >> "$fired"
done
python3 - "$fired" "$mode" <<'PY'
import sys
total = {}
for line in open(sys.argv[1]):
    for item in line.split()[1:]:
        name, n = item.split("=")
        total[name] = total.get(name, 0) + int(n)
print("fired: " + " ".join(f"{k}={v}" for k, v in total.items()))
never = [k for k, v in total.items() if v == 0]
# The classic programs are the plain ones: most transformations have nothing to do there.
if never and sys.argv[2] != "classic":
    print("fuzz: never fired, so not tested by these programs: " + " ".join(never))
    sys.exit(1)
PY
