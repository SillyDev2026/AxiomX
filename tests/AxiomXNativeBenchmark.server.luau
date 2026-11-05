--!strict
--!optimize 2

local RunService = game:GetService("RunService")
local RUN_BENCHMARK = false
local RUN_HEAP_PROBE = false
if not RunService:IsStudio() or not RUN_BENCHMARK then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FullScript = ReplicatedStorage:FindFirstChild("AxiomX")
local SelectiveScript = ReplicatedStorage:FindFirstChild("AxiomXSelective")
local BytecodeScript = ReplicatedStorage:FindFirstChild("AxiomXBytecode")
if not FullScript or not FullScript:IsA("ModuleScript") or not SelectiveScript or not SelectiveScript:IsA("ModuleScript") or not BytecodeScript or not BytecodeScript:IsA("ModuleScript") then
	warn("[AxiomX Bench] Install AxiomX, AxiomXSelective, and AxiomXBytecode in ReplicatedStorage.")
	return
end

local Full = require(FullScript :: ModuleScript)
local Selective = require(SelectiveScript :: ModuleScript)
local Bytecode = require(BytecodeScript :: ModuleScript)
local SAMPLES = 160
local WARMUP = 20
local MATH_ITERATIONS = 2500
local CODEC_ITERATIONS = 500
local Sink = 0
local A = Vector3.new(23.54, -5, 142.75)
local B = Vector3.new(-10.95, 37.4, 77.15)
local C = Vector3.new(5, 0, -8)
local D = Vector3.new(3, 0, 6)
local Half = Vector3.new(8, 8, 8)
local Collider = Vector3.new(33, -5, 155)

type Profile = {Average: number, P50: number, P95: number, P99: number}
local function profile(Name: string, Iterations: number, Kernel: (number) -> number): Profile
	local Times: {number} = table.create(SAMPLES)
	for _ = 1, WARMUP do Sink += Kernel(Iterations) end
	for Sample = 1, SAMPLES do
		local Started = os.clock()
		Sink += Kernel(Iterations)
		Times[Sample] = (os.clock() - Started) * 1e6 / Iterations
	end
	table.sort(Times)
	local Total = 0
	for Index = 1, SAMPLES do Total += Times[Index] end
	local Stats: Profile = {Average = Total / SAMPLES, P50 = Times[math.ceil(SAMPLES * 0.5)], P95 = Times[math.ceil(SAMPLES * 0.95)], P99 = Times[math.ceil(SAMPLES * 0.99)]}
	print(string.format("[AxiomX Native] %-27s avg %.4f us/op | p50 %.4f | p95 %.4f | p99 %.4f", Name, Stats.Average, Stats.P50, Stats.P95, Stats.P99))
	return Stats
end

local function compare(Name: string, Inner: number, FullKernel: (number) -> number, SelectiveKernel: (number) -> number, BytecodeKernel: (number) -> number)
	local NativeStats = profile(Name .. " / full", Inner, FullKernel)
	local SelectiveStats = profile(Name .. " / selective", Inner, SelectiveKernel)
	local BytecodeStats = profile(Name .. " / bytecode", Inner, BytecodeKernel)
	if NativeStats.Average > 0 and SelectiveStats.Average > 0 then
		print(string.format("[AxiomX Native] %s: full %.2fx, selective %.2fx versus bytecode (higher is faster)", Name, BytecodeStats.Average / NativeStats.Average, BytecodeStats.Average / SelectiveStats.Average))
	end
end

compare("FastDistanceSquared", MATH_ITERATIONS,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += Full.FastDistanceSquared(A, B) end
		return Sum
	end,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += Selective.FastDistanceSquared(A, B) end
		return Sum
	end,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += Bytecode.FastDistanceSquared(A, B) end
		return Sum
	end)

compare("FastRaySphereTime", MATH_ITERATIONS,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += (Full.FastRaySphereTime(A, D, Collider, 20) or 0) end
		return Sum
	end,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += (Selective.FastRaySphereTime(A, D, Collider, 20) or 0) end
		return Sum
	end,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += (Bytecode.FastRaySphereTime(A, D, Collider, 20) or 0) end
		return Sum
	end)

