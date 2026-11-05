--!strict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local AxiomX = require(ReplicatedStorage:WaitForChild("AxiomX"))
local Passed = 0
local Failed = 0
local function check(Name: string, Valid: boolean)
	if Valid then Passed += 1 else Failed += 1; warn("[AxiomX patch] FAIL", Name) end
end
local Nan = 0 / 0
local Center = Vector3.zero
local Unit = Vector3.xAxis
local Bad = Vector3.new(Nan, 0, 0)
local Point, Time = AxiomX.RaySphereIntersection(Center, Unit, Center, 2)
check("Inside sphere t0", Point == Center and Time == 0)
check("Fast inside sphere t0", AxiomX.FastRaySphereTime(Center, Unit, Center, 2) == 0)
local SegmentPoint, SegmentTime = AxiomX.SegmentSphereIntersection(Center, Unit, Center, 2)
check("Inside segment t0", SegmentPoint == Center and SegmentTime == 0)
check("Zero ray direction", AxiomX.RaySphereIntersection(Center, Center, Center, 2) == nil)
check("NaN ray origin", AxiomX.RaySphereIntersection(Bad, Unit, Center, 2) == nil)
check("NaN fast ray origin", AxiomX.FastRaySphereTime(Bad, Unit, Center, 2) == nil)
check("NaN fast ray direction", AxiomX.FastRaySphereTime(Center, Bad, Center, 2) == nil)
check("NaN cone angle", not AxiomX.PointInCone(Center, Center, Unit, Nan, 10))
check("NaN cone distance", not AxiomX.PointInCone(Center, Center, Unit, 60, Nan))
check("NaN view angle", not AxiomX.PointInViewCone(Center, CFrame.new(), Nan, 10))
check("NaN view distance", not AxiomX.PointInViewCone(Center, CFrame.new(), 60, Nan))
check("Negative view distance", not AxiomX.PointInViewCone(Center, CFrame.new(), 60, -1))
local P1 = Vector3.zero
local P2 = Vector3.xAxis
local P3 = Vector3.zAxis
check("NaN triangle tolerance", not AxiomX.PointInTriangle(P1, P1, P2, P3, Nan))
check("Negative triangle tolerance", not AxiomX.PointInTriangle(P1, P1, P2, P3, -1))
check("NaN projectile steps", #AxiomX.SampleProjectilePath(Center, Unit, 1, Nan) == 0)
check("NaN ray trace steps", AxiomX.TraceProjectile(Center, Unit, 1, Nan, nil) == nil)
check("NaN sphere trace steps", AxiomX.TraceProjectileSphere(Center, Unit, 1, 1, Nan, nil) == nil)
local Path = AxiomX.SampleProjectilePath(Center, Unit, 1, 4, Vector3.zero)
check("Valid path unaffected", #Path == 5 and Path[5] == Unit)
local Results: {BasePart} = {}
check("Box rejects NaN size", #AxiomX.GetPartsInBox(CFrame.new(), Bad) == 0)
check("Into box rejects NaN size", AxiomX.GetPartsInBoxInto(CFrame.new(), Bad, nil, Results) == 0 and #Results == 0)
local Part = Instance.new("Part")
check("Shapecast rejects zero size", AxiomX.CastShape(Part, Unit, 10, nil, nil, Vector3.new(0, 1, 1)) == nil)
check("Shapecast displacement rejects zero size", AxiomX.CastShapeDisplacement(Part, Unit, nil, nil, Vector3.new(0, 1, 1)) == nil)
Part:Destroy()
check("Infinite MaxParts means unlimited", AxiomX.MakeOverlapParams(nil, math.huge).MaxParts == 0)
check("Very large MaxParts is bounded", AxiomX.MakeOverlapParams(nil, 1e20).MaxParts == 2147483647)
check("Patch version", AxiomX.Version == "1.0.1" and AxiomX.Codec.Version == 1)
print(string.format("[AxiomX patch] %d passed; %d failed", Passed, Failed))
assert(Failed == 0, "AxiomX v1.0.1 patch tests failed")
