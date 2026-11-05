--!strict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AxiomX = require(ReplicatedStorage:WaitForChild("AxiomX"))
local Origin = Vector3.new(0, 30, 0)
local Direction = -Vector3.yAxis
local Params = AxiomX.MakeRaycastParams()
local Impact = AxiomX.MakeImpactBuffer()
local Projectile = AxiomX.MakeProjectileBuffer()
local Gravity = Vector3.new(0, -workspace.Gravity, 0)
local UsedQueries = 0

local Allowed, NextUsedQueries = AxiomX.TryConsumeQueryBudget(UsedQueries, 8)
UsedQueries = NextUsedQueries

if Allowed and AxiomX.GetImpactDataInto(Origin, Direction, 100, Params, Impact) then
	print("Impact angle:", Impact.Angle)
	print("Hit part:", Impact.Instance)
	print("Distance:", Impact.Distance)
	print("Reflection:", Impact.Reflection)
end

local Position = AxiomX.FastProjectilePosition(Origin, Vector3.new(20, 20, 0), Gravity, 0.25)
print("Projectile at 0.25 seconds:", Position)

if AxiomX.TraceProjectileInto(Origin, Vector3.new(0, -20, 0), 1, 16, Params, Gravity, Projectile) then
	print("Projectile impact at:", Projectile.Time)
end

-- AxiomX compact serialization: one reusable output buffer for repeated snapshots.
local Codec = AxiomX.Codec
local Wire = Codec.NewBuffer(Codec.FullProfile) :: buffer
local State = Codec.NewFullSnapshot()
local Decoded = Codec.NewFullSnapshot()

State.Position = Vector3.new(12.34, 5, -8.72)
State.Velocity = Vector3.new(0, -5.5, 12)
State.Yaw = 90
State.Pitch = -8
State.Roll = 0
State.TickMs = 1000
State.EntityId = 72
State.Flags = 3
State.Health = 100
State.Sequence = 15
State.Metadata = 0

if Codec.WriteFullInto(Wire, State) and Codec.ReadFullInto(Wire, Decoded) then
	print("AxiomX compressed bytes:", buffer.len(Wire))
	print("Decoded position:", Decoded.Position)
end
