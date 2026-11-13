#!/bin/zsh
# Write the backend out into the Coil worktree and build a compiler with it.
#   tools/coil-candidate.sh        → $COIL_TREE/build/bin/coil-candidate
set -euo pipefail
cd "$(dirname $0)/.."
tree=${COIL_TREE:-$HOME/Documents/Code/projects/coil/.worktrees/declarative}
notice=$(cat "$tree/src/compiler/declarative/NOTICE")
tools/expand.sh "$tree/src/compiler/declarative" declarative | tail -1
print -r -- "$notice" > "$tree/src/compiler/declarative/NOTICE"
(cd "$tree" && python3 scripts/dev.py build candidate 2>&1 | grep -E "^error|^built compiler|panic" -A6 | head -40)
