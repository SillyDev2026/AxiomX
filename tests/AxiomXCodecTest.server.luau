--!strict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local AxiomX = require(ReplicatedStorage:WaitForChild("AxiomX"))
local Codec = AxiomX.Codec
local Randomizer = Random.new(20261105)
local Passed = 0
local Failed = 0

local function check(Name: string, Condition: boolean)
	if Condition then
		Passed += 1
	else
		Failed += 1
		warn("[AxiomX Codec] FAIL:", Name)
	end
end

local function near(A: number, B: number, Error: number): boolean
	return math.abs(A - B) <= Error
end

local function closeVector(A: Vector3, B: Vector3, Error: number): boolean
	return near(A.X, B.X, Error) and near(A.Y, B.Y, Error) and near(A.Z, B.Z, Error)
end

local function angleError(A: number, B: number): number
	return math.abs((A - B + 180) % 360 - 180)
end

check("Version", AxiomX.Version == "1.0.1" and Codec.Version == 1)
check("Profile sizes", Codec.GetBytes(1) == 9 and Codec.GetBytes(2) == 14 and Codec.GetBytes(3) == 15 and Codec.GetBytes(4) == 30)
check("Reject unknown profile", Codec.GetBytes(5) == nil and Codec.NewBuffer(0) == nil)
check("Savings 193 to 30", near(Codec.SavingsPercent(193, 30), 84.455958549, 1e-7))

local Position = Codec.NewBuffer(Codec.PositionProfile) :: buffer
check("9 byte position allocation", buffer.len(Position) == 9)
check("Position roundtrip", Codec.WritePositionInto(Position, Vector3.new(-10.01, 25, 1.23)) and closeVector(Codec.ReadPosition(Position) :: Vector3, Vector3.new(-10.01, 25, 1.23), 0.0001))
check("Position header", buffer.readu8(Position, 0) == 0x51)
check("Position padding", buffer.readbits(Position, 71, 1) == 0)
check("Reject position overflow", not Codec.WritePositionInto(Position, Vector3.new(10485.77, 0, 0)))
check("Rejected write unchanged", buffer.readu8(Position, 0) == 0x51 and Codec.ReadPosition(Position) ~= nil)
check("Reject position NaN", not Codec.WritePositionInto(Position, Vector3.new(0 / 0, 0, 0)))

local PosePacket = Codec.NewBuffer(Codec.PoseProfile) :: buffer
local Pose = Codec.NewPoseSnapshot()
local PoseOutput = Codec.NewPoseSnapshot()
Pose.Position = Vector3.new(-12, 30.03, 90)
Pose.Yaw = -179.99
Pose.Pitch = 25.12
Pose.Roll = -1
check("14 byte pose allocation", buffer.len(PosePacket) == 14)
check("Pose encode decode", Codec.WritePoseInto(PosePacket, Pose) and Codec.ReadPoseInto(PosePacket, PoseOutput))
check("Pose position", closeVector(PoseOutput.Position, Pose.Position, 0.0051))
check("Pose angles", angleError(PoseOutput.Yaw, Pose.Yaw) <= 0.044 and angleError(PoseOutput.Pitch, Pose.Pitch) <= 0.088 and angleError(PoseOutput.Roll, Pose.Roll) <= 0.088)
check("Pose padding", buffer.readbits(PosePacket, 105, 7) == 0)

local MotionPacket = Codec.NewBuffer(Codec.MotionProfile) :: buffer
local Motion = Codec.NewMotionSnapshot()
local MotionOutput = Codec.NewMotionSnapshot()
Motion.Position = Vector3.new(14.01, -25, 40)
Motion.Velocity = Vector3.new(-16.02, 0, 100)
check("15 byte motion allocation", buffer.len(MotionPacket) == 15)
check("Motion encode decode", Codec.WriteMotionInto(MotionPacket, Motion) and Codec.ReadMotionInto(MotionPacket, MotionOutput))
check("Motion position", closeVector(MotionOutput.Position, Motion.Position, 0.0051))
check("Motion velocity", closeVector(MotionOutput.Velocity, Motion.Velocity, 0.0101))
check("Motion padding", buffer.readbits(MotionPacket, 113, 7) == 0)
Motion.Velocity = Vector3.new(500, 0, 0)
check("Reject motion overflow", not Codec.WriteMotionInto(MotionPacket, Motion))

