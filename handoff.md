# Handoff: the declarative backend is Stogir, 13 November 2026 (second)

The backend now stands in for the old Stogir. In Coil (worktree
`~/Documents/Code/projects/coil/.worktrees/declarative`, branch
`feature/declarative-backend`), `--backend stogir` and `--backend declarative`
both choose it; the vendored Stogir library and its adapter are deleted.
`docs/reference/STOGIR_BACKEND.md` there says what the backend is, its
settings and the assumptions its optimizer makes. Both repositories have local
commits only; nothing is pushed. History: pad `coil-stogir-declarative`, log 17.

## Verified on the final commits

| | AArch64 macOS | x86-64 Linux |
|---|---|---|
| `tools/check.sh` (rules, linking, single programs, fuzz with every transformation counted) | 2,000 programs | `tools/x64/remote.sh`: 2,000 |
| corpus through `stogir` and `declarative` | 9 of 9 | 9 of 9 |
| compiler built by the backend rebuilds itself to the same object | yes | yes |
| same, under `tools/coil-stress.sh` (150/6000/3000 and 400/20000/10000) | yes, corpus 9 of 9 | not run |
| Coil's sweep against LLVM, -O1 and -O2 | all agree (one timing test flaked under load, then passed 16 of 16) | all agree |
| old library's tests (`tools/coil-sweep.sh library`) | 865 agree, 0 wrong (3 x86-only tests do not link at -O1) | not run |
| `tools/coil-debugger.sh` (lldb against LLVM's -g build, 300 stops each) | 9 of 9 programs agree | gdb: not run |
| ThreadSanitizer build of the compiler emitting itself | no report; same object | not run |
| `cli.sh objects` | 48 of 48 | not run |
| run time against LLVM -O3 of the same compiler | 1.10x cycles, 1.14x instructions | 1.20x cycles, 1.59x instructions |

## What changed (and what each found)

- Pass counters are `tally` cells, which starting over keeps; before, all read
  zero. The fuzzer sums them and fails when one never fires.
- The generator links each program as an image: it calls itself and the C
  routines, makes switches of many cases or of every case, array loops (some
  left from the middle), word pairs, flags tested where ways meet, early
  returns. With either of today's bugs put back it fails in the first 2,000.
- Bugs fixed: `reduce` stepped addresses from a base made on a loop's middle
  exit (Coil's parser crashed under heavy inlining); `turn` left the old test's
  condition as a use of the counter, so `reduce` never fired; under -g the
  debugger stopped before the arguments were in their frame objects, tests
  fused with a branch had no line, and expanded copies and fills had no line.
- Coil bug filed (pad `coil-bugs`, `fnptr-of-cast-loses-c-byval`).

## Left to do

1. Performance. The hot loop the last handoff named (`set-contains`) is now
   stepped as addresses standalone; inlined into
   `closure-subprogram-scoped` it is about 11% behind LLVM's. Frame-object
   stores are now paired. Still open from before: copy elision across blocks
   (about 4,000 `memcpy` calls against LLVM's 700), x86-64 memory operands,
   jump tables and paired accesses there, and text 1.38x LLVM's.
2. The runs marked "not run" above on x86-64.
3. `-O1` keeps calls a constant test would remove (the 3 library tests that do
   not link): not wrong, but LLVM's -O1 folds them.

## Tools

    tools/check.sh 2000         tools/x64/remote.sh 2000 1
    tools/coil-cycle.sh         tools/x64/coil-cycle.sh
    tools/coil-stress.sh        tools/coil-debugger.sh
    tools/coil-sweep.sh [x64|library]
    FUZZ_OFF=bits FUZZ_WITHOUT=bits FUZZ_QUICK=1 out/fuzz 1 SEED
