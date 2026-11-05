#!/usr/bin/env python3
"""Static AxiomX API/build-parity audit. Not a Luau or Roblox Studio compiler."""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "AxiomX.luau").read_text(encoding="utf-8")
SELECTIVE = (ROOT / "bench/AxiomXSelective.luau").read_text(encoding="utf-8")
BYTECODE = (ROOT / "bench/AxiomXBytecode.luau").read_text(encoding="utf-8")
MANIFEST = json.loads((ROOT / "tools/public_api_v1.json").read_text(encoding="utf-8"))
errors = []

def check(valid, message):
    if not valid:
        errors.append(message)

def names(source, qualifier):
    return re.findall(r"(?m)^function " + qualifier + r"\.([A-Za-z_0-9]+)\(", source)

check(MAIN.startswith("--!native\n--!optimize 2\n--!strict\n"), "Main compiler directives")
check(SELECTIVE.startswith("--!strict\n--!optimize 2\n"), "Selective compiler directives")
check(BYTECODE.startswith("--!strict\n--!optimize 2\n"), "Bytecode compiler directives")
check('AxiomX.Version = "1.0.1"' in MAIN, "AxiomX patch version")
check("Codec.Version = 1" in MAIN, "Codec wire protocol version")
for profile, n in [("Position", 9), ("Pose", 14), ("Motion", 15), ("Full", 30)]:
    check(f"Codec.{profile}Bytes = {n}" in MAIN, f"Codec {profile} size")
for label, source in [("full", MAIN), ("selective", SELECTIVE), ("bytecode", BYTECODE)]:
    check(names(source, "AxiomX") == MANIFEST["math_and_physics"], f"{label} math public API")
    check(names(source, "Codec") == MANIFEST["codec"], f"{label} codec public API")
    check(not re.search(r"(?m)^\s*local\b[^\n]*=\s*$", source), f"{label} multiline local assignments")
check(len(names(MAIN, "AxiomX")) == 178 and len(names(MAIN, "Codec")) == 14, "Expected public counts")
check(SELECTIVE.count("@native\nfunction ") == 27, "Selective native hint count")
check("--!native" not in SELECTIVE and "--!native" not in BYTECODE, "Bytecode/selective native directives")
expected = MAIN.replace("--!native\n--!optimize 2\n--!strict\n", "--!strict\n--!optimize 2\n")
actual_selective = SELECTIVE.replace('AxiomX.NativeMode = "selective"', 'AxiomX.NativeMode = "full"').replace("@native\n", "")
actual_bytecode = BYTECODE.replace('AxiomX.NativeMode = "bytecode"', 'AxiomX.NativeMode = "full"')
check(expected == actual_selective, "Selective build logic diverged")
check(expected == actual_bytecode, "Bytecode build logic diverged")
for line in MAIN.splitlines():
    if line.startswith("function AxiomX.") or line.startswith("function Codec."):
        check(":" in line.split("(", 1)[1], f"Missing typed signature: {line}")
if errors:
    for error in errors:
        print("FAIL:", error)
    sys.exit(1)
print("PASS: 178 engine functions, 14 codec methods, wire format, native parity and formatting")
print("Studio's Roblox-aware Script Analysis and physics tests remain necessary.")
