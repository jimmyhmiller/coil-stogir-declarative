#!/usr/bin/env bash
# A Coil compiler for x86-64 Linux with this backend in it, linked on the Linux
# host: the backend is written out into the Coil worktree and a compiler built
# here (tools/coil-candidate.sh); that compiler's Linux IR is printed by an
# emitter linked against the host's LLVM (21) and compiled and linked there.
#   tools/x64/coil-host.sh      → $HOST:csd-coil/build/x64/llvm/bin/coil
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tree=${COIL_TREE:-$HOME/Documents/Code/projects/coil/.worktrees/declarative}
HOST=${X64_HOST:-computer.jimmyhmiller.com}
"$here/../coil-candidate.sh" 2>&1 | grep -E "^error" -A6 && exit 1
cd "$tree"
export LLVM_CONFIG=/opt/homebrew/opt/llvm@21/bin/llvm-config
read -r -a LINK <<<"$(scripts/compiler/llvm-link-flags.sh dynamic)"
mkdir -p build/x64
python3 scripts/compiler/stage0.py build/bin/coil-candidate build src/compiler/main.coil -o build/x64/coil-emitter "${LINK[@]}" > /dev/null
build/x64/coil-emitter emit-ir src/compiler/main.coil --target x86_64-unknown-linux-gnu > build/x64/coil-linux.ll
xz -3 -T0 -f -k build/x64/coil-linux.ll
rsync -a --delete --exclude .git --exclude '/build' --exclude .worktrees ./ $HOST:csd-coil/
ssh -o BatchMode=yes $HOST 'mkdir -p ~/csd-coil-ir'
rsync -a build/x64/coil-linux.ll.xz $HOST:csd-coil-ir/
ssh -o BatchMode=yes $HOST 'set -e; cd ~/csd-coil; mkdir -p build/bin build/x64; [ -e build/bin/native ] || ln -s ~/stogir-x86/coil-adapter/build/bin/native build/bin/native; xz -dc ~/csd-coil-ir/coil-linux.ll.xz > build/x64/coil-linux.ll; /usr/lib/llvm-21/bin/clang -O1 -c build/x64/coil-linux.ll -o build/x64/coil-linux.o 2>&1 | grep -v "overriding the module\|warning generated" || true; bash ~/stogir-x86/coil-adapter/docs/benchmarks/x86/tools/link-host-linux.sh . build/x64/coil-linux.o build/x64/llvm 2>&1 | tail -3'
