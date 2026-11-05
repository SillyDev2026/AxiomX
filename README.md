<div align="center">

# AxiomX

**Strictly typed math, geometry, physics queries, ballistics, and compact binary snapshots for Roblox Luau.**

**Version 1.0.1** · v1 stable API line · Roblox Studio · Luau

[Quick start](#quick-start) · [API reference](docs/API.md) · [Typechecking](#typechecking-in-studio) · [Binary codec](#binary-codec) · [Testing](#testing-and-benchmarks) · [Changelog](CHANGELOG.md)

</div>

AxiomX is an all-in-one library for gameplay calculations and spatial queries. It supports zero-*new-Lua-table* hot paths where practical, plus safer wrappers around Roblox's `WorldRoot` physics APIs. It does **not** replace the physics engine, guarantee zero allocations, or promise zero frame-time overhead.

> **Version policy:** v1.0.1 is a backward-compatible patch of the first public GitHub version (v1.0.0). The earlier internal development version was 5.1.0. This patch retains all **178 public math/physics functions**, all **14 codec functions**, and the existing packet wire format (codec version `1`).

## Capabilities

| Area | Included |
| --- | --- |
| Scalars & interpolation | Clamping, easing, lerp, Hermite, Bezier, smooth damping, angles |
| Vectors & transforms | Distance, projections, reflection, refraction, normalization, CFrame alignment |
| Geometry | AABB, sphere, capsule, cone, triangles, ray/segment intersections |
| Roblox physics | Raycasts, spherecasts, blockcasts, shapecasts, overlap queries, ground/LOS helpers |
| Ballistics | Projectile path sampling, hit prediction, arcs, collision traces, drag |
| Low-allocation interfaces | Caller-owned `ImpactBuffer`, `ProjectileBuffer`, reusable `buffer` snapshots |
| Binary codec | Position / pose / motion / full state packets, fixed bit layouts |
| Developer tools | Strict-type contract sample, regression tests, native comparison, p50/p95/p99 benchmarks |

## Quick start

1. In **Roblox Studio**, create `ReplicatedStorage/AxiomX` as a **ModuleScript**.
2. Copy the contents of [AxiomX.luau](AxiomX.luau) into that ModuleScript.
3. Put any example Script under `ServerScriptService`, or require `AxiomX` from your game code.
4. To preserve an older `require(...MathX)` path, create `ReplicatedStorage/MathX` and paste [MathX.compat.luau](MathX.compat.luau) into it.

```luau
--!strict
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AxiomX = require(ReplicatedStorage:WaitForChild("AxiomX"))
local Origin = Vector3.new(0, 20, 0)
local Direction = -Vector3.yAxis
local Params = AxiomX.MakeRaycastParams()
local Hit = AxiomX.GetImpactData(Origin, Direction, 100, Params)

if Hit then
    print("Angle", Hit.Angle, "Part", Hit.Instance, "Distance", Hit.Distance)
end
```

Keep hot-loop parameters and result buffers outside the loop; don't construct them repeatedly.

## Strict types and reusable results

All existing public math/physics function signatures declare parameter types and return types. AxiomX also exports data types for static checking:

| Exported type | Meaning |
| --- | --- |
| `AxiomX.ImpactData` | Non-optional impact fields returned on a hit |
| `AxiomX.ImpactBuffer` | Caller-owned impact output with optional fields until populated |
| `AxiomX.ProjectileHit` | Projectile raycast collision information |
| `AxiomX.ProjectileBuffer` | Caller-owned projectile trace output |
| `AxiomX.FullSnapshot` | Full state codec schema |
| `AxiomX.PoseSnapshot` | Position + three Euler angles |
| `AxiomX.MotionSnapshot` | Position + velocity |

```luau
--!strict
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AxiomX = require(ReplicatedStorage.AxiomX)
type ImpactBuffer = AxiomX.ImpactBuffer

local Params: RaycastParams = AxiomX.MakeRaycastParams()
local Impact: ImpactBuffer = AxiomX.MakeImpactBuffer()
local Origin = Vector3.new(0, 25, 0)

if AxiomX.GetImpactDataInto(Origin, -Vector3.yAxis, 80, Params, Impact) then
    print(Impact.Distance, Impact.Normal)
end
```

Unlike `GetImpactData()`, `GetImpactDataInto()` does not create a new **Lua result table**. It reuses `Impact`. It can still receive an engine-created `RaycastResult`. Results must not be shared across concurrent callers or parallel workers.

## Binary codec

`AxiomX.Codec` serializes four **specific gameplay schemas** into fixed-size buffers. These are *lossy/quantized* formats, not general-purpose compression of arbitrary data.

| Profile constant | Bytes | Encoded fields |
| --- | ---: | --- |
| `Codec.PositionProfile` | 9 | Position XYZ |
| `Codec.PoseProfile` | 14 | Position XYZ and yaw/pitch/roll |
| `Codec.MotionProfile` | 15 | Position XYZ and velocity XYZ |
| `Codec.FullProfile` | 30 | Position, velocity, rotation, tick, entity ID, flags, health, sequence, metadata |

- **Position:** signed 21-bit per axis at 0.01-stud resolution, approximately -10,485.76 to +10,485.75 studs.
- **Velocity:** signed 14-bit per axis at 0.02-stud/second resolution, approximately -163.84 to +163.82 studs/second.
- **Angles:** one 12-bit and two 11-bit unsigned circular encodings; quantization steps are about 0.088° and 0.176°, respectively.
- **Full-state other fields:** tick 24 bits, entity ID 20, flags 12, health 10, sequence 16, metadata 8.
- **Header:** first byte identifies profile with protocol/version 1. Reserved padding is validated by decoders. This is **not** encryption, authentication, or a checksum.

```luau
--!strict
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AxiomX = require(ReplicatedStorage:WaitForChild("AxiomX"))
local Codec = AxiomX.Codec
local Packet = Codec.NewBuffer(Codec.FullProfile) :: buffer
local State = Codec.NewFullSnapshot()
local Received = Codec.NewFullSnapshot()

State.Position = Vector3.new(15.25, 3, -8.5)
State.Velocity = Vector3.new(4, 0, -2)
State.EntityId = 25
State.Health = 100

if Codec.WriteFullInto(Packet, State) and Codec.ReadFullInto(Packet, Received) then
    print("Payload:", buffer.len(Packet), "bytes")
    print("Decoded:", Received.Position, Received.Health)
end
```

`Write*Into` rejects nonfinite, out-of-range or unrepresentable values rather than truncating silently. Validate incoming payloads at the trust boundary; never treat decoded state as authoritative for health, position or inventory merely because it came through a buffer. **Actual Roblox network bandwidth and DataStore costs must be measured separately**: buffer sizes are not a billing guarantee.

## Typechecking in Studio

AxiomX uses `--!strict` and explicit Luau types. Roblox Studio's **Script Analysis** window is the authoritative Roblox-aware type checker: unlike a standalone Luau CLI, it knows `Workspace`, `RaycastParams`, `buffer`, and Roblox engine types.

1. Install `ReplicatedStorage/AxiomX` first.
2. Add [tests/AxiomXTypeContracts.server.luau](tests/AxiomXTypeContracts.server.luau) as a Script under `ServerScriptService`.
3. Open **View → Script Analysis**, set your scripts to strict type checking, and resolve any warnings/errors before release.
4. Run the test scripts in Studio. Tests are guarded by `RunService:IsStudio()` to avoid running in live servers.

`AxiomXTypeContracts.server.luau` deliberately uses `AxiomX.ImpactBuffer`, `AxiomX.FullSnapshot`, and other exported types as **compile-time contracts**. If Studio highlights unresolved module types, check the ModuleScript name and direct `require(ReplicatedStorage.AxiomX)` path before editing the types.

**Verification limitation:** Source audit and offline checks can run here. Roblox Studio itself is not available in this environment, so Roblox-aware typechecking, physics tests and native profiling still need to be performed in Studio.

## Native performance and benchmarking

The release includes three **functionally equivalent** builds for measurement:

| Source file | Compilation strategy |
| --- | --- |
| [`AxiomX.luau`](AxiomX.luau) | `--!native`, `--!optimize 2`, `--!strict` |
| [`bench/AxiomXSelective.luau`](bench/AxiomXSelective.luau) | `@native` on selected functions and `--!optimize 2` |
| [`bench/AxiomXBytecode.luau`](bench/AxiomXBytecode.luau) | Optimized bytecode without native directives |

For comparative benchmarking, name ModuleScripts `AxiomX`, `AxiomXSelective`, and `AxiomXBytecode` under `ReplicatedStorage`. Run `tests/AxiomXNativeBenchmark.server.luau` in Studio after enabling its opt-in switches. Metrics include avg, p50, p95, and p99 timings for batches. Use `tests/AxiomXNativeSmoke.server.luau` to compare results across builds.

**Performance constraints:** engine raycast/overlap queries can allocate, `Vector3`/`CFrame` operations may have engine-managed costs, and native compilation can increase code memory/startup. Do not interpret a small heap delta as proof of zero allocations. Benchmark native vs bytecode on the target platform before choosing.

## Testing

| File | Purpose |
| --- | --- |
| [`tests/AxiomXRegression.server.luau`](tests/AxiomXRegression.server.luau) | Baseline math and engine query regression suite |
| [`tests/AxiomXCodecTest.server.luau`](tests/AxiomXCodecTest.server.luau) | Snapshot validation, golden packet, codec roundtrips |
| [`tests/AxiomXPatch.server.luau`](tests/AxiomXPatch.server.luau) | New v1.0.1 cases: nonfinite input, inside-sphere ray, degenerate queries |
| [`tests/AxiomXTypeContracts.server.luau`](tests/AxiomXTypeContracts.server.luau) | Compile-time Studio type contracts and lightweight smoke checks |
| [`tests/AxiomXNativeSmoke.server.luau`](tests/AxiomXNativeSmoke.server.luau) | Full-native/selective/bytecode result parity |
| [`tests/AxiomXNativeBenchmark.server.luau`](tests/AxiomXNativeBenchmark.server.luau) | Timing distribution and opt-in memory probe |
| [`tools/audit.py`](tools/audit.py) | Python source parity, type annotations, formatting and public API audit (not a Luau compiler) |

Run the offline audit from the repository root with `python tools/audit.py`. For full verification, run the Studio tests, inspect Script Analysis and benchmark on actual devices. Avoid shipping test Scripts to a production experience.

## Compatibility & semantics

- All **178** original AxiomX math/physics function names and **14** codec function names are retained. Existing calls and argument order are preserved.
- Protocol **`Codec.Version == 1`** and all four packet layouts remain unchanged. `AxiomX.Version` is `"1.0.1"`.
- `RaySphereIntersection` now returns the ray origin and `t = 0` when starting inside/on the sphere, consistent with `FastRaySphereTime`. Rays with zero direction still return `nil`.
- Query wrapper distances differ: `CastRay`/`CastSphere`/`CastBlock` accept *unit direction + distance*; `Raycast` and `Cast*Displacement` accept raw displacement vectors. **Do not normalize a displacement twice.**
- `MaxRayDistance`, `MaxSweepDistance`, geometry limits, and codec ranges reject unsupported values; query limits are intentionally conservative.
- Geometry uses **studs**, time in **seconds**, angle methods in **degrees** unless explicitly documented otherwise.

## Full API reference

See **[docs/API.md](docs/API.md)** for signatures of every public function and codec method. The README is the integration guide; the API reference is the exhaustive index.

## License and contributions

No license was supplied for this repository; ownership and permissions therefore remain governed by applicable copyright law. Add a LICENSE file only after choosing your intended distribution terms. Contributions should retain strict Luau typing, stable API signatures, deterministic tests, and compact one-line assignments (`local a = b`).

## Official references

- [Roblox Creator Hub — Type checking](https://create.roblox.com/docs/luau/type-checking)
- [Roblox Creator Hub — RaycastParams](https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams)
- [Roblox Creator Hub — Luau directives](https://create.roblox.com/docs/luau/comments)
- [Roblox Creator Hub — Native code generation](https://create.roblox.com/docs/luau/native-code-gen)