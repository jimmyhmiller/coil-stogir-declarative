#!/bin/zsh
# The Coil compiler built by the backend must work as the one built by LLVM
# does: built by each, it compiles itself to the same object.
#   tools/coil-selfcheck.sh      (after tools/coil-candidate.sh)
set -uo pipefail
tree=${COIL_TREE:-$HOME/Documents/Code/projects/coil/.worktrees/declarative}
cd "$tree"
flags=($(scripts/compiler/llvm-link-flags.sh dynamic))
build/bin/coil-candidate build src/compiler/main.coil --backend native -O2 --release -o build/bin/coil-self $flags >/dev/null 2>&1 || { echo "selfcheck: the compiler did not build"; exit 1; }
build/bin/coil-candidate emit-obj src/compiler/main.coil --backend native -O2 --no-debug -o build/self1.o >/dev/null 2>&1
build/bin/coil-self emit-obj src/compiler/main.coil --backend native -O2 --no-debug -o build/self2.o >/dev/null 2>&1 || { echo "selfcheck: the compiler built by the backend failed to compile"; exit 1; }
cmp -s build/self1.o build/self2.o && echo "selfcheck: the compiler built by the backend rebuilds itself to the same object" || { echo "selfcheck: the objects differ"; exit 1; }
