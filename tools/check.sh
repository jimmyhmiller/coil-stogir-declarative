#!/bin/zsh
# Everything that is claimed: the split holds, the compiler builds, and random
# programs give the same answers interpreted and compiled.
set -euo pipefail
cd "$(dirname $0)/.."
mkdir -p out
python3 tools/lines.py
coil build tests/fuzz.coil -O1 -o out/fuzz | grep -v '^wrote' || true
out/fuzz ${1:-2000}
