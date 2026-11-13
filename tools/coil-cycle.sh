#!/bin/zsh
# After a change to the backend: a Coil compiler with it, Coil's corpus through
# that compiler, the self-reproduction check, and the run time against LLVM's.
#   tools/coil-cycle.sh [profile]
set -uo pipefail
here=$(cd "$(dirname $0)" && pwd)
tree=${COIL_TREE:-$HOME/Documents/Code/projects/coil/.worktrees/declarative}
$here/coil-candidate.sh 2>&1 | grep -v "^built /\|^expanded"
(cd $tree && python3 scripts/oracle.py corpus declarative --compiler build/bin/coil-candidate 2>&1 | grep -E "^FAIL|^corpus")
$here/coil-selfcheck.sh || exit 1
$here/coil-runtime.sh ${1:-}
