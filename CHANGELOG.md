# Changelog

All notable source changes are recorded here. AxiomX follows semantic versioning within the `v1` release line.

## [1.0.1] — 2026-11-05

**Patch release: type safety, input validation and documentation.** No public functions were removed, renamed or reordered; binary packet layouts remain version 1.

### Fixed

- Align `RaySphereIntersection` with the fast intersection helper when a non-degenerate ray starts inside or on a sphere (`t = 0`).
- Reject nonfinite inputs for cone, view-cone, triangle-tolerance and fast ray/sphere queries before geometric calculations.
- Reject NaN or infinite trajectory steps before calling `table.create()` or dispatching physics work.
- Validate box query transforms/dimensions before calling Roblox overlap APIs.
- Reject zero-size shapecast overrides and nonfinite shapecast origins.
- Bound `MakeOverlapParams` maximum result count to a safe 32-bit signed integer range.

### Type and quality improvements

- Add explicit Roblox types to cached service/constants, `RaycastParams`, `OverlapParams`, and projectile sample arrays.
- Use `unknown` for untrusted packet input and refine it to `buffer` after a runtime type guard.
- Add Studio compile-time type contract tests and targeted patch regressions.
- Add offline source-parity audit for the 178 math/physics and 14 codec public functions, plus one-line assignment style.
- Rewrite README as a usage, safety, testing and benchmarking guide, with a generated exhaustive API signature reference.
- Preserve full-native, selective-native, bytecode and legacy `MathX` compatibility builds.

### Compatibility notes

- `AxiomX.Version` changes to `"1.0.1"`; `AxiomX.Codec.Version` stays at `1`.
- `RaySphereIntersection` starting inside a sphere now reports immediate intersection rather than exit; code relying on exit-only behavior should adjust.
- Roblox Studio typechecker, runtime physics suite and platform-specific allocation benchmarks still require running in Studio.

## [1.0.0] — 2026-11-05

- First public GitHub edition of AxiomX, renumbered from the pre-release internal 5.1.0 line.
- Retained the 178 public math/physics functions, 14 codec functions and fixed 9/14/15/30-byte binary profiles.
- Included optimized Luau builds, regression and codec tests, and a legacy MathX alias.