#!/usr/bin/env python3
"""Regenerate docs/API.md from AxiomX.luau; public names live in tools/public_api_v1.json."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
lines = (root / "AxiomX.luau").read_text(encoding="utf-8").splitlines()
functions = [line for line in lines if re.match(r"^function (AxiomX|Codec)\.", line)]
assert len(functions) == 192
codec = [line for line in functions if line.startswith("function Codec.")]
main = [line for line in functions if line.startswith("function AxiomX.")]
output = """# AxiomX — Public API reference

This file is generated from the strict-typed function definitions in [AxiomX.luau](../AxiomX.luau). See [README.md](../README.md) for usage, limits, typechecking, and tests.

## Math, geometry, physics, and ballistics (178 functions)

```luau
"""
output += "\n".join(main) + "\n```\n\n## Binary codec (14 methods)\n\n```luau\n"
output += "\n".join(codec) + "\n```\n"
(root / "docs/API.md").write_text(output, encoding="utf-8")
print("Generated", len(main), "math/physics methods and", len(codec), "codec methods")