local Packet = Codec.NewBuffer(Codec.FullProfile) :: buffer
local Snapshot = Codec.NewFullSnapshot()
local Out = Codec.NewFullSnapshot()
Snapshot.Position = Vector3.new(-450.12, 23.55, 700)
Snapshot.Velocity = Vector3.new(-13.02, 8.3, 100)
Snapshot.Yaw = 179.9
Snapshot.Pitch = -55.1
Snapshot.Roll = 45.0
Snapshot.TickMs = 16777215
Snapshot.EntityId = 1048575
Snapshot.Flags = 4095
Snapshot.Health = 1023
Snapshot.Sequence = 65535
Snapshot.Metadata = 255
check("30 byte full allocation", buffer.len(Packet) == 30)
check("Full encode decode", Codec.WriteFullInto(Packet, Snapshot) and Codec.ReadFullInto(Packet, Out))
check("Full header", buffer.readu8(Packet, 0) == 0x54)
check("Full padding", buffer.readbits(Packet, 237, 3) == 0)
-- Independently computed reference packet from tools/verify_layout.py.
local Expected = {84, 44, 80, 127, 38, 1, 192, 69, 132, 186, 254, 51, 64, 156, 254, 255, 88, 0, 253, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 31}
local MatchGolden = true
for Index = 1, 30 do
	if buffer.readu8(Packet, Index - 1) ~= Expected[Index] then MatchGolden = false; break end
end
check("Full binary golden packet", MatchGolden)
check("Full position", closeVector(Out.Position, Snapshot.Position, 0.0051))
check("Full velocity", closeVector(Out.Velocity, Snapshot.Velocity, 0.0101))
check("Full angles", angleError(Out.Yaw, Snapshot.Yaw) <= 0.044 and angleError(Out.Pitch, Snapshot.Pitch) <= 0.088 and angleError(Out.Roll, Snapshot.Roll) <= 0.088)
check("Full integer fidelity", Out.TickMs == Snapshot.TickMs and Out.EntityId == Snapshot.EntityId and Out.Flags == Snapshot.Flags and Out.Health == Snapshot.Health and Out.Sequence == Snapshot.Sequence and Out.Metadata == Snapshot.Metadata)

local BeforeInvalid = buffer.tostring(Packet)
Snapshot.Position = Vector3.new(999999, 0, 0)
check("Reject out of bounds position", not Codec.WriteFullInto(Packet, Snapshot))
check("Rejected writes preserve payload", BeforeInvalid == buffer.tostring(Packet))
Snapshot.Position = Vector3.new(5, 0, 0)
Snapshot.EntityId = 1048576
check("Reject ID overflow", not Codec.WriteFullInto(Packet, Snapshot))
Snapshot.EntityId = 10
Snapshot.TickMs = -1
check("Reject negative tick", not Codec.WriteFullInto(Packet, Snapshot))
Snapshot.TickMs = 100
Snapshot.Health = 1024
check("Reject health overflow", not Codec.WriteFullInto(Packet, Snapshot))
Snapshot.Health = 100
Snapshot.Flags = 0.5
check("Reject fractional flags", not Codec.WriteFullInto(Packet, Snapshot))
Snapshot.Flags = 1
check("Writable after rejection", Codec.WriteFullInto(Packet, Snapshot))

