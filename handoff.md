# Handoff: the declarative backend, 13 November 2026

What is left before this can stand in for the existing Stogir. Ordered by how
much it bears on correctness. Matching the old backend test for test is not
a goal; being wrong is the only thing that blocks.

## Where things are

- Backend: `~/Documents/Code/projects/coil-stogir-declarative` (this repo).
- Coil side: worktree `~/Documents/Code/projects/coil/.worktrees/declarative`,
  branch `feature/declarative-backend`. `--backend declarative`.
  `src/compiler/declarative/` there is written by `tools/expand.sh`; never edit it by hand.
- Linux host: `computer.jimmyhmiller.com`, checkout under `~/csd-coil`.
- Both repositories have local commits only. Nothing is pushed.
- History and measurements: pad `coil-stogir-declarative`, cells `log-5` to `log-16`.

Verified on the final commits, on AArch64 macOS and x86-64 Linux alike: the
backend's own checks, Coil's corpus (9 of 9), the compiler built by the
backend rebuilding itself to the same object, the corpus through that
compiler, Coil's sweep against LLVM at -O1 and -O2, `-g` in lldb and gdb, and
the same object at 1 and 8 threads.

To re-verify after any change:

    tools/check.sh 2000            # rules, linking, single programs, fuzz
    tools/coil-cycle.sh            # candidate, corpus, self-reproduction, run time
    tools/coil-sweep.sh            # Coil's programs against LLVM
    tools/x64/remote.sh 500 1      # the backend's checks on the Linux host
    tools/x64/coil-cycle.sh        # the same cycle on x86-64
    tools/coil-sweep.sh x64

## 1. Correctness: what I am actually worried about

### 1.1 The fuzzer does not cover what was added this week (highest priority)

The differential fuzzer (interpreter against compiled code) was the main
safety net for the first version. Since then these went in, and none of them
was shown to be exercised by generated programs:

`loops.pass` (turning loops, hoisting loads, threading constant tags,
learning from branches, stepping addresses), `tails.pass`, `copies.pass`,
`selects.pass`, `switches.pass` (splitting, the exhaustive-switch rule), jump
tables, paired loads and stores, opening the frame late, and the allocator's
eviction changes.

They are covered by the corpus, self-reproduction and the sweep, which is
real coverage but coarse. Two concrete things to do:

1. **Count what fires.** Each pass keeps a counter (`turned`, `hoisted`,
   `parted`, `learned`, `reduced`, `looped`, `elided`, `chosen`, `halved`,
   `settled`, and `frame-at` for late frames). Have `tests/fuzz.coil` sum
   them over a run and print them. Any that stay at zero need a shape added
   to `tests/gen.coil`.
