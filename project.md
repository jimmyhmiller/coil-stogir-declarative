# coil-stogir-declarative

> **Moved into Coil (2026-11-15).** The backend's sources, its languages and its
> tests now live in the Coil repository: `src/declarative/` (sources and
> languages), `src/compiler/declarative/` (the runtime, the adapter, and the
> generated Coil, written by `scripts/compiler/gen-declarative.py`),
> `scripts/tests/declarative.py` (what `tools/check.sh` ran) and
> `scripts/declarative/` (the development tools). Edit them there; this
> repository is kept for its history.

## Summary

A compiler backend written language-first: everything that knows a node, a
register, an instruction or an algorithm of compilation is in small languages
under `src/`; `compiler/` holds only the implementations of those languages and
a generic runtime. The plan and status are in the `coil-stogir-declarative` pad.
