# Changelog

## v1.0.0 — Initial GitHub release (2026-11-05)

- Established AxiomX v1.0.0 numbering without removing the prior 5.1.0 implementation's 178 math/physics public functions.
- Preserved compact codec and its existing 9/14/15/30-byte layouts; codec wire-format version remains 1.
- Preserved `--!native`, `--!optimize 2`, `--!strict`, selective-native and bytecode benchmark variants.
- Updated version assertions in the regression, codec, and native smoke tests.
- Maintained optional `MathX` compatibility alias and reusable `Into` interfaces.

This release is a **version reset**, not a claim that Roblox Studio tests or native benchmarks passed.