2. **Make the fuzzer catch the bug it missed.** Log 14 describes it: removing
   control that cannot run could delete live code. Revert the fix in
   `compiler/lang/rewrite.coil` (`kill-control!`, the "who uses it is noted
   before anything is changed" block) and extend the generator until a seed
   fails. I added one shape (`last-read!` in `gen.coil`) and 1,000 programs
   still passed, so that shape is not enough. The trigger needs a dead way
   whose last control node is a load or call, whose value is a phi input at
   the join, with a later input of that phi being another load or call.

### 1.2 Cheap stress runs that have already found a bug once

Larger inlining limits exposed the bug above when default settings passed
everything. Make this routine:

    DECLARATIVE_SMALL=150 DECLARATIVE_GROWTH=6000 DECLARATIVE_ONCE=3000

Build the compiler with these, then run the corpus and the self-reproduction
check through it. Only a ten-second smoke run was done with them after the fix.

### 1.3 Assumptions the optimizer now makes

Each is deliberate, but each is a place where a program could behave
differently from the LLVM build. Decide whether you accept them.

- **A switch whose default only traps is treated as naming every value**
  (`switches.pass`, `certain`). A corrupt tag is then undefined instead of a
  trap. LLVM does the same with `unreachable`. Switch 16 turns it off.
- **Stepping addresses compares pointers for equality** (`loops.pass`,
  `reduce`). Correct as long as `count * size` does not wrap 64 bits. Element
  sizes are capped at 4096. Switch 18.
- **C library routines are recognised by symbol name** (`known-routine` in
  `adapter/cir.coil`): `memcpy`, `memmove`, `memset`, `memcmp`, `bcmp`,
  `strlen`, `strcmp`, `strncmp`, `memchr`, with or without a leading
  underscore. A program that defines its own function under one of those
  names with other behaviour would be miscompiled.
- **Tail calls trust CIR's `frame-escapes`**, and inlining a callee whose
  frame escapes is refused once a function has a tail call. If that flag is
  ever wrong, a callee reads a dead frame.
- **Two different frame objects never overlap**, and a store to a frame
  object nothing else can reach cannot change memory reached another way
  (`forward.pass` `apart?`, `copies.pass` `may-write?`).

### 1.4 Threads were never run under a race detector

Functions compile on up to eight threads. Workers read the assembler's symbol
table and other functions' CIR (for inlining) and write only their own
buffers; the object is identical at 1 and 8 threads on both machines. That is
evidence, not proof. The old project built the compiler with
`--sanitize=thread` and self-emitted; do the same once with
`--backend declarative`.

### 1.5 Things with thin testing

- **`-g`** was checked on one small program in lldb and gdb (breakpoint by
  line, backtrace, locals), plus two corpus programs built and run. Nothing
  systematic. Under `-g` functions compile one at a time, frame objects stay
  in memory, and values that live only in registers have no location.
- **Opening the frame late** has a fallback: emission checks the plan and
  opens the frame at the start if the plan does not hold (`plan-holds?` in
  `emit.pass`). The check is what makes it safe; it is only exercised by
  whatever the corpus and the compiler itself contain.
- **x86-64 by-value stack arguments** are exercised by the corpus (`ffi_abi`)
  and the sweep, not by a test of their own.
- **`tools/x64/remote.sh` can run a stale binary** if a build on the host
  fails, as `tools/check.sh` did before it was fixed. Make it stop on a
  failed build the same way.

### 1.6 One optional run that is cheap and worth it

The old library's own tests compiled by this backend (the `library` group of
Coil's sweep, about a thousand small programs). Not for parity; it is simply
the largest body of small backend-shaped programs available, and it costs one
command:

    python3 build/declarative-sweep.py build/bin/coil-candidate --group library \
      --library ~/Documents/Code/projects/coil-stogir --levels 1,2 --jobs 6

(`tools/coil-sweep.sh` writes `build/declarative-sweep.py`; add the group there.)

## 2. Performance, if you want it closer to the old Stogir

Measured on the Coil compiler checking its own source, AArch64:

| | cycles | instructions | text | generation |
|---|---|---|---|---|
| LLVM -O3 | 50 G | 166 G | 6.85 MB | 9.8 s |
| existing Stogir -O3 | 53 to 54 G | 178 G | 8.0 MB | 4.7 s |
| declarative | 57 to 58 G | 199 G | 10.2 MB | 0.9 s |

x86-64: declarative is 1.18x LLVM's cycles and 1.48x its instructions; the
old Stogir was not measured there on the same commit.

`-O2` and `-O3` are the same thing here; `-O0` and `-O1` are selection and
allocation only.

In rough order of expected return:

1. The hottest loop (`closure-subprogram-scoped`) is not reached by address
   stepping: its base pointer is reloaded each outer round, and the loop that
   should match is not in the shape `reduce` expects. `tools/coil-runtime.sh
   profile` shows it. To see why `reduce` declines a loop, print at each of
   its early returns (it has no trace of its own).
2. Stores to frame objects are not paired (an inline copy into a local is one
   paired load and two single stores).
3. Copy elision only works within a block; about 4,000 `memcpy` call sites
   remain against LLVM's 700.
4. x86-64: no instructions with memory operands, no jump tables (`tables = 0`
   in `x64.isa`; selection stops hard if one is asked for), no paired
   accesses, and five preserved registers against an allocator tuned on ten.
5. Text size: LLVM inlines mid-sized functions at several sites and then
   cleans up. Raising `DECLARATIVE_SMALL` makes our text larger, not smaller,
   and does not run faster, so the cleanup after inlining is what is missing.

Cycles move about 3% from build to build even when instructions fall. Compare
with `tools/coil-runtime.sh` (least of four alternating runs), not one run.

## 3. Switching over

Only once section 1 is settled:

1. Point `--backend stogir` at this backend (`cli/build.coil`, `cli/units.coil`,
   `pipeline.coil`, and the `stogir` lanes in `scripts/oracle.py`), or keep
   both names for a while.
2. Remove `src/compiler/stogir/` and `backend/codegen_stogir.coil`. The
   declarative path still borrows three things from that file through
   `codegen_tpde.coil`: copy forwarding (`stogir-forward-copies!`), the
   reachability helper `stogir-live-job!`, and the thread count. Move them
   before deleting.
3. The Stogir-specific scripts under `scripts/tests/` test the old
   backend's internals. Keep the ones that state behaviour a user would
   notice (tail calls, volatile accesses, symbol addresses, shim calls) and
   drop the rest with the backend.

## 4. Not bugs of ours, noted for Coil

Seen while reading Coil's code, never reproduced, so not filed in
`coil-bugs`: TPDE's `MULO` at widths 33 to 63, and the success flag of
`cmpxchg` in the llvm-ir path.

## Tools for finding a miscompile

    tools/coil-bisect.sh 'COMMAND'          # which function (halves DECLARATIVE_TRIAL)
    DECLARATIVE_OFF=BITS DECLARATIVE_OFF_AT=N   # which transformation, in function N
    DECLARATIVE_SHOW=NAME                   # that function's graph before and after, and its code
    DECLARATIVE_SHOW='?'                    # every function's number
    DECLARATIVE_ONLY=N                      # only the first N functions optimized

The transformation numbers are listed in `src/backend/cfg.pass`. The command
given to `coil-bisect.sh` must succeed with the trial off and fail with it on;
when the failure is a crash, test the exit status exactly (a first attempt
this week treated a segfault as success).
