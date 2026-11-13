#!/usr/bin/env python3
"""Disassemble AArch64 instruction words printed one per line in hex (as `out/fuzz 1 SEED` prints)."""
import subprocess, sys, tempfile, os
words = [l for l in sys.stdin.read().split() if len(l) == 8 and all(c in "0123456789abcdef" for c in l)]
d = tempfile.mkdtemp()
src, obj = os.path.join(d, "code.s"), os.path.join(d, "code.o")
open(src, "w").write(".text\n_code:\n" + "".join(f"  .inst 0x{w}\n" for w in words))
subprocess.run(["clang", "-c", "-arch", "arm64", src, "-o", obj], check=True)
out = subprocess.run(["/opt/homebrew/opt/llvm/bin/llvm-objdump", "-d", "--no-show-raw-insn", obj],
                     capture_output=True, text=True).stdout
print("\n".join(out.splitlines()[5:]))