compare("FastRayAABBTime", MATH_ITERATIONS,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += (Full.FastRayAABBTime(A, D, Collider, Half) or 0) end
		return Sum
	end,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += (Selective.FastRayAABBTime(A, D, Collider, Half) or 0) end
		return Sum
	end,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += (Bytecode.FastRayAABBTime(A, D, Collider, Half) or 0) end
		return Sum
	end)

compare("SegmentDistanceSquared", MATH_ITERATIONS,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += Full.FastPointSegmentDistanceSquared(A, B, C) end
		return Sum
	end,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += Selective.FastPointSegmentDistanceSquared(A, B, C) end
		return Sum
	end,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += Bytecode.FastPointSegmentDistanceSquared(A, B, C) end
		return Sum
	end)

compare("FastProjectilePosition", MATH_ITERATIONS,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += Full.FastProjectilePosition(A, D, C, 0.25).Y end
		return Sum
	end,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += Selective.FastProjectilePosition(A, D, C, 0.25).Y end
		return Sum
	end,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do Sum += Bytecode.FastProjectilePosition(A, D, C, 0.25).Y end
		return Sum
	end)

local FullCodec = Full.Codec
local SelectiveCodec = Selective.Codec
local BytecodeCodec = Bytecode.Codec
local FullPacket = FullCodec.NewBuffer(FullCodec.FullProfile) :: buffer
local SelectivePacket = SelectiveCodec.NewBuffer(SelectiveCodec.FullProfile) :: buffer
local BytecodePacket = BytecodeCodec.NewBuffer(BytecodeCodec.FullProfile) :: buffer
local State = FullCodec.NewFullSnapshot()
local FullDecoded = FullCodec.NewFullSnapshot()
local SelectiveDecoded = SelectiveCodec.NewFullSnapshot()
local BytecodeDecoded = BytecodeCodec.NewFullSnapshot()
State.Position = Vector3.new(120.25, 25.5, -89.5)
State.Velocity = Vector3.new(5, 2.5, -12.5)
State.Yaw = 180
State.Pitch = -30
State.Roll = 1
State.TickMs = 100
State.EntityId = 42
State.Health = 100
State.Sequence = 2
State.Flags = 1
State.Metadata = 0
assert(FullCodec.WriteFullInto(FullPacket, State))
assert(SelectiveCodec.WriteFullInto(SelectivePacket, State))
assert(BytecodeCodec.WriteFullInto(BytecodePacket, State))

compare("Codec.WriteFullInto", CODEC_ITERATIONS,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do if FullCodec.WriteFullInto(FullPacket, State) then Sum += 1 end end
		return Sum
	end,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do if SelectiveCodec.WriteFullInto(SelectivePacket, State) then Sum += 1 end end
		return Sum
	end,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do if BytecodeCodec.WriteFullInto(BytecodePacket, State) then Sum += 1 end end
		return Sum
	end)

compare("Codec.ReadFullInto", CODEC_ITERATIONS,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do if FullCodec.ReadFullInto(FullPacket, FullDecoded) then Sum += FullDecoded.Health end end
		return Sum
	end,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do if SelectiveCodec.ReadFullInto(SelectivePacket, SelectiveDecoded) then Sum += SelectiveDecoded.Health end end
		return Sum
	end,
	function(Count: number): number
		local Sum = 0
		for Index = 1, Count do if BytecodeCodec.ReadFullInto(BytecodePacket, BytecodeDecoded) then Sum += BytecodeDecoded.Health end end
		return Sum
	end)

if RUN_HEAP_PROBE then
	local Before = gcinfo()
	for Index = 1, 100000 do Sink += Full.FastDistanceSquared(A, B) end
	local After = gcinfo()
	print(string.format("[AxiomX Native] Lua heap delta after 100k numeric calls: %.3f KB (not allocation proof)", After - Before))
end

print("[AxiomX Native] Finished; sink", Sink)
print("[AxiomX Native] p50/p95/p99 describe amortized per-operation BATCH timings, not isolated call tail latency.")
print("[AxiomX Native] To inspect native execution: Script Profiler should display <native>. In Server Command Bar run debug.dumpcodesize().")
