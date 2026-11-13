#!/bin/zsh
# Coil's programs through this backend against the same through LLVM: the
# corpus, the demos, the SIMD and backend tests, the standard library's
# suites and the example projects, at -O1 and -O2. Uses Coil's own sweep
# (scripts/tests/stogir-x86-sweep.py) with the backend's name put in.
#   tools/coil-sweep.sh           here, with the candidate compiler
#   tools/coil-sweep.sh x64       on the Linux host, with the compiler linked there
#   tools/coil-sweep.sh library   here: the old Stogir library's own tests (about
#                                 a thousand small programs), from $STOGIR_LIBRARY
set -uo pipefail
tree=${COIL_TREE:-$HOME/Documents/Code/projects/coil/.worktrees/declarative}
groups=(--group corpus --group demos --group simd --group backend --group stdlib --group examples)
if [[ "${1:-}" == library ]]; then
  groups=(--group library --library ${STOGIR_LIBRARY:-$HOME/Documents/Code/projects/coil-stogir})
fi
if [[ "${1:-}" == x64 ]]; then
  ssh -o BatchMode=yes ${X64_HOST:-computer.jimmyhmiller.com} "cd ~/csd-coil; export COIL_LIBRARY_STATE=0; sed \"s/'--backend', 'stogir'/'--backend', 'declarative'/g\" scripts/tests/stogir-x86-sweep.py > scripts/tests/declarative-sweep.py; rm -rf build/x64/sweep-logs; python3 scripts/tests/declarative-sweep.py build/x64/llvm/bin/coil $groups --levels 1,2 --jobs 16 --logs build/x64/sweep-logs 2>&1 | tail -30" | cut -c1-200
else
  cd "$tree"
  sed "s/'--backend', 'stogir'/'--backend', 'declarative'/g; s|parents\[2\]|parents[1]|" scripts/tests/stogir-x86-sweep.py > build/declarative-sweep.py
  COIL_LIBRARY_STATE=0 python3 build/declarative-sweep.py build/bin/coil-candidate $groups --levels 1,2 --jobs 6 --logs build/sweep-logs 2>&1 | tail -30 | cut -c1-200
fi
