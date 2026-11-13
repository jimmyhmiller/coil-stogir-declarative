#!/usr/bin/env python3
"""Make an expanded tree one package: tools/expand.sh DIRECTORY PACKAGE.

Every module of the tree is renamed PACKAGE.<name> (the adapter's modules
already are), in its own (module ...) form, in every import of it, and where
one is named in full. A Coil.toml says the directory is the package.
"""
import pathlib, re, sys

root, package = pathlib.Path(sys.argv[1]), sys.argv[2]
files = sorted(root.rglob("*.coil"))
names = []
for f in files:
    m = re.search(r"^\(module ([^\s)]+)\)", f.read_text(), re.M)
    if not m:
        sys.exit(f"expand-package: {f} declares no module")
    names.append(m.group(1))
renamed = {n: n if n.startswith(package + ".") else f"{package}.{n}" for n in names}
# Longest first, so a name that begins another is not mistaken for it.
order = sorted(renamed, key=len, reverse=True)
for f in files:
    text = f.read_text()
    for old in order:
        new = renamed[old]
        if old == new:
            continue
        q = re.escape(old)
        text = re.sub(rf"^\(module {q}\)", f"(module {new})", text, flags=re.M)
        text = re.sub(rf'\(import "{q}"', f'(import "{new}"', text)
        # A definition named in full: module.name, not inside a longer word.
        text = re.sub(rf"(?<![\w.\"/-]){q}\.(?=[\w])", new + ".", text)
    f.write_text(text)
(root / "Coil.toml").write_text(
    f"# Written by coil-stogir-declarative's tools/expand.sh: see NOTICE.\n"
    f"[package]\nname = \"{package}\"\nsource-roots = [\".\"]\n\n"
    f"[dependencies]\ntpde = {{ path = \"../tpde\" }}\n")
print(f"expand-package: {len(files)} modules named {package}.*")
