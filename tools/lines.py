#!/usr/bin/env python3
"""Lines of source by language, and of the language implementations.

Source is everything under src/. It must hold no .coil file: that is the split,
and this exits 1 if it is broken. Counts are lines that are neither blank nor
only a comment.
"""
import pathlib, sys

root = pathlib.Path(__file__).resolve().parent.parent

def count(path, comment):
    return sum(1 for line in path.read_text().splitlines()
               if line.strip() and not line.strip().startswith(comment))

by_language = {}
coil_in_src = []
for path in sorted((root / "src").rglob("*")):
    if path.is_file() and not path.name.startswith('.'):
        if path.suffix == ".coil":
            coil_in_src.append(path)
        by_language[path.suffix] = by_language.get(path.suffix, 0) + count(path, "#")

total = sum(by_language.values())
print("source (src/)")
for suffix, lines in sorted(by_language.items(), key=lambda item: -item[1]):
    print(f"  {suffix:10} {lines:6}")
print(f"  {'total':10} {total:6}")

implementation = sum(count(p, ";") for p in (root / "compiler").rglob("*.coil"))
print(f"language implementations and runtime (compiler/): {implementation}")

if coil_in_src:
    print("src/ holds Coil, which it must not:", *coil_in_src, sep="\n  ")
    sys.exit(1)