local Corrupt = buffer.create(30)
buffer.copy(Corrupt, 0, Packet)
buffer.writeu8(Corrupt, 0, 0x55)
check("Reject unknown header", not Codec.ReadFullInto(Corrupt, Out) and Out.Position == Vector3.zero and Out.Sequence == 0)
buffer.copy(Corrupt, 0, Packet)
buffer.writebits(Corrupt, 237, 3, 7)
check("Reject nonzero padding", not Codec.ReadFullInto(Corrupt, Out) and Out.Health == 0)
check("Reject wrong buffer length", not Codec.ReadFullInto(Position, Out))
check("Reject nil input", not Codec.ReadFullInto(nil :: any, Out))

local AllPositions = true
local AllPoses = true
local AllMotions = true
local AllFull = true
Snapshot = Codec.NewFullSnapshot()
Motion = Codec.NewMotionSnapshot()
Pose = Codec.NewPoseSnapshot()
for Index = 1, 2000 do
	local P = Vector3.new(Randomizer:NextNumber(-1000, 1000), Randomizer:NextNumber(-1000, 1000), Randomizer:NextNumber(-1000, 1000))
	local V = Vector3.new(Randomizer:NextNumber(-150, 150), Randomizer:NextNumber(-150, 150), Randomizer:NextNumber(-150, 150))
	local Yaw = Randomizer:NextNumber(-180, 180)
	local Pitch = Randomizer:NextNumber(-180, 180)
	local Roll = Randomizer:NextNumber(-180, 180)
	if not Codec.WritePositionInto(Position, P) or not closeVector(Codec.ReadPosition(Position) :: Vector3, P, 0.0051) then AllPositions = false end
	Pose.Position = P
	Pose.Yaw = Yaw
	Pose.Pitch = Pitch
	Pose.Roll = Roll
	if not Codec.WritePoseInto(PosePacket, Pose) or not Codec.ReadPoseInto(PosePacket, PoseOutput) or not closeVector(PoseOutput.Position, P, 0.0051) or angleError(PoseOutput.Yaw, Yaw) > 0.044 or angleError(PoseOutput.Pitch, Pitch) > 0.088 or angleError(PoseOutput.Roll, Roll) > 0.088 then AllPoses = false end
	Motion.Position = P
	Motion.Velocity = V
	if not Codec.WriteMotionInto(MotionPacket, Motion) or not Codec.ReadMotionInto(MotionPacket, MotionOutput) or not closeVector(MotionOutput.Velocity, V, 0.0101) then AllMotions = false end
	Snapshot.Position = P
	Snapshot.Velocity = V
	Snapshot.Yaw = Yaw
	Snapshot.Pitch = Pitch
	Snapshot.Roll = Roll
	Snapshot.TickMs = Randomizer:NextInteger(0, 16777215)
	Snapshot.EntityId = Randomizer:NextInteger(0, 1048575)
	Snapshot.Flags = Randomizer:NextInteger(0, 4095)
	Snapshot.Health = Randomizer:NextInteger(0, 1023)
	Snapshot.Sequence = Randomizer:NextInteger(0, 65535)
	Snapshot.Metadata = Randomizer:NextInteger(0, 255)
	if not Codec.WriteFullInto(Packet, Snapshot) or not Codec.ReadFullInto(Packet, Out) or not closeVector(Out.Position, P, 0.0051) or not closeVector(Out.Velocity, V, 0.0101) or angleError(Out.Yaw, Yaw) > 0.044 or angleError(Out.Pitch, Pitch) > 0.088 or angleError(Out.Roll, Roll) > 0.088 or Out.TickMs ~= Snapshot.TickMs or Out.EntityId ~= Snapshot.EntityId or Out.Flags ~= Snapshot.Flags or Out.Health ~= Snapshot.Health or Out.Sequence ~= Snapshot.Sequence or Out.Metadata ~= Snapshot.Metadata then AllFull = false end
end
check("2000 randomized position snapshots", AllPositions)
check("2000 randomized pose snapshots", AllPoses)
check("2000 randomized motion snapshots", AllMotions)
check("2000 randomized full snapshots", AllFull)

print(string.format("[AxiomX Codec] %d passed, %d failed", Passed, Failed))
assert(Failed == 0, "AxiomX Codec regression failed")
