# A declarative native backend

We’re building a native code generator to compete with LLVM on compile time and the speed of the code it produces. Coil is its first compiler integration. It feeds the backend Coil IR (CIR), and the backend takes it from there through optimization, instruction selection, register allocation, and machine-code emission. It’s early days, but the lowest optimization level already has a clear advantage in code-generation time.

## How it compares with LLVM

**At `-O0`, the native backend generates code for the Coil compiler about 8× as fast as LLVM on AArch64 and 10× as fast on x86-64.** With debug info, the speedup rises to about 14× and 16×.

| Platform | Settings | Native | LLVM | Speedup |
| --- | --- | ---: | ---: | ---: |
| AArch64 macOS | `-O0` | 0.47 s | 3.84 s | 8.2× |
| AArch64 macOS | `-O0 -g` | 0.50 s | 7.06 s | 14.1× |
| x86-64 Linux | `-O0` | 0.74 s | 7.17 s | 9.7× |
| x86-64 Linux | `-O0 -g` | 0.88 s | 14.4 s | 16.4× |

Coil’s internal timers measured the code-generation phase on November 15, 2026.

**Generated code at `-O0` trades wins with LLVM.** Across eight workloads that ran under both backends, geometric-mean runtime was essentially tied on macOS and about 15% longer with the native backend on Linux. The native-built compiler itself checked its own source in 65.1 s versus LLVM’s 73.0 s on macOS and 55.8 s versus 58.7 s on Linux. The native backend’s compiler executable had 23% less text on macOS and 13% less on Linux at `-O0`. One slice benchmark crashed in the LLVM `-O0` builds on both hosts and was excluded from the runtime aggregate.

**The optimizing path has a bigger code-quality gap.** In a separate November 13 checkpoint, the graph backend’s measured generation phase took about 0.9 s versus 9.8 s for LLVM on macOS and 0.8 s versus 10.8 s on Linux. In the [final comparison from that checkpoint](handoff.md), the optimized native-built compiler used 10% more CPU cycles on AArch64 and 20% more on x86-64 than the LLVM `-O3` build when checking its own source. That’s one workload. Optimization coverage is still narrower than LLVM’s, with room to improve copy elimination, x86-64 addressing and instruction selection, and code size.

## How it’s built

The backend describes its internals in small domain-specific languages (DSLs). The files in [`src/`](src/) define the IR, optimization rules, pass algorithms, calling conventions, and instruction encodings. Coil readers in [`compiler/lang/`](compiler/lang/) turn those descriptions into Coil modules, and [`compiler/rt/`](compiler/rt/) provides the runtime they use.

Development has moved to the [Coil repository](https://github.com/jimmyhmiller/coil). This checkout preserves the standalone project. The maintained backend lives in [`src/declarative/`](https://github.com/jimmyhmiller/coil/tree/main/src/declarative) and runs as `--backend native`. See Coil’s [native backend reference](https://github.com/jimmyhmiller/coil/blob/main/docs/reference/NATIVE_BACKEND.md) for current usage and integration details.

## What it supports

| Target | Calling convention | Object format |
| --- | --- | --- |
| AArch64 macOS | AAPCS64 with Apple platform conventions | Mach-O |
| x86-64 Linux | System V AMD64 | ELF |

- **`-O0` and `-O1` compile directly from CIR.** The backend walks each function, matches CIR operations against instruction-selection rules, and assigns registers as it emits code.
- **`-O2` and `-O3` use an optimizing graph pipeline.** The backend translates CIR into a graph, simplifies it with rewrites and inferred facts, and runs passes such as memory forwarding and loop transforms. It then schedules the graph, selects instructions, allocates registers, and lays out stack frames.
- **Both targets support object emission and in-memory execution.** The backend handles C calling conventions, including variadic calls and aggregate arguments and results. In Coil, the native backend also provides code generation for metaprograms, JIT sessions, and the REPL, and can emit DWARF debug information.

## The DSLs

| File | What you describe |
| --- | --- |
| [`.ir`](src/backend/nodes.ir) | Graph node types, operands, results, and semantics. The node definitions give the optimizer and rule tests a shared definition of what an operation means. |
| [`.ops`](src/cir/cir.ops) | The linear CIR instruction set, including opcode numbers, operands, immediates, and operation semantics. The same descriptions feed instruction selection and the reference interpreter. |
| [`.rewrite`](src/backend/simplify.rewrite) | Graph patterns and their replacements, with guards for rules that only apply under certain conditions. |
| [`.flow`](src/backend/facts.flow) | Facts about values and how to derive them from inputs. Rewrite guards can use facts such as a value’s upper bound on bit width. |
| [`.pass`](src/backend/alloc.pass) | Compiler algorithms that work over entities such as nodes and blocks. A pass declares typed columns for its data, while the language implementation handles the columns’ storage. |
| [`.isa`](src/a64/a64.isa) | Registers, register classes, instruction operands, and the bits or bytes that encode each instruction. |
| [`.abi`](src/a64/a64.abi) | Calling convention details such as argument and result registers, stack placement, and frame conventions. |
| [`.lower`](src/a64/a64.lower) | Rules that match graph nodes and emit target instructions, plus reusable instruction templates. |
| [`.select`](src/a64-direct/a64.select) | Rules that select instructions directly from CIR during the `-O0` and `-O1` walk. |
| [`.layout`](src/a64/macho.layout) | The ordered blocks and fields that make up an object file, including headers and relocation records. |
| [`.unit`](src/a64/a64.unit) | The set of schemas, target descriptions, rules, and passes that make up a compiler. |
| [`.pipeline`](src/backend/plans.pipeline) | Named plans that order the passes. A plan can repeat a group of steps until it stops changing the graph. |

The [calculator in `src/toy/`](src/toy/) is a small example you can read end to end. Its rewrite file contains this rule:

```text
rule times-two : TIMES(x, LIT 2) => PLUS(x, x)
```

The calculator defines those nodes in its own `.ir` file and uses a `.flow` file to infer how many low bits may be set. Its pipeline simplifies expressions, solves those facts, then runs more rewrites using the results. It uses the same readers as the native backend.

## Tests

The suite checks rewrite rules and facts against node semantics, links objects in memory and through the system linker, and exercises calling conventions. It also compares randomly generated programs with reference evaluators for both the direct CIR and optimizing graph paths.

From a checkout of Coil, run the maintained suite on AArch64 macOS or x86-64 Linux with a compiler built from that checkout:

```sh
python3 scripts/tests/declarative.py /path/to/coil
```
