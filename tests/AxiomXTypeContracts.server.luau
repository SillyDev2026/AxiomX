--!strict
--!optimize 2

-- Studio Script Analysis validates exported types and public return signatures.
-- Requires ModuleScript named AxiomX directly under ReplicatedStorage.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local AxiomX = require(ReplicatedStorage.AxiomX)
type ImpactData = AxiomX.ImpactData
type ImpactBuffer = AxiomX.ImpactBuffer
type ProjectileHit = AxiomX.ProjectileHit
type ProjectileBuffer = AxiomX.ProjectileBuffer
type FullSnapshot = AxiomX.FullSnapshot
type PoseSnapshot = AxiomX.PoseSnapshot
type MotionSnapshot = AxiomX.MotionSnapshot

local Origin: Vector3 = Vector3.new(0, 10, 0)
local Direction: Vector3 = -Vector3.yAxis
local Out: ImpactBuffer = AxiomX.MakeImpactBuffer()
local ProjectileOut: ProjectileBuffer = AxiomX.MakeProjectileBuffer()
local Data: ImpactData? = AxiomX.GetImpactData(Origin, Direction, 12)
local Hit: ProjectileHit? = AxiomX.TraceProjectile(Origin, Direction, 1, 5)
local Params: RaycastParams = AxiomX.MakeRaycastParams()
local Overlap: OverlapParams = AxiomX.MakeOverlapParams()
local Parts: {BasePart} = AxiomX.GetPartsInRadius(Origin, 8, Overlap)
local Full: FullSnapshot = AxiomX.Codec.NewFullSnapshot()
local Pose: PoseSnapshot = AxiomX.Codec.NewPoseSnapshot()
local Motion: MotionSnapshot = AxiomX.Codec.NewMotionSnapshot()
local Packet: buffer? = AxiomX.Codec.NewBuffer(AxiomX.Codec.FullProfile)
local Angle: number? = AxiomX.GetImpactAngle(Origin, Direction, 20, Params)
local Score: number = AxiomX.DistanceSquared(Origin, Vector3.zero)
local HitValid: boolean = AxiomX.GetImpactDataInto(Origin, Direction, 12, Params, Out)
if Packet then
	local Written: boolean = AxiomX.Codec.WriteFullInto(Packet, Full)
	local Read: boolean = AxiomX.Codec.ReadFullInto(Packet, Full)
	assert(Written and Read)
end
assert(Score >= 0 and #Parts >= 0 and not (HitValid and Out.Result == nil))
assert(Data == nil or Data.Distance >= 0)
assert(Hit == nil or Hit.Time >= 0)
assert(Angle == nil or Angle >= 0)
assert(Pose.Position == Vector3.zero and Motion.Velocity == Vector3.zero)
assert(ProjectileOut.Time == nil)
print("[AxiomX] Type contracts loaded; check Studio Script Analysis for warnings")
