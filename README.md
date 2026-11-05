# AxiomX v1.0.0

**AxiomX** is a reusable, strict Luau math, geometry, physics-query, ballistics, and compact binary-packet library for Roblox. **v1.0.0 is the first GitHub release**, based on the previously developed v5.1.0 implementation. Its public functions and binary packet layouts have been kept intact; this is a release-number reset, **not a functional rewrite**.

## Highlights

- **178 math/physics functions** covering numeric utilities, Vector3 geometry, ray/sphere/block casts, hitboxes, collision and projectile calculations.
- Compact binary codec with fixed **9, 14, 15 and 30 byte** profiles. Size depends on the data model; do not assume a universal compression ratio. Quantized values can lose precision.
- **`--!native`, `--!optimize 2`, `--!strict`** on the main module. Alternative selective-native and bytecode builds for A/B/C benchmarks.
- Reusable `Into` output and codec buffers to reduce Lua allocations on hot paths. Roblox physics APIs may still allocate.
- Tests and P50/P95/P99 benchmarking scripts included, for Studio only.
- Compact assignment formatting: `local a = b`.

## Install

Create a **ModuleScript** named `AxiomX` in **ReplicatedStorage**, then paste `AxiomX.luau` into it. Use `MathX.compat.luau` as a second ModuleScript called `MathX` only if supporting legacy code.

```luau
--!strict
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AxiomX = require(ReplicatedStorage:WaitForChild("AxiomX"))
local Origin = Vector3.new(0, 20, 0)
local Direction = Vector3.new(0, -1, 0)
local Hit = AxiomX.GetImpactData(Origin, Direction, 100)
if Hit then
    print(Hit.Angle, Hit.Reflection, Hit.Instance)
end
```

## Low-allocation packet codec

```luau
--!strict
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AxiomX = require(ReplicatedStorage:WaitForChild("AxiomX"))
local Codec = AxiomX.Codec
local Packet = Codec.NewBuffer(Codec.FullProfile) :: buffer
local State = Codec.NewFullSnapshot()
local Decoded = Codec.NewFullSnapshot()
State.Position = Vector3.new(10, 25, 50)
State.Velocity = Vector3.new(10, 0, -5)
State.EntityId = 25
State.Health = 100
if Codec.WriteFullInto(Packet, State) and Codec.ReadFullInto(Packet, Decoded) then
    print("Bytes:", buffer.len(Packet), "Position:", Decoded.Position)
end
```

Preallocate per owner/worker and **do not share a mutable result buffer across concurrent calls**. The codec's `Version` remains **1** so existing packet format assumptions are unchanged. All codec ranges and precision limits still apply.

## Repository contents

| Path | Purpose |
|---|---|
| `AxiomX.luau` | Main full-native production ModuleScript |
| `MathX.compat.luau` | Optional alias for older MathX imports |
| `bench/AxiomXSelective.luau` | Selective native build for A/B comparison |
| `bench/AxiomXBytecode.luau` | Optimized bytecode build without native hints |
| `tests/AxiomXRegression.server.luau` | Math and physics regression checks |
| `tests/AxiomXCodecTest.server.luau` | Codec encoding/decoding checks |
| `tests/AxiomXNativeSmoke.server.luau` | Native/selective/bytecode parity checks |
| `tests/AxiomXNativeBenchmark.server.luau` | Avg / P50 / P95 / P99 timing harness |
| `examples/AxiomXUsage.server.luau` | Basic examples |

## Run tests and benchmarks

Create ModuleScripts under `ReplicatedStorage`: `AxiomX`, `AxiomXSelective`, `AxiomXBytecode` (using their corresponding files). Copy scripts from `tests/` into `ServerScriptService` **for Studio testing only**. Read the `RUN_BENCHMARK` / `RUN_HEAP_PROBE` switches in the benchmark and enable them intentionally. `P95`/`P99` are timing percentiles for *batched* calls, not network-latency promises.

**Performance note:** Native compilation is advisory, platform-dependent, and can increase startup time and code memory. `--!native` does not guarantee faster execution. Zero lag and zero allocations cannot be guaranteed with Roblox's physics/query APIs. Benchmark each deployment target and profile memory before choosing the production variant.

## Compatibility

- **Code compatibility:** Existing MathX/AxiomX public function names retained from the previous build; verify any code relying on `AxiomX.Version` as it is now `"1.0.0"`.
- **Binary compatibility:** Codec profile layouts and codec format version were not altered by this release-number reset.
- **Validation:** Static checks and offline codec verification are available, but Roblox Studio native execution, regression suite and memory/latency measurements must be run before treating the release as production-verified.

## References

- [Roblox Creator Hub — Native code generation](https://create.roblox.com/docs/luau/native-code-gen)
- [Roblox Creator Hub — Performance](https://create.roblox.com/docs/performance-optimization/improve)
