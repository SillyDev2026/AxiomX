--!strict
--!optimize 2

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Names = {"AxiomX", "AxiomXSelective", "AxiomXBytecode"}
local Modules: {any} = {}
for Index, Name in Names do
	local Source = ReplicatedStorage:FindFirstChild(Name)
	if not Source or not Source:IsA("ModuleScript") then warn("[AxiomX Native Test] Missing module:", Name); return end
	Modules[Index] = require(Source :: ModuleScript)
end

local Randomizer = Random.new(20261105)
local Checks = 0
local function check(Valid: boolean, Message: string)
	Checks += 1
	assert(Valid, "[AxiomX Native Test] " .. Message)
end

local Native = Modules[1]
local Selective = Modules[2]
local Bytecode = Modules[3]
check(Native.NativeMode == "full" and Selective.NativeMode == "selective" and Bytecode.NativeMode == "bytecode", "native modes")
check(Native.Version == "1.0.0" and Selective.Version == Native.Version and Bytecode.Version == Native.Version, "module version")

local function near(A: number, B: number, Epsilon: number): boolean
	return math.abs(A - B) <= Epsilon
end

local Base = Vector3.new(2, 3, 4)
for Case = 1, 2000 do
	local A = Vector3.new(Randomizer:NextNumber(-200, 200), Randomizer:NextNumber(-200, 200), Randomizer:NextNumber(-200, 200))
	local B = Vector3.new(Randomizer:NextNumber(-200, 200), Randomizer:NextNumber(-200, 200), Randomizer:NextNumber(-200, 200))
	local C = Vector3.new(Randomizer:NextNumber(-200, 200), Randomizer:NextNumber(-200, 200), Randomizer:NextNumber(-200, 200))
	local Distance = Native.FastDistanceSquared(A, B)
	check(near(Native.DistanceSquared(A, B), Distance, 1e-7), "distance consistency " .. Case)
	check(near(Selective.FastDistanceSquared(A, B), Distance, 1e-7) and near(Bytecode.FastDistanceSquared(A, B), Distance, 1e-7), "cross-build distance " .. Case)
	local SegmentSquared = Native.FastPointSegmentDistanceSquared(A, B, C)
	local Reference = Native.FastDistanceSquared(A, Native.ClosestPointOnSegment(A, B, C))
	check(near(SegmentSquared, Reference, 1e-7), "segment distance " .. Case)
	check(near(SegmentSquared, Selective.FastPointSegmentDistanceSquared(A, B, C), 1e-7) and near(SegmentSquared, Bytecode.FastPointSegmentDistanceSquared(A, B, C), 1e-7), "cross-build segment " .. Case)
	check(Native.FastSphereContains(A, B, 150) == Selective.FastSphereContains(A, B, 150), "sphere contains " .. Case)
end

check(near(Native.FastPointSegmentDistanceSquared(Base, Base, Base), 0, 0), "degenerate segment")
check(Native.FastRaySphereTime(Vector3.new(0, 0, -5), Vector3.zAxis, Vector3.zero, 1) ~= nil, "ray sphere hit")
check(Native.FastRayAABBTime(Vector3.new(0, 0, -5), Vector3.zAxis, Vector3.zero, Vector3.one) ~= nil, "ray aabb hit")

local Packets: {buffer} = {}
local Outputs: {any} = {}
for Index = 1, #Modules do
	local Codec = Modules[Index].Codec
	Packets[Index] = Codec.NewBuffer(Codec.FullProfile) :: buffer
	Outputs[Index] = Codec.NewFullSnapshot()
end
local State = Native.Codec.NewFullSnapshot()
for Case = 1, 500 do
	State.Position = Vector3.new(Randomizer:NextNumber(-1000, 1000), Randomizer:NextNumber(-500, 500), Randomizer:NextNumber(-1000, 1000))
	State.Velocity = Vector3.new(Randomizer:NextNumber(-100, 100), Randomizer:NextNumber(-100, 100), Randomizer:NextNumber(-100, 100))
	State.Yaw = Randomizer:NextNumber(-180, 180)
	State.Pitch = Randomizer:NextNumber(-180, 180)
	State.Roll = Randomizer:NextNumber(-180, 180)
	State.TickMs = Randomizer:NextInteger(0, 16000000)
	State.EntityId = Randomizer:NextInteger(0, 1000000)
	State.Flags = Randomizer:NextInteger(0, 4095)
	State.Health = Randomizer:NextInteger(0, 1023)
	State.Sequence = Randomizer:NextInteger(0, 65535)
	State.Metadata = Randomizer:NextInteger(0, 255)
	for Index, Module in Modules do
		check(Module.Codec.WriteFullInto(Packets[Index], State), "codec write " .. Case)
		check(Module.Codec.ReadFullInto(Packets[Index], Outputs[Index]), "codec read " .. Case)
		check(Outputs[Index].Health == State.Health and Outputs[Index].EntityId == State.EntityId, "codec integers " .. Case)
	end
	for Byte = 0, 29 do
		check(buffer.readu8(Packets[1], Byte) == buffer.readu8(Packets[2], Byte) and buffer.readu8(Packets[1], Byte) == buffer.readu8(Packets[3], Byte), "identical encoded bytes " .. Case)
	end
end
print(string.format("[AxiomX Native Test] PASS %d assertions across full/selective/bytecode builds", Checks))
