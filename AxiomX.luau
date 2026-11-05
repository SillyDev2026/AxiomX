--!native
--!optimize 2
--!strict

local Workspace = game:GetService("Workspace")
local AxiomX = {}

AxiomX.Version = "1.0.0"
AxiomX.Epsilon = 1e-8
AxiomX.RayLimit = 1000
AxiomX.MaxRayDistance = 15000
AxiomX.MaxSweepDistance = 1024
AxiomX.MaxSphereRadius = 256
AxiomX.MaxBlockSize = 512
AxiomX.MaxTrajectorySteps = 256
AxiomX.AllocationPolicy = "Pure math avoids Lua result tables; Into/Codec reuse caller buffers; physics APIs may allocate"
AxiomX.NativeMode = "full"

local ZERO = Vector3.zero
local UP = Vector3.yAxis
local HUGE = math.huge
local EPS = AxiomX.Epsilon

export type ImpactData = {
	Result: RaycastResult,
	Instance: BasePart,
	Material: Enum.Material,
	Position: Vector3,
	Normal: Vector3,
	Distance: number,
	Angle: number,
	SlopeAngle: number,
	Reflection: Vector3,
}

export type ProjectileHit = {
	Result: RaycastResult,
	Position: Vector3,
	Velocity: Vector3,
	Time: number,
}

-- Allocate these buffers ONCE per owner; do not share a mutable buffer across concurrent callers.
export type ImpactBuffer = {
	Result: RaycastResult?,
	Instance: BasePart?,
	Material: Enum.Material?,
	Position: Vector3?,
	Normal: Vector3?,
	Distance: number?,
	Angle: number?,
	SlopeAngle: number?,
	Reflection: Vector3?,
}

export type ProjectileBuffer = {
	Result: RaycastResult?,
	Position: Vector3?,
	Velocity: Vector3?,
	Time: number?,
}

local function finite(N: number): boolean
	return N == N and N ~= HUGE and N ~= -HUGE
end

local function unit(V: Vector3): Vector3
	local Length = V.Magnitude
	return if Length > EPS and finite(Length) then V / Length else ZERO
end

local function scalarRay(Direction: Vector3, Distance: number?, Limit: number): Vector3?
	local Length = Distance or AxiomX.RayLimit
	if not finite(Length) or Length <= 0 or Length > Limit then return nil end
	local Unit = unit(Direction)
	return if Unit ~= ZERO then Unit * Length else nil
end

local function gravityVector(Gravity: Vector3?): Vector3
	return Gravity or Vector3.new(0, -Workspace.Gravity, 0)
end

-- Number utilities
function AxiomX.IsFinite(N: number): boolean
	return finite(N)
end

function AxiomX.Clamp01(N: number): number
	return math.clamp(N, 0, 1)
end

function AxiomX.Lerp(A: number, B: number, Alpha: number): number
	return A + (B - A) * Alpha
end

function AxiomX.InverseLerp(A: number, B: number, Value: number): number
	local Delta = B - A
	return if math.abs(Delta) > EPS then (Value - A) / Delta else 0
end

function AxiomX.Remap(Value: number, FromMin: number, FromMax: number, ToMin: number, ToMax: number): number
	return ToMin + (ToMax - ToMin) * AxiomX.InverseLerp(FromMin, FromMax, Value)
end

function AxiomX.SmoothStep(A: number, B: number, Value: number): number
	local T = math.clamp(AxiomX.InverseLerp(A, B, Value), 0, 1)
	return T * T * (3 - 2 * T)
end

function AxiomX.SmootherStep(A: number, B: number, Value: number): number
	local T = math.clamp(AxiomX.InverseLerp(A, B, Value), 0, 1)
	return T * T * T * (T * (T * 6 - 15) + 10)
end

function AxiomX.Damp(Current: number, Target: number, Speed: number, DeltaTime: number): number
	if Speed <= 0 or DeltaTime <= 0 then return Current end
	return Target + (Current - Target) * math.exp(-Speed * DeltaTime)
end

function AxiomX.MoveTowards(Current: number, Target: number, MaxDelta: number): number
	if MaxDelta <= 0 then return Current end
	local Delta = Target - Current
	return if math.abs(Delta) <= MaxDelta then Target else Current + math.sign(Delta) * MaxDelta
end

function AxiomX.Wrap(Value: number, Minimum: number, Maximum: number): number
	local Width = Maximum - Minimum
	return if Width > 0 then (Value - Minimum) % Width + Minimum else Minimum
end

function AxiomX.PingPong(Value: number, Length: number): number
	if Length <= 0 then return 0 end
	local Remainder = Value % (2 * Length)
	return Length - math.abs(Remainder - Length)
end

function AxiomX.DeltaAngle(A: number, B: number): number
	local Delta = (B - A + 180) % 360 - 180
	return if Delta == -180 then 180 else Delta
end

function AxiomX.LerpAngle(A: number, B: number, Alpha: number): number
	return A + AxiomX.DeltaAngle(A, B) * Alpha
end

function AxiomX.NearlyEqual(A: number, B: number, Tolerance: number?): boolean
	local Tol = Tolerance or 1e-6
	return math.abs(A - B) <= Tol * math.max(1, math.abs(A), math.abs(B))
end

function AxiomX.RoundTo(Value: number, Step: number): number
	return if Step > 0 then math.round(Value / Step) * Step else Value
end

-- Vector utilities
function AxiomX.IsFiniteVector(V: Vector3): boolean
	return finite(V.X) and finite(V.Y) and finite(V.Z)
end

function AxiomX.SafeUnit(V: Vector3): Vector3
	return unit(V)
end

function AxiomX.Direction(Origin: Vector3, Target: Vector3): Vector3
	return unit(Target - Origin)
end

function AxiomX.DistanceSquared(A: Vector3, B: Vector3): number
	local DX = B.X - A.X
	local DY = B.Y - A.Y
	local DZ = B.Z - A.Z
	return DX * DX + DY * DY + DZ * DZ
end

function AxiomX.AngleBetween(A: Vector3, B: Vector3): number
	local U = unit(A)
	local V = unit(B)
	if U == ZERO or V == ZERO then return 0 end
	return math.deg(math.acos(math.clamp(U:Dot(V), -1, 1)))
end

function AxiomX.SignedAngle(A: Vector3, B: Vector3, Axis: Vector3): number
	local U = unit(A)
	local V = unit(B)
	local N = unit(Axis)
	if U == ZERO or V == ZERO or N == ZERO then return 0 end
	local ProjectedA = unit(U - N * U:Dot(N))
	local ProjectedB = unit(V - N * V:Dot(N))
	if ProjectedA == ZERO or ProjectedB == ZERO then return 0 end
	return math.deg(math.atan2(N:Dot(ProjectedA:Cross(ProjectedB)), ProjectedA:Dot(ProjectedB)))
end

function AxiomX.Project(V: Vector3, Onto: Vector3): Vector3
	local Divisor = Onto:Dot(Onto)
	return if Divisor > EPS * EPS then Onto * (V:Dot(Onto) / Divisor) else ZERO
end

function AxiomX.Reject(V: Vector3, From: Vector3): Vector3
	return V - AxiomX.Project(V, From)
end

function AxiomX.Reflect(Direction: Vector3, Normal: Vector3): Vector3
	local N = unit(Normal)
	return if N ~= ZERO then Direction - N * (2 * Direction:Dot(N)) else Direction
end

function AxiomX.Refract(Direction: Vector3, Normal: Vector3, IndexFrom: number, IndexTo: number): Vector3?
	if IndexFrom <= 0 or IndexTo <= 0 then return nil end
	local I = unit(Direction)
	local N = unit(Normal)
	if I == ZERO or N == ZERO then return nil end
	local CosI = math.clamp(-I:Dot(N), -1, 1)
	local Ratio = IndexFrom / IndexTo
	if CosI < 0 then
		N = -N
		CosI = -CosI
	end
	local K = 1 - Ratio * Ratio * (1 - CosI * CosI)
	if K < 0 then return nil end
	return unit(Ratio * I + (Ratio * CosI - math.sqrt(K)) * N)
end

function AxiomX.RotateAroundAxis(V: Vector3, Axis: Vector3, AngleDegrees: number): Vector3
	local N = unit(Axis)
	if N == ZERO then return V end
	local Angle = math.rad(AngleDegrees)
	local C = math.cos(Angle)
	local S = math.sin(Angle)
	return V * C + N:Cross(V) * S + N * (N:Dot(V) * (1 - C))
end

function AxiomX.LerpVector(A: Vector3, B: Vector3, Alpha: number): Vector3
	return A + (B - A) * Alpha
end

function AxiomX.DampVector(Current: Vector3, Target: Vector3, Speed: number, DeltaTime: number): Vector3
	if Speed <= 0 or DeltaTime <= 0 then return Current end
	return Target + (Current - Target) * math.exp(-Speed * DeltaTime)
end

function AxiomX.MoveTowardsVector(Current: Vector3, Target: Vector3, MaxDelta: number): Vector3
	if MaxDelta <= 0 then return Current end
	local Difference = Target - Current
	local Length = Difference.Magnitude
	return if Length <= MaxDelta or Length <= EPS then Target else Current + Difference * (MaxDelta / Length)
end

function AxiomX.FlatDirection(Origin: Vector3, Target: Vector3): Vector3
	local Delta = Target - Origin
	return unit(Vector3.new(Delta.X, 0, Delta.Z))
end

function AxiomX.HorizontalDistance(A: Vector3, B: Vector3): number
	local DX = B.X - A.X
	local DZ = B.Z - A.Z
	return math.sqrt(DX * DX + DZ * DZ)
end

function AxiomX.LookAtSafe(Origin: Vector3, Target: Vector3, Up: Vector3?): CFrame
	local Direction = unit(Target - Origin)
	if Direction == ZERO then return CFrame.new(Origin) end
	local UpUnit = unit(Up or UP)
	if UpUnit == ZERO or math.abs(Direction:Dot(UpUnit)) > 0.999 then
		UpUnit = if math.abs(Direction:Dot(UP)) < 0.999 then UP else Vector3.xAxis
	end
	return CFrame.lookAt(Origin, Target, UpUnit)
end

-- Geometry
function AxiomX.PointOnRay(Origin: Vector3, Direction: Vector3, Distance: number): Vector3
	return Origin + unit(Direction) * Distance
end

function AxiomX.ClosestPointOnLine(Point: Vector3, A: Vector3, B: Vector3): Vector3
	local Delta = B - A
	local Denominator = Delta:Dot(Delta)
	return if Denominator > EPS * EPS then A + Delta * ((Point - A):Dot(Delta) / Denominator) else A
end

function AxiomX.ClosestPointOnRay(Point: Vector3, Origin: Vector3, Direction: Vector3): Vector3
	local D = unit(Direction)
	return Origin + D * math.max(0, (Point - Origin):Dot(D))
end

function AxiomX.ClosestPointOnSegment(Point: Vector3, A: Vector3, B: Vector3): Vector3
	local Delta = B - A
	local Denominator = Delta:Dot(Delta)
	return if Denominator > EPS * EPS then A + Delta * math.clamp((Point - A):Dot(Delta) / Denominator, 0, 1) else A
end

function AxiomX.DistanceToSegment(Point: Vector3, A: Vector3, B: Vector3): number
	return (Point - AxiomX.ClosestPointOnSegment(Point, A, B)).Magnitude
end

function AxiomX.PointInSphere(Point: Vector3, Center: Vector3, Radius: number): boolean
	return Radius >= 0 and AxiomX.DistanceSquared(Point, Center) <= Radius * Radius
end

function AxiomX.PointInAABB(Point: Vector3, Center: Vector3, Size: Vector3): boolean
	if Size.X < 0 or Size.Y < 0 or Size.Z < 0 then return false end
	local Delta = Point - Center
	return math.abs(Delta.X) <= Size.X * 0.5 and math.abs(Delta.Y) <= Size.Y * 0.5 and math.abs(Delta.Z) <= Size.Z * 0.5
end

function AxiomX.PointInBox(Point: Vector3, Box: CFrame, Size: Vector3): boolean
	return AxiomX.PointInAABB(Box:PointToObjectSpace(Point), ZERO, Size)
end

function AxiomX.SpheresOverlap(CenterA: Vector3, RadiusA: number, CenterB: Vector3, RadiusB: number): boolean
	if RadiusA < 0 or RadiusB < 0 then return false end
	local Combined = RadiusA + RadiusB
	return AxiomX.DistanceSquared(CenterA, CenterB) <= Combined * Combined
end

function AxiomX.PointInCone(Point: Vector3, Apex: Vector3, Forward: Vector3, AngleDegrees: number, MaxDistance: number): boolean
	if AngleDegrees < 0 or AngleDegrees > 180 or MaxDistance < 0 then return false end
	local Delta = Point - Apex
	local Length = Delta.Magnitude
	if Length > MaxDistance then return false end
	if Length <= EPS then return true end
	local D = unit(Forward)
	return D ~= ZERO and (Delta / Length):Dot(D) >= math.cos(math.rad(AngleDegrees))
end

function AxiomX.PointInViewCone(Point: Vector3, Camera: CFrame, FullAngleDegrees: number, MaxDistance: number?): boolean
	if FullAngleDegrees < 0 or FullAngleDegrees > 360 then return false end
	local Delta = Point - Camera.Position
	local Limit = MaxDistance or HUGE
	local Length = Delta.Magnitude
	if Length > Limit then return false end
	if Length <= EPS then return true end
	return Delta:Dot(Camera.LookVector) / Length >= math.cos(math.rad(FullAngleDegrees * 0.5))
end

function AxiomX.GetSlopeAngle(Normal: Vector3): number
	return AxiomX.AngleBetween(Normal, UP)
end

-- Engine queries. CastRay defaults to AxiomX.RayLimit; Raycast uses raw displacement.
function AxiomX.MakeRaycastParams(Exclude: {Instance}?, CollisionGroup: string?): RaycastParams
	local Params = RaycastParams.new()
	Params.ExcludeInstances = Exclude
	if CollisionGroup then Params.CollisionGroup = CollisionGroup end
	return Params
end

function AxiomX.MakeOverlapParams(Exclude: {Instance}?, MaxParts: number?, CollisionGroup: string?): OverlapParams
	local Params = OverlapParams.new()
	Params.ExcludeInstances = Exclude
	Params.MaxParts = if MaxParts and finite(MaxParts) then math.max(0, math.floor(MaxParts)) else 0
	if CollisionGroup then Params.CollisionGroup = CollisionGroup end
	return Params
end

function AxiomX.Raycast(Origin: Vector3, Displacement: Vector3, Params: RaycastParams?): RaycastResult?
	local Length = Displacement.Magnitude
	if Length <= EPS or Length > AxiomX.MaxRayDistance or not finite(Length) or not AxiomX.IsFiniteVector(Origin) then return nil end
	return Workspace:Raycast(Origin, Displacement, Params)
end

function AxiomX.CastRay(Origin: Vector3, Direction: Vector3, Distance: number?, Params: RaycastParams?): RaycastResult?
	if not AxiomX.IsFiniteVector(Origin) then return nil end
	local Displacement = scalarRay(Direction, Distance, AxiomX.MaxRayDistance)
	return if Displacement then Workspace:Raycast(Origin, Displacement, Params) else nil
end

function AxiomX.CastSphere(Origin: Vector3, Radius: number, Direction: Vector3, Distance: number?, Params: RaycastParams?): RaycastResult?
	if not finite(Radius) or Radius <= 0 or Radius > AxiomX.MaxSphereRadius or not AxiomX.IsFiniteVector(Origin) then return nil end
	local Displacement = scalarRay(Direction, Distance, AxiomX.MaxSweepDistance)
	return if Displacement then Workspace:Spherecast(Origin, Radius, Displacement, Params) else nil
end

function AxiomX.CastBlock(Box: CFrame, Size: Vector3, Direction: Vector3, Distance: number?, Params: RaycastParams?): RaycastResult?
	if not AxiomX.IsFiniteVector(Size) then return nil end
	if Size.X <= 0 or Size.Y <= 0 or Size.Z <= 0 or Size.X > AxiomX.MaxBlockSize or Size.Y > AxiomX.MaxBlockSize or Size.Z > AxiomX.MaxBlockSize then return nil end
	if not AxiomX.IsFiniteVector(Box.Position) then return nil end
	local Displacement = scalarRay(Direction, Distance, AxiomX.MaxSweepDistance)
	return if Displacement then Workspace:Blockcast(Box, Size, Displacement, Params) else nil
end

function AxiomX.GetImpactData(Origin: Vector3, Direction: Vector3, Distance: number?, Params: RaycastParams?): ImpactData?
	local Unit = unit(Direction)
	local Length = Distance or AxiomX.RayLimit
	if Unit == ZERO or not finite(Length) or Length <= 0 or Length > AxiomX.MaxRayDistance or not AxiomX.IsFiniteVector(Origin) then return nil end
	local Result = Workspace:Raycast(Origin, Unit * Length, Params)
	if not Result then return nil end
	local Normal = Result.Normal
	local Dot = Unit:Dot(Normal)
	local Incidence = math.clamp(-Dot, -1, 1)
	return {
		Result = Result,
		Instance = Result.Instance,
		Material = Result.Material,
		Position = Result.Position,
		Normal = Result.Normal,
		Distance = Result.Distance,
		Angle = math.deg(math.acos(Incidence)),
		SlopeAngle = math.deg(math.acos(math.clamp(Normal:Dot(UP), -1, 1))),
		Reflection = Unit - 2 * Dot * Normal,
	}
end

function AxiomX.GetImpactAngle(Origin: Vector3, Direction: Vector3, Distance: number?, Params: RaycastParams?): number?
	local Unit = unit(Direction)
	if Unit == ZERO then return nil end
	local Hit = AxiomX.CastRay(Origin, Unit, Distance, Params)
	return if Hit then math.deg(math.acos(math.clamp(-Unit:Dot(Hit.Normal), -1, 1))) else nil
end

function AxiomX.GetImpactPosition(Origin: Vector3, Direction: Vector3, Distance: number?, Params: RaycastParams?): Vector3?
	local Hit = AxiomX.CastRay(Origin, Direction, Distance, Params)
	return if Hit then Hit.Position else nil
end

function AxiomX.GetGroundHit(Origin: Vector3, Distance: number?, Params: RaycastParams?): RaycastResult?
	return AxiomX.CastRay(Origin, -UP, Distance, Params)
end

function AxiomX.GetGroundDistance(Origin: Vector3, Distance: number?, Params: RaycastParams?): number?
	local Hit = AxiomX.GetGroundHit(Origin, Distance, Params)
	return if Hit then Hit.Distance else nil
end

function AxiomX.HasLineOfSight(Origin: Vector3, Target: Vector3, Params: RaycastParams?, TargetInstance: Instance?): boolean
	local Displacement = Target - Origin
	local Length = Displacement.Magnitude
	if not AxiomX.IsFiniteVector(Origin) or not AxiomX.IsFiniteVector(Target) then return false end
	if Length <= EPS then return true end
	if Length > AxiomX.MaxRayDistance or not finite(Length) then return false end
	local Hit = AxiomX.Raycast(Origin, Displacement, Params)
	if not Hit then return true end
	return TargetInstance ~= nil and (Hit.Instance == TargetInstance or Hit.Instance:IsDescendantOf(TargetInstance))
end

function AxiomX.GetPartsInRadius(Center: Vector3, Radius: number, Params: OverlapParams?): {BasePart}
	if not finite(Radius) or Radius <= 0 or not AxiomX.IsFiniteVector(Center) then return {} end
	return Workspace:GetPartBoundsInRadius(Center, Radius, Params)
end

function AxiomX.GetPartsInBox(Box: CFrame, Size: Vector3, Params: OverlapParams?): {BasePart}
	if not AxiomX.IsFiniteVector(Size) or Size.X <= 0 or Size.Y <= 0 or Size.Z <= 0 then return {} end
	return Workspace:GetPartBoundsInBox(Box, Size, Params)
end

function AxiomX.GetPartsInPart(Part: BasePart, Params: OverlapParams?): {BasePart}
	return Workspace:GetPartsInPart(Part, Params)
end

-- Ballistics and target prediction. Gravity is acceleration in studs/s^2.
function AxiomX.ProjectilePosition(Origin: Vector3, Velocity: Vector3, Time: number, Gravity: Vector3?): Vector3
	return Origin + Velocity * Time + gravityVector(Gravity) * (0.5 * Time * Time)
end

function AxiomX.ProjectileVelocity(Velocity: Vector3, Time: number, Gravity: Vector3?): Vector3
	return Velocity + gravityVector(Gravity) * Time
end

function AxiomX.SolveLaunchVelocity(Origin: Vector3, Target: Vector3, TravelTime: number, Gravity: Vector3?): Vector3?
	if TravelTime <= EPS or not finite(TravelTime) then return nil end
	return (Target - Origin - gravityVector(Gravity) * (0.5 * TravelTime * TravelTime)) / TravelTime
end

function AxiomX.SolveBallisticArc(Origin: Vector3, Target: Vector3, Speed: number, Gravity: number?): (Vector3?, Vector3?)
	local G = Gravity or Workspace.Gravity
	if Speed <= EPS or G <= EPS or not finite(Speed) or not finite(G) then return nil, nil end
	local Offset = Target - Origin
	local Horizontal = Vector3.new(Offset.X, 0, Offset.Z)
	local X = Horizontal.Magnitude
	local Y = Offset.Y
	if X <= EPS then
		if Speed * Speed < 2 * G * Y then return nil, nil end
		if Y < 0 then return UP * Speed, -UP * Speed end
		return UP * Speed, nil
	end
	local S2 = Speed * Speed
	local Discriminant = S2 * S2 - G * (G * X * X + 2 * Y * S2)
	if Discriminant < 0 then return nil, nil end
	local Root = math.sqrt(Discriminant)
	local LowerTan = (S2 - Root) / (G * X)
	local HigherTan = (S2 + Root) / (G * X)
	local Direction = Horizontal / X
	local LowerScale = Speed / math.sqrt(1 + LowerTan * LowerTan)
	local HigherScale = Speed / math.sqrt(1 + HigherTan * HigherTan)
	local Lower = Direction * LowerScale + UP * (LowerScale * LowerTan)
	local Higher = Direction * HigherScale + UP * (HigherScale * HigherTan)
	return Lower, Higher
end

function AxiomX.TimeToReachHeight(StartY: number, TargetY: number, InitialVerticalSpeed: number, Gravity: number?): (number?, number?)
	local G = Gravity or Workspace.Gravity
	if G <= EPS or not finite(G) then return nil, nil end
	local Discriminant = InitialVerticalSpeed * InitialVerticalSpeed - 2 * G * (TargetY - StartY)
	if Discriminant < 0 then return nil, nil end
	local Root = math.sqrt(Discriminant)
	local First = (InitialVerticalSpeed - Root) / G
	local Second = (InitialVerticalSpeed + Root) / G
	if First >= 0 and Second >= 0 then return First, Second end
	if Second >= 0 then return Second, nil end
	return nil, nil
end

function AxiomX.PredictIntercept(Origin: Vector3, TargetPosition: Vector3, TargetVelocity: Vector3, ProjectileSpeed: number): (Vector3?, number?)
	if ProjectileSpeed <= EPS or not finite(ProjectileSpeed) then return nil, nil end
	local Relative = TargetPosition - Origin
	local C = Relative:Dot(Relative)
	if C <= EPS * EPS then return TargetPosition, 0 end
	local A = TargetVelocity:Dot(TargetVelocity) - ProjectileSpeed * ProjectileSpeed
	local B = 2 * Relative:Dot(TargetVelocity)
	local T: number?
	if math.abs(A) <= EPS then
		if math.abs(B) <= EPS then return nil, nil end
		local Candidate = -C / B
		if Candidate < 0 then return nil, nil end
		T = Candidate
	else
		local Discriminant = B * B - 4 * A * C
		if Discriminant < 0 then return nil, nil end
		local Root = math.sqrt(Discriminant)
		local T1 = (-B - Root) / (2 * A)
		local T2 = (-B + Root) / (2 * A)
		if T1 >= 0 and T2 >= 0 then
			T = math.min(T1, T2)
		elseif T1 >= 0 then
			T = T1
		elseif T2 >= 0 then
			T = T2
		else
			return nil, nil
		end
	end
	if T == nil then return nil, nil end
	return TargetPosition + TargetVelocity * T, T
end

function AxiomX.BounceVelocity(Velocity: Vector3, Normal: Vector3, Restitution: number?, Friction: number?): Vector3
	local N = unit(Normal)
	if N == ZERO then return Velocity end
	local E = math.clamp(Restitution or 1, 0, 1)
	local F = math.clamp(Friction or 0, 0, 1)
	local NormalSpeed = Velocity:Dot(N)
	local Tangential = Velocity - N * NormalSpeed
	return Tangential * (1 - F) + N * (if NormalSpeed < 0 then -NormalSpeed * E else NormalSpeed)
end

function AxiomX.TraceProjectile(Origin: Vector3, Velocity: Vector3, Duration: number, Steps: number, Params: RaycastParams?, Gravity: Vector3?): ProjectileHit?
	if Duration <= 0 or not finite(Duration) or Steps < 1 or Steps > AxiomX.MaxTrajectorySteps or Steps % 1 ~= 0 then return nil end
	if not AxiomX.IsFiniteVector(Origin) or not AxiomX.IsFiniteVector(Velocity) then return nil end
	local Acceleration = gravityVector(Gravity)
	if not AxiomX.IsFiniteVector(Acceleration) then return nil end
	local Step = Duration / Steps
	local Previous = Origin
	for Index = 1, Steps do
		local Time = Index * Step
		local Next = Origin + Velocity * Time + Acceleration * (0.5 * Time * Time)
		local Segment = Next - Previous
		local Length = Segment.Magnitude
		if Length > 15000 then return nil end
		if Length > EPS then
			local Hit = Workspace:Raycast(Previous, Segment, Params)
			if Hit then
				local HitTime = (Index - 1) * Step + Step * math.clamp(Hit.Distance / Length, 0, 1)
				return {Result = Hit, Position = Hit.Position, Velocity = Velocity + Acceleration * HitTime, Time = HitTime}
			end
		end
		Previous = Next
	end
	return nil
end


-- Advanced scalar math. All time-based routines accept seconds.
function AxiomX.LerpClamped(A: number, B: number, Alpha: number): number
	return A + (B - A) * math.clamp(Alpha, 0, 1)
end

function AxiomX.InverseLerpClamped(A: number, B: number, Value: number): number
	return math.clamp(AxiomX.InverseLerp(A, B, Value), 0, 1)
end

function AxiomX.RemapClamped(Value: number, FromMin: number, FromMax: number, ToMin: number, ToMax: number): number
	return ToMin + (ToMax - ToMin) * AxiomX.InverseLerpClamped(FromMin, FromMax, Value)
end

function AxiomX.Fract(Value: number): number
	return Value - math.floor(Value)
end

function AxiomX.Step(Edge: number, Value: number): number
	return if Value < Edge then 0 else 1
end

function AxiomX.SignNonZero(Value: number): number
	return if Value < 0 then -1 else 1
end

function AxiomX.MoveTowardsAngle(Current: number, Target: number, MaxDelta: number): number
	local Difference = AxiomX.DeltaAngle(Current, Target)
	return Current + AxiomX.MoveTowards(0, Difference, MaxDelta)
end

function AxiomX.DampAngle(Current: number, Target: number, Speed: number, DeltaTime: number): number
	return Current + AxiomX.Damp(0, AxiomX.DeltaAngle(Current, Target), Speed, DeltaTime)
end

function AxiomX.SmoothPulse(Start: number, End: number, Fade: number, Value: number): number
	if End <= Start or Fade <= 0 then return if Value >= Start and Value <= End then 1 else 0 end
	return AxiomX.SmoothStep(Start, Start + Fade, Value) * (1 - AxiomX.SmoothStep(End - Fade, End, Value))
end

function AxiomX.SmoothDamp(Current: number, Target: number, CurrentVelocity: number, SmoothTime: number, DeltaTime: number, MaxSpeed: number?): (number, number)
	if DeltaTime <= 0 or not finite(DeltaTime) then return Current, CurrentVelocity end
	local Duration = math.max(0.0001, SmoothTime)
	local Omega = 2 / Duration
	local X = Omega * DeltaTime
	local Decay = 1 / (1 + X + 0.48 * X * X + 0.235 * X * X * X)
	local Delta = Current - Target
	local Limit = math.max(0, MaxSpeed or HUGE) * Duration
	Delta = math.clamp(Delta, -Limit, Limit)
	local Adjusted = Current - Delta
	local Temp = (CurrentVelocity + Omega * Delta) * DeltaTime
	local NewVelocity = (CurrentVelocity - Omega * Temp) * Decay
	local Value = Adjusted + (Delta + Temp) * Decay
	if (Target - Current > 0) == (Value > Target) then return Target, 0 end
	return Value, NewVelocity
end

function AxiomX.SmoothDampAngle(Current: number, Target: number, CurrentVelocity: number, SmoothTime: number, DeltaTime: number, MaxSpeed: number?): (number, number)
	return AxiomX.SmoothDamp(Current, Current + AxiomX.DeltaAngle(Current, Target), CurrentVelocity, SmoothTime, DeltaTime, MaxSpeed)
end

function AxiomX.QuadraticBezier(A: number, B: number, C: number, Alpha: number): number
	local U = 1 - Alpha
	return U * U * A + 2 * U * Alpha * B + Alpha * Alpha * C
end

function AxiomX.CubicBezier(A: number, B: number, C: number, D: number, Alpha: number): number
	local U = 1 - Alpha
	return U * U * U * A + 3 * U * U * Alpha * B + 3 * U * Alpha * Alpha * C + Alpha * Alpha * Alpha * D
end

function AxiomX.Hermite(A: number, TangentA: number, B: number, TangentB: number, Alpha: number): number
	local T2 = Alpha * Alpha
	local T3 = T2 * Alpha
	return (2 * T3 - 3 * T2 + 1) * A + (T3 - 2 * T2 + Alpha) * TangentA + (-2 * T3 + 3 * T2) * B + (T3 - T2) * TangentB
end

function AxiomX.ClampFinite(Value: number, Minimum: number, Maximum: number, Fallback: number?): number
	return if finite(Value) then math.clamp(Value, Minimum, Maximum) else (Fallback or Minimum)
end

-- Advanced vector, orientation and interpolation operations.
function AxiomX.VectorMagnitudeSquared(V: Vector3): number
	return V:Dot(V)
end

function AxiomX.VectorNearlyEqual(A: Vector3, B: Vector3, Tolerance: number?): boolean
	local Distance = A - B
	local E = Tolerance or 1e-5
	return Distance:Dot(Distance) <= E * E
end

function AxiomX.ClampMagnitude(V: Vector3, Maximum: number): Vector3
	if Maximum <= 0 then return ZERO end
	local LengthSquared = V:Dot(V)
	return if LengthSquared > Maximum * Maximum then V * (Maximum / math.sqrt(LengthSquared)) else V
end

function AxiomX.FlattenOnPlane(V: Vector3, Normal: Vector3): Vector3
	local N = unit(Normal)
	return if N ~= ZERO then V - N * V:Dot(N) else V
end

function AxiomX.Perpendicular(V: Vector3): Vector3
	local N = unit(V)
	if N == ZERO then return Vector3.xAxis end
	local Axis = if math.abs(N.Y) < 0.9 then UP else Vector3.xAxis
	return unit(N:Cross(Axis))
end

function AxiomX.OrthonormalBasis(Forward: Vector3, Up: Vector3?): (Vector3, Vector3, Vector3)
	local F = unit(Forward)
	if F == ZERO then F = -Vector3.zAxis end
	local ProposedUp = unit(Up or UP)
	if ProposedUp == ZERO then ProposedUp = UP end
	local R = unit(F:Cross(ProposedUp))
	if R == ZERO then R = AxiomX.Perpendicular(F) end
	local U = unit(R:Cross(F))
	return R, U, F
end

function AxiomX.SlerpUnit(A: Vector3, B: Vector3, Alpha: number): Vector3
	local U = unit(A)
	local V = unit(B)
	if U == ZERO or V == ZERO then return unit(U + (V - U) * Alpha) end
	local Dot = math.clamp(U:Dot(V), -1, 1)
	if Dot > 0.9995 then return unit(U + (V - U) * Alpha) end
	if Dot < -0.9995 then return AxiomX.RotateAroundAxis(U, AxiomX.Perpendicular(U), 180 * Alpha) end
	local Angle = math.acos(Dot)
	local Denominator = math.sin(Angle)
	return unit((U * math.sin((1 - Alpha) * Angle) + V * math.sin(Alpha * Angle)) / Denominator)
end

function AxiomX.SlerpVector(A: Vector3, B: Vector3, Alpha: number): Vector3
	local Magnitude = A.Magnitude + (B.Magnitude - A.Magnitude) * Alpha
	return AxiomX.SlerpUnit(A, B, Alpha) * Magnitude
end

function AxiomX.RotateTowardsVector(Current: Vector3, Target: Vector3, MaximumDegrees: number): Vector3
	local A = unit(Current)
	local B = unit(Target)
	if A == ZERO or B == ZERO then return Current end
	local Angle = AxiomX.AngleBetween(A, B)
	return AxiomX.SlerpUnit(A, B, if Angle > EPS then math.clamp(MaximumDegrees / Angle, 0, 1) else 1) * Current.Magnitude
end

function AxiomX.VectorQuadraticBezier(A: Vector3, B: Vector3, C: Vector3, Alpha: number): Vector3
	local U = 1 - Alpha
	return U * U * A + 2 * U * Alpha * B + Alpha * Alpha * C
end

function AxiomX.VectorCubicBezier(A: Vector3, B: Vector3, C: Vector3, D: Vector3, Alpha: number): Vector3
	local U = 1 - Alpha
	return U * U * U * A + 3 * U * U * Alpha * B + 3 * U * Alpha * Alpha * C + Alpha * Alpha * Alpha * D
end

function AxiomX.VectorCubicBezierDerivative(A: Vector3, B: Vector3, C: Vector3, D: Vector3, Alpha: number): Vector3
	local U = 1 - Alpha
	return 3 * U * U * (B - A) + 6 * U * Alpha * (C - B) + 3 * Alpha * Alpha * (D - C)
end

function AxiomX.VectorHermite(A: Vector3, TangentA: Vector3, B: Vector3, TangentB: Vector3, Alpha: number): Vector3
	local T2 = Alpha * Alpha
	local T3 = T2 * Alpha
	return (2 * T3 - 3 * T2 + 1) * A + (T3 - 2 * T2 + Alpha) * TangentA + (-2 * T3 + 3 * T2) * B + (T3 - T2) * TangentB
end

function AxiomX.SmoothDampVector(Current: Vector3, Target: Vector3, CurrentVelocity: Vector3, SmoothTime: number, DeltaTime: number, MaxSpeed: number?): (Vector3, Vector3)
	if DeltaTime <= 0 or not finite(DeltaTime) then return Current, CurrentVelocity end
	local Duration = math.max(0.0001, SmoothTime)
	local Omega = 2 / Duration
	local X = Omega * DeltaTime
	local Decay = 1 / (1 + X + 0.48 * X * X + 0.235 * X * X * X)
	local Delta = AxiomX.ClampMagnitude(Current - Target, math.max(0, MaxSpeed or HUGE) * Duration)
	local Adjusted = Current - Delta
	local Temp = (CurrentVelocity + Omega * Delta) * DeltaTime
	local Velocity = (CurrentVelocity - Omega * Temp) * Decay
	local Value = Adjusted + (Delta + Temp) * Decay
	if (Target - Current):Dot(Value - Target) > 0 then return Target, ZERO end
	return Value, Velocity
end

function AxiomX.LerpCFrame(A: CFrame, B: CFrame, Alpha: number): CFrame
	return A:Lerp(B, Alpha)
end

function AxiomX.LookAlongSafe(Origin: Vector3, Forward: Vector3, Up: Vector3?): CFrame
	local F = unit(Forward)
	return if F ~= ZERO then AxiomX.LookAtSafe(Origin, Origin + F, Up) else CFrame.new(Origin)
end

function AxiomX.AlignToNormal(Position: Vector3, Normal: Vector3, Forward: Vector3?): CFrame
	local N = unit(Normal)
	if N == ZERO then return CFrame.new(Position) end
	local Look = unit(AxiomX.FlattenOnPlane(Forward or -Vector3.zAxis, N))
	if Look == ZERO then Look = AxiomX.Perpendicular(N) end
	return CFrame.lookAt(Position, Position + Look, N)
end

-- Pure geometry: no world queries; tuple returns do not create Lua result tables.
function AxiomX.ClosestPointOnAABB(Point: Vector3, Center: Vector3, Size: Vector3): Vector3
	if Size.X < 0 or Size.Y < 0 or Size.Z < 0 then return Center end
	local Half = Size * 0.5
	return Center + Vector3.new(math.clamp(Point.X - Center.X, -Half.X, Half.X), math.clamp(Point.Y - Center.Y, -Half.Y, Half.Y), math.clamp(Point.Z - Center.Z, -Half.Z, Half.Z))
end

function AxiomX.ClosestPointOnBox(Point: Vector3, Box: CFrame, Size: Vector3): Vector3
	return Box:PointToWorldSpace(AxiomX.ClosestPointOnAABB(Box:PointToObjectSpace(Point), ZERO, Size))
end

function AxiomX.DistanceToBox(Point: Vector3, Box: CFrame, Size: Vector3): number
	return (Point - AxiomX.ClosestPointOnBox(Point, Box, Size)).Magnitude
end

function AxiomX.PointInCapsule(Point: Vector3, A: Vector3, B: Vector3, Radius: number): boolean
	if Radius < 0 then return false end
	local Delta = Point - AxiomX.ClosestPointOnSegment(Point, A, B)
	return Delta:Dot(Delta) <= Radius * Radius
end

function AxiomX.CapsuleSphereOverlap(A: Vector3, B: Vector3, CapsuleRadius: number, Center: Vector3, SphereRadius: number): boolean
	if CapsuleRadius < 0 or SphereRadius < 0 then return false end
	return AxiomX.PointInCapsule(Center, A, B, CapsuleRadius + SphereRadius)
end

function AxiomX.PointInCylinder(Point: Vector3, Center: Vector3, Axis: Vector3, Radius: number, HalfHeight: number): boolean
	if Radius < 0 or HalfHeight < 0 then return false end
	local N = unit(Axis)
	if N == ZERO then return false end
	local Delta = Point - Center
	local Vertical = Delta:Dot(N)
	local Radial = Delta - N * Vertical
	return math.abs(Vertical) <= HalfHeight and Radial:Dot(Radial) <= Radius * Radius
end

function AxiomX.SignedDistanceToPlane(Point: Vector3, PlanePoint: Vector3, PlaneNormal: Vector3): number
	return (Point - PlanePoint):Dot(unit(PlaneNormal))
end

function AxiomX.RayPlaneIntersection(Origin: Vector3, Direction: Vector3, PlanePoint: Vector3, PlaneNormal: Vector3): (Vector3?, number?)
	local Denominator = Direction:Dot(PlaneNormal)
	if math.abs(Denominator) <= EPS then return nil, nil end
	local T = (PlanePoint - Origin):Dot(PlaneNormal) / Denominator
	if T < 0 or not finite(T) then return nil, nil end
	return Origin + Direction * T, T
end

function AxiomX.SegmentPlaneIntersection(A: Vector3, B: Vector3, PlanePoint: Vector3, PlaneNormal: Vector3): (Vector3?, number?)
	local Position, T = AxiomX.RayPlaneIntersection(A, B - A, PlanePoint, PlaneNormal)
	if T ~= nil and T <= 1 then return Position, T end
	return nil, nil
end

function AxiomX.RaySphereIntersection(Origin: Vector3, Direction: Vector3, Center: Vector3, Radius: number): (Vector3?, number?)
	if Radius < 0 or not finite(Radius) or not AxiomX.IsFiniteVector(Origin) or not AxiomX.IsFiniteVector(Direction) or not AxiomX.IsFiniteVector(Center) then return nil, nil end
	local A = Direction:Dot(Direction)
	if A <= EPS * EPS or not finite(A) then return nil, nil end
	local Difference = Origin - Center
	local B = 2 * Difference:Dot(Direction)
	local C = Difference:Dot(Difference) - Radius * Radius
	local Discriminant = B * B - 4 * A * C
	if Discriminant < 0 or not finite(Discriminant) then return nil, nil end
	local Root = math.sqrt(Discriminant)
	local First = (-B - Root) / (2 * A)
	local Second = (-B + Root) / (2 * A)
	local T = if First >= 0 then First else Second
	if T < 0 or not finite(T) then return nil, nil end
	return Origin + Direction * T, T
end

function AxiomX.SegmentSphereIntersection(A: Vector3, B: Vector3, Center: Vector3, Radius: number): (Vector3?, number?)
	local Position, T = AxiomX.RaySphereIntersection(A, B - A, Center, Radius)
	if T ~= nil and T <= 1 then return Position, T end
	return nil, nil
end

function AxiomX.RayAABBIntersection(Origin: Vector3, Direction: Vector3, Center: Vector3, Size: Vector3): (Vector3?, number?)
	if not AxiomX.IsFiniteVector(Origin) or not AxiomX.IsFiniteVector(Direction) or not AxiomX.IsFiniteVector(Center) or not AxiomX.IsFiniteVector(Size) then return nil, nil end
	if Size.X < 0 or Size.Y < 0 or Size.Z < 0 then return nil, nil end
	local Lower = Center - Size * 0.5
	local Upper = Center + Size * 0.5
	local Near = -HUGE
	local Far = HUGE
	local Ox, Oy, Oz = Origin.X, Origin.Y, Origin.Z
	local Dx, Dy, Dz = Direction.X, Direction.Y, Direction.Z
	if math.abs(Dx) <= EPS then
		if Ox < Lower.X or Ox > Upper.X then return nil, nil end
	else
		local A = (Lower.X - Ox) / Dx
		local B = (Upper.X - Ox) / Dx
		Near = math.max(Near, math.min(A, B))
		Far = math.min(Far, math.max(A, B))
	end
	if math.abs(Dy) <= EPS then
		if Oy < Lower.Y or Oy > Upper.Y then return nil, nil end
	else
		local A = (Lower.Y - Oy) / Dy
		local B = (Upper.Y - Oy) / Dy
		Near = math.max(Near, math.min(A, B))
		Far = math.min(Far, math.max(A, B))
	end
	if math.abs(Dz) <= EPS then
		if Oz < Lower.Z or Oz > Upper.Z then return nil, nil end
	else
		local A = (Lower.Z - Oz) / Dz
		local B = (Upper.Z - Oz) / Dz
		Near = math.max(Near, math.min(A, B))
		Far = math.min(Far, math.max(A, B))
	end
	if Near > Far or Far < 0 then return nil, nil end
	local T = math.max(0, Near)
	if T == 0 and Direction:Dot(Direction) <= EPS * EPS then return nil, nil end
	return Origin + Direction * T, T
end

function AxiomX.RayBoxIntersection(Origin: Vector3, Direction: Vector3, Box: CFrame, Size: Vector3): (Vector3?, number?)
	local Position, T = AxiomX.RayAABBIntersection(Box:PointToObjectSpace(Origin), Box:VectorToObjectSpace(Direction), ZERO, Size)
	return if Position then Box:PointToWorldSpace(Position) else nil, T
end

function AxiomX.TriangleNormal(A: Vector3, B: Vector3, C: Vector3): Vector3
	return unit((B - A):Cross(C - A))
end

function AxiomX.TriangleArea(A: Vector3, B: Vector3, C: Vector3): number
	return 0.5 * ((B - A):Cross(C - A)).Magnitude
end

function AxiomX.Barycentric(Point: Vector3, A: Vector3, B: Vector3, C: Vector3): (number?, number?, number?)
	local V0 = B - A
	local V1 = C - A
	local V2 = Point - A
	local D00 = V0:Dot(V0)
	local D01 = V0:Dot(V1)
	local D11 = V1:Dot(V1)
	local D20 = V2:Dot(V0)
	local D21 = V2:Dot(V1)
	local Denominator = D00 * D11 - D01 * D01
	if math.abs(Denominator) <= EPS * EPS then return nil, nil, nil end
	local V = (D11 * D20 - D01 * D21) / Denominator
	local W = (D00 * D21 - D01 * D20) / Denominator
	return 1 - V - W, V, W
end

function AxiomX.PointInTriangle(Point: Vector3, A: Vector3, B: Vector3, C: Vector3, Tolerance: number?): boolean
	local N = AxiomX.TriangleNormal(A, B, C)
	if N == ZERO or math.abs((Point - A):Dot(N)) > (Tolerance or 1e-5) then return false end
	local U, V, W = AxiomX.Barycentric(Point, A, B, C)
	return U ~= nil and V ~= nil and W ~= nil and U >= -EPS and V >= -EPS and W >= -EPS
end

-- Engine operations (WorldRoot). Pass reusable Params for hot paths.
function AxiomX.SetRaycastFilters(Params: RaycastParams, Include: {Instance}?, Exclude: {Instance}?)
	Params.IncludeInstances = Include
	Params.ExcludeInstances = Exclude
end

function AxiomX.SetOverlapFilters(Params: OverlapParams, Include: {Instance}?, Exclude: {Instance}?)
	Params.IncludeInstances = Include
	Params.ExcludeInstances = Exclude
end

function AxiomX.CastSphereDisplacement(Origin: Vector3, Radius: number, Displacement: Vector3, Params: RaycastParams?): RaycastResult?
	local Length = Displacement.Magnitude
	if not finite(Radius) or Radius <= 0 or Radius > AxiomX.MaxSphereRadius or Length <= EPS or Length > AxiomX.MaxSweepDistance or not finite(Length) or not AxiomX.IsFiniteVector(Origin) then return nil end
	return Workspace:Spherecast(Origin, Radius, Displacement, Params)
end

function AxiomX.CastBlockDisplacement(Box: CFrame, Size: Vector3, Displacement: Vector3, Params: RaycastParams?): RaycastResult?
	local Length = Displacement.Magnitude
	if not AxiomX.IsFiniteVector(Size) or Size.X <= 0 or Size.Y <= 0 or Size.Z <= 0 or Size.X > 512 or Size.Y > 512 or Size.Z > 512 then return nil end
	if Length <= EPS or Length > AxiomX.MaxSweepDistance or not finite(Length) or not AxiomX.IsFiniteVector(Box.Position) then return nil end
	return Workspace:Blockcast(Box, Size, Displacement, Params)
end

function AxiomX.CastShape(Part: BasePart, Direction: Vector3, Distance: number?, Params: RaycastParams?, CFrameOverride: CFrame?, SizeOverride: Vector3?): RaycastResult?
	if SizeOverride and (not AxiomX.IsFiniteVector(SizeOverride) or SizeOverride.X < 0 or SizeOverride.Y < 0 or SizeOverride.Z < 0 or SizeOverride.X > 512 or SizeOverride.Y > 512 or SizeOverride.Z > 512) then return nil end
	local Displacement = scalarRay(Direction, Distance, AxiomX.MaxSweepDistance)
	return if Displacement then Workspace:Shapecast(Part, Displacement, Params, CFrameOverride, SizeOverride) else nil
end

function AxiomX.CastShapeDisplacement(Part: BasePart, Displacement: Vector3, Params: RaycastParams?, CFrameOverride: CFrame?, SizeOverride: Vector3?): RaycastResult?
	local Length = Displacement.Magnitude
	if Length <= EPS or Length > AxiomX.MaxSweepDistance or not finite(Length) then return nil end
	if SizeOverride and (not AxiomX.IsFiniteVector(SizeOverride) or SizeOverride.X < 0 or SizeOverride.Y < 0 or SizeOverride.Z < 0 or SizeOverride.X > 512 or SizeOverride.Y > 512 or SizeOverride.Z > 512) then return nil end
	return Workspace:Shapecast(Part, Displacement, Params, CFrameOverride, SizeOverride)
end

function AxiomX.CastRayTo(Origin: Vector3, Target: Vector3, Params: RaycastParams?): RaycastResult?
	return AxiomX.Raycast(Origin, Target - Origin, Params)
end

function AxiomX.GetGroundSphere(Origin: Vector3, Radius: number, Distance: number?, Params: RaycastParams?): RaycastResult?
	return AxiomX.CastSphere(Origin, Radius, -UP, Distance, Params)
end

function AxiomX.GetGroundBlock(Box: CFrame, Size: Vector3, Distance: number?, Params: RaycastParams?): RaycastResult?
	return AxiomX.CastBlock(Box, Size, -UP, Distance, Params)
end

function AxiomX.IsGrounded(Origin: Vector3, Distance: number, MaxSlopeDegrees: number?, Params: RaycastParams?): boolean
	local Hit = AxiomX.GetGroundHit(Origin, Distance, Params)
	return Hit ~= nil and Hit.Normal:Dot(UP) >= math.cos(math.rad(math.clamp(MaxSlopeDegrees or 90, 0, 180)))
end

function AxiomX.GetImpactFromResult(Result: RaycastResult, IncomingDirection: Vector3): ImpactData?
	local D = unit(IncomingDirection)
	if D == ZERO then return nil end
	local N = Result.Normal
	local Incidence = math.clamp(-D:Dot(N), -1, 1)
	return {
		Result = Result,
		Instance = Result.Instance,
		Material = Result.Material,
		Position = Result.Position,
		Normal = N,
		Distance = Result.Distance,
		Angle = math.deg(math.acos(Incidence)),
		SlopeAngle = math.deg(math.acos(math.clamp(N:Dot(UP), -1, 1))),
		Reflection = D - 2 * D:Dot(N) * N,
	}
end

function AxiomX.GetSurfaceFrame(Result: RaycastResult, PreferredForward: Vector3?): CFrame
	return AxiomX.AlignToNormal(Result.Position, Result.Normal, PreferredForward)
end

function AxiomX.GetPartCentersInRadius(Center: Vector3, Radius: number, Params: OverlapParams?): {BasePart}
	local Candidates = AxiomX.GetPartsInRadius(Center, Radius, Params)
	local RadiusSquared = Radius * Radius
	local Count = #Candidates
	local Write = 1
	for Index = 1, Count do
		local Part = Candidates[Index]
		local Difference = Part.Position - Center
		if Difference:Dot(Difference) <= RadiusSquared then
			Candidates[Write] = Part
			Write += 1
		end
	end
	for Index = Write, Count do Candidates[Index] = nil end
	return Candidates
end

function AxiomX.GetPartCentersInCone(Apex: Vector3, Forward: Vector3, HalfAngleDegrees: number, Radius: number, Params: OverlapParams?): {BasePart}
	if not finite(HalfAngleDegrees) or HalfAngleDegrees < 0 or HalfAngleDegrees > 180 or not finite(Radius) or Radius <= 0 then return {} end
	local Direction = unit(Forward)
	if Direction == ZERO then return {} end
	local Candidates = AxiomX.GetPartsInRadius(Apex, Radius, Params)
	local Threshold = math.cos(math.rad(HalfAngleDegrees))
	local LimitSquared = Radius * Radius
	local Count = #Candidates
	local Write = 1
	for Index = 1, Count do
		local Part = Candidates[Index]
		local Delta = Part.Position - Apex
		local Squared = Delta:Dot(Delta)
		if Squared <= LimitSquared and (Squared <= EPS * EPS or Delta:Dot(Direction) >= math.sqrt(Squared) * Threshold) then
			Candidates[Write] = Part
			Write += 1
		end
	end
	for Index = Write, Count do Candidates[Index] = nil end
	return Candidates
end

-- Ballistic extensions. Drag is nonnegative linear drag coefficient (per second).
function AxiomX.ProjectileVelocityDrag(Velocity: Vector3, Time: number, Drag: number, Gravity: Vector3?): Vector3
	local G = gravityVector(Gravity)
	if Drag <= EPS then return Velocity + G * Time end
	local Decay = math.exp(-Drag * Time)
	return Velocity * Decay + G * ((1 - Decay) / Drag)
end

function AxiomX.ProjectilePositionDrag(Origin: Vector3, Velocity: Vector3, Time: number, Drag: number, Gravity: Vector3?): Vector3
	local G = gravityVector(Gravity)
	if Drag <= EPS then return Origin + Velocity * Time + G * (0.5 * Time * Time) end
	local Factor = (1 - math.exp(-Drag * Time)) / Drag
	return Origin + Velocity * Factor + G * ((Time - Factor) / Drag)
end

function AxiomX.GetApexTime(InitialVerticalSpeed: number, Gravity: number?): number?
	local G = Gravity or Workspace.Gravity
	return if finite(G) and G > EPS and InitialVerticalSpeed > 0 then InitialVerticalSpeed / G else nil
end

function AxiomX.GetMaximumHeight(StartY: number, InitialVerticalSpeed: number, Gravity: number?): number?
	local G = Gravity or Workspace.Gravity
	return if finite(G) and G > EPS then StartY + math.max(InitialVerticalSpeed, 0) ^ 2 / (2 * G) else nil
end

function AxiomX.SampleProjectilePath(Origin: Vector3, Velocity: Vector3, Duration: number, Steps: number, Gravity: Vector3?): {Vector3}
	if Duration < 0 or not finite(Duration) or Steps < 1 or Steps > AxiomX.MaxTrajectorySteps or Steps % 1 ~= 0 then return {} end
	local Points = table.create(Steps + 1)
	local G = gravityVector(Gravity)
	for Index = 0, Steps do
		local Time = Duration * Index / Steps
		Points[Index + 1] = Origin + Velocity * Time + G * (0.5 * Time * Time)
	end
	return Points
end

function AxiomX.TraceProjectileSphere(Origin: Vector3, Velocity: Vector3, Radius: number, Duration: number, Steps: number, Params: RaycastParams?, Gravity: Vector3?): ProjectileHit?
	if not finite(Radius) or Radius <= 0 or Radius > AxiomX.MaxSphereRadius or Duration <= 0 or not finite(Duration) or Steps < 1 or Steps > AxiomX.MaxTrajectorySteps or Steps % 1 ~= 0 then return nil end
	if not AxiomX.IsFiniteVector(Origin) or not AxiomX.IsFiniteVector(Velocity) then return nil end
	local G = gravityVector(Gravity)
	if not AxiomX.IsFiniteVector(G) then return nil end
	local DeltaTime = Duration / Steps
	local Previous = Origin
	for Index = 1, Steps do
		local Time = Index * DeltaTime
		local Next = Origin + Velocity * Time + G * (0.5 * Time * Time)
		local Segment = Next - Previous
		local Length = Segment.Magnitude
		if Length > AxiomX.MaxSweepDistance then return nil end
		if Length > EPS then
			local Hit = Workspace:Spherecast(Previous, Radius, Segment, Params)
			if Hit then
				local HitTime = (Index - 1) * DeltaTime + DeltaTime * math.clamp(Hit.Distance / Length, 0, 1)
				return {Result = Hit, Position = Hit.Position, Velocity = Velocity + G * HitTime, Time = HitTime}
			end
		end
		Previous = Next
	end
	return nil
end

local function interceptResidual(Delta: Vector3, TargetVelocity: Vector3, TargetAcceleration: Vector3, ProjectileSpeed: number, Time: number): number
	local Offset = Delta + TargetVelocity * Time + TargetAcceleration * (0.5 * Time * Time)
	return Offset.Magnitude - ProjectileSpeed * Time
end

function AxiomX.PredictInterceptAcceleration(Origin: Vector3, TargetPosition: Vector3, TargetVelocity: Vector3, TargetAcceleration: Vector3, ProjectileSpeed: number, MaxTime: number?, Iterations: number?): (Vector3?, number?)
	if ProjectileSpeed <= EPS or not finite(ProjectileSpeed) then return nil, nil end
	local TMax = MaxTime or 30
	if TMax <= 0 or not finite(TMax) then return nil, nil end
	local Delta = TargetPosition - Origin
	-- Find the first positive root with a bounded scan; avoids selecting an unrelated later intercept.
	local PriorTime = 0
	local PriorValue = interceptResidual(Delta, TargetVelocity, TargetAcceleration, ProjectileSpeed, 0)
	if PriorValue <= EPS then return TargetPosition, 0 end
	local RootLow = 0
	local RootHigh = 0
	local Count = math.floor(math.clamp(Iterations or 64, 4, 256))
	for Index = 1, Count do
		local Candidate = TMax * Index / Count
		local Value = interceptResidual(Delta, TargetVelocity, TargetAcceleration, ProjectileSpeed, Candidate)
		if Value <= 0 and PriorValue > 0 then RootLow = PriorTime; RootHigh = Candidate; break end
		PriorTime = Candidate
		PriorValue = Value
	end
	if RootHigh == 0 then return nil, nil end
	for _ = 1, 28 do
		local Mid = (RootLow + RootHigh) * 0.5
		if interceptResidual(Delta, TargetVelocity, TargetAcceleration, ProjectileSpeed, Mid) > 0 then RootLow = Mid else RootHigh = Mid end
	end
	local T = RootHigh
	return TargetPosition + TargetVelocity * T + TargetAcceleration * (0.5 * T * T), T
end


-- AxiomX v4 hot-path kernel: these pure helpers construct no Lua tables or Instances.
-- Vector3/CFrame are native value types; engine APIs and caller-supplied tables have their own costs.
function AxiomX.FastDistanceSquared(A: Vector3, B: Vector3): number
	local DX = B.X - A.X
	local DY = B.Y - A.Y
	local DZ = B.Z - A.Z
	return DX * DX + DY * DY + DZ * DZ
end

function AxiomX.FastDistanceSquaredXZ(A: Vector3, B: Vector3): number
	local DX = B.X - A.X
	local DZ = B.Z - A.Z
	return DX * DX + DZ * DZ
end

function AxiomX.FastMagnitudeSquared(V: Vector3): number
	return V.X * V.X + V.Y * V.Y + V.Z * V.Z
end

function AxiomX.FastMagnitudeSquaredXZ(V: Vector3): number
	return V.X * V.X + V.Z * V.Z
end

function AxiomX.WithinDistance(A: Vector3, B: Vector3, Radius: number): boolean
	if not finite(Radius) or Radius < 0 then return false end
	return AxiomX.FastDistanceSquared(A, B) <= Radius * Radius
end

function AxiomX.WithinDistanceXZ(A: Vector3, B: Vector3, Radius: number): boolean
	if not finite(Radius) or Radius < 0 then return false end
	return AxiomX.FastDistanceSquaredXZ(A, B) <= Radius * Radius
end

function AxiomX.FastNormalDot(Direction: Vector3, Normal: Vector3): number
	return Direction:Dot(Normal)
end

function AxiomX.FastAngleDegrees(A: Vector3, B: Vector3): number
	local ASquared = A:Dot(A)
	local BSquared = B:Dot(B)
	if ASquared <= EPS * EPS or BSquared <= EPS * EPS or not finite(ASquared) or not finite(BSquared) then return 0 end
	local Cosine = math.clamp(A:Dot(B) / math.sqrt(ASquared * BSquared), -1, 1)
	return math.deg(math.acos(Cosine))
end

function AxiomX.FastImpactAngle(Direction: Vector3, SurfaceNormal: Vector3): number
	local D = unit(Direction)
	local N = unit(SurfaceNormal)
	return if D ~= ZERO and N ~= ZERO then math.deg(math.acos(math.clamp(-D:Dot(N), -1, 1))) else 0
end

function AxiomX.FastSlopeAngle(Normal: Vector3): number
	local N = unit(Normal)
	return if N ~= ZERO then math.deg(math.acos(math.clamp(N.Y, -1, 1))) else 0
end

function AxiomX.IsWalkableNormal(Normal: Vector3, MaximumSlopeDegrees: number): boolean
	if not finite(MaximumSlopeDegrees) or MaximumSlopeDegrees < 0 or MaximumSlopeDegrees > 90 then return false end
	local N = unit(Normal)
	return N ~= ZERO and N.Y >= math.cos(math.rad(MaximumSlopeDegrees))
end

function AxiomX.FastReflect(Direction: Vector3, Normal: Vector3): Vector3
	local N = unit(Normal)
	return if N ~= ZERO then Direction - N * (2 * Direction:Dot(N)) else Direction
end

function AxiomX.FastDampFactor(Speed: number, DeltaTime: number): number
	if not finite(Speed) or not finite(DeltaTime) or Speed <= 0 or DeltaTime <= 0 then return 0 end
	return 1 - math.exp(-Speed * DeltaTime)
end

function AxiomX.FastDampScalar(Current: number, Target: number, Speed: number, DeltaTime: number): number
	return Current + (Target - Current) * AxiomX.FastDampFactor(Speed, DeltaTime)
end

function AxiomX.FastDampVector(Current: Vector3, Target: Vector3, Speed: number, DeltaTime: number): Vector3
	return Current + (Target - Current) * AxiomX.FastDampFactor(Speed, DeltaTime)
end

function AxiomX.FastClosestSegmentParameter(Point: Vector3, A: Vector3, B: Vector3): number
	local Direction = B - A
	local Squared = Direction:Dot(Direction)
	if Squared <= EPS * EPS or not finite(Squared) then return 0 end
	return math.clamp((Point - A):Dot(Direction) / Squared, 0, 1)
end

function AxiomX.FastPointSegmentDistanceSquared(Point: Vector3, A: Vector3, B: Vector3): number
	local Direction = B - A
	local Squared = Direction:Dot(Direction)
	if Squared <= EPS * EPS or not finite(Squared) then
		local Delta = Point - A
		return Delta:Dot(Delta)
	end
	local Parameter = math.clamp((Point - A):Dot(Direction) / Squared, 0, 1)
	local Delta = Point - (A + Direction * Parameter)
	return Delta:Dot(Delta)
end

function AxiomX.FastSphereContains(Point: Vector3, Center: Vector3, Radius: number): boolean
	if Radius < 0 or not finite(Radius) then return false end
	return AxiomX.FastDistanceSquared(Point, Center) <= Radius * Radius
end

function AxiomX.FastCapsuleContains(Point: Vector3, A: Vector3, B: Vector3, Radius: number): boolean
	if Radius < 0 or not finite(Radius) then return false end
	return AxiomX.FastPointSegmentDistanceSquared(Point, A, B) <= Radius * Radius
end

function AxiomX.FastSphereOverlaps(A: Vector3, RadiusA: number, B: Vector3, RadiusB: number): boolean
	if RadiusA < 0 or RadiusB < 0 or not finite(RadiusA) or not finite(RadiusB) then return false end
	local Radius = RadiusA + RadiusB
	return AxiomX.FastDistanceSquared(A, B) <= Radius * Radius
end

function AxiomX.FastAABBContains(Point: Vector3, Center: Vector3, HalfSize: Vector3): boolean
	if HalfSize.X < 0 or HalfSize.Y < 0 or HalfSize.Z < 0 then return false end
	return math.abs(Point.X - Center.X) <= HalfSize.X and math.abs(Point.Y - Center.Y) <= HalfSize.Y and math.abs(Point.Z - Center.Z) <= HalfSize.Z
end

function AxiomX.FastAABBOverlaps(CenterA: Vector3, HalfA: Vector3, CenterB: Vector3, HalfB: Vector3): boolean
	if HalfA.X < 0 or HalfA.Y < 0 or HalfA.Z < 0 or HalfB.X < 0 or HalfB.Y < 0 or HalfB.Z < 0 then return false end
	return math.abs(CenterA.X - CenterB.X) <= HalfA.X + HalfB.X and math.abs(CenterA.Y - CenterB.Y) <= HalfA.Y + HalfB.Y and math.abs(CenterA.Z - CenterB.Z) <= HalfA.Z + HalfB.Z
end

function AxiomX.FastRayPlaneTime(Origin: Vector3, Direction: Vector3, PlanePoint: Vector3, PlaneNormal: Vector3): number?
	local Denominator = Direction:Dot(PlaneNormal)
	if not finite(Denominator) or math.abs(Denominator) <= EPS then return nil end
	local T = (PlanePoint - Origin):Dot(PlaneNormal) / Denominator
	return if finite(T) and T >= 0 then T else nil
end

function AxiomX.FastRaySphereTime(Origin: Vector3, Direction: Vector3, Center: Vector3, Radius: number): number?
	if Radius < 0 or not finite(Radius) then return nil end
	local A = Direction:Dot(Direction)
	if A <= EPS * EPS or not finite(A) then return nil end
	local Offset = Origin - Center
	local C = Offset:Dot(Offset) - Radius * Radius
	if C <= 0 then return 0 end
	local B = Offset:Dot(Direction)
	local D = B * B - A * C
	if D < 0 or not finite(D) then return nil end
	local T = (-B - math.sqrt(D)) / A
	return if T >= 0 and finite(T) then T else nil
end

function AxiomX.FastRayAABBTime(Origin: Vector3, Direction: Vector3, Center: Vector3, HalfSize: Vector3): number?
	if not AxiomX.IsFiniteVector(Origin) or not AxiomX.IsFiniteVector(Direction) or not AxiomX.IsFiniteVector(Center) or not AxiomX.IsFiniteVector(HalfSize) then return nil end
	if HalfSize.X < 0 or HalfSize.Y < 0 or HalfSize.Z < 0 or Direction:Dot(Direction) <= EPS * EPS then return nil end
	local Offset = Origin - Center
	local Near = -HUGE
	local Far = HUGE
	if math.abs(Direction.X) <= EPS then
		if math.abs(Offset.X) > HalfSize.X then return nil end
	else
		local A = (-HalfSize.X - Offset.X) / Direction.X
		local B = (HalfSize.X - Offset.X) / Direction.X
		Near = math.max(Near, math.min(A, B))
		Far = math.min(Far, math.max(A, B))
	end
	if math.abs(Direction.Y) <= EPS then
		if math.abs(Offset.Y) > HalfSize.Y then return nil end
	else
		local A = (-HalfSize.Y - Offset.Y) / Direction.Y
		local B = (HalfSize.Y - Offset.Y) / Direction.Y
		Near = math.max(Near, math.min(A, B))
		Far = math.min(Far, math.max(A, B))
	end
	if math.abs(Direction.Z) <= EPS then
		if math.abs(Offset.Z) > HalfSize.Z then return nil end
	else
		local A = (-HalfSize.Z - Offset.Z) / Direction.Z
		local B = (HalfSize.Z - Offset.Z) / Direction.Z
		Near = math.max(Near, math.min(A, B))
		Far = math.min(Far, math.max(A, B))
	end
	if Far < 0 or Near > Far then return nil end
	return math.max(0, Near)
end

function AxiomX.FastSegmentSphereTime(A: Vector3, B: Vector3, Center: Vector3, Radius: number): number?
	local Time = AxiomX.FastRaySphereTime(A, B - A, Center, Radius)
	return if Time ~= nil and Time <= 1 then Time else nil
end

function AxiomX.FastSegmentAABBTime(A: Vector3, B: Vector3, Center: Vector3, HalfSize: Vector3): number?
	local Time = AxiomX.FastRayAABBTime(A, B - A, Center, HalfSize)
	return if Time ~= nil and Time <= 1 then Time else nil
end

function AxiomX.FastProjectilePosition(Origin: Vector3, InitialVelocity: Vector3, Gravity: Vector3, Time: number): Vector3
	return Origin + InitialVelocity * Time + Gravity * (0.5 * Time * Time)
end

function AxiomX.FastProjectileVelocity(InitialVelocity: Vector3, Gravity: Vector3, Time: number): Vector3
	return InitialVelocity + Gravity * Time
end

-- Stateless, table-free query budget. Caller resets Used to 0 at its chosen frame/tick boundary.
function AxiomX.TryConsumeQueryBudget(Used: number, Maximum: number, Cost: number?): (boolean, number)
	local Price = Cost or 1
	if not finite(Used) or not finite(Maximum) or not finite(Price) or Used < 0 or Maximum < 0 or Price <= 0 then return false, Used end
	if Price > Maximum - Used then return false, Used end
	return true, Used + Price
end

-- Change existing query parameter objects, without constructing a fresh params object.
function AxiomX.SetRaycastShapeTuning(Params: RaycastParams, Margin: number?, SizeGradient: number?): boolean
	if Margin ~= nil and (not finite(Margin) or Margin < 0) then return false end
	if SizeGradient ~= nil and not finite(SizeGradient) then return false end
	if Margin ~= nil then Params.Margin = Margin end
	if SizeGradient ~= nil then Params.SizeGradient = SizeGradient end
	return true
end

-- Writable hit output: no newly created Lua table; callers allocate one table before looping.
local function clearImpact(Out: ImpactBuffer)
	Out.Result = nil
	Out.Instance = nil
	Out.Material = nil
	Out.Position = nil
	Out.Normal = nil
	Out.Distance = nil
	Out.Angle = nil
	Out.SlopeAngle = nil
	Out.Reflection = nil
end

local function fillImpact(Out: ImpactBuffer, Hit: RaycastResult, Unit: Vector3): boolean
	if Unit == ZERO then clearImpact(Out); return false end
	local Normal = Hit.Normal
	local Dot = Unit:Dot(Normal)
	Out.Result = Hit
	Out.Instance = Hit.Instance
	Out.Material = Hit.Material
	Out.Position = Hit.Position
	Out.Normal = Normal
	Out.Distance = Hit.Distance
	Out.Angle = math.deg(math.acos(math.clamp(-Dot, -1, 1)))
	Out.SlopeAngle = math.deg(math.acos(math.clamp(Normal.Y, -1, 1)))
	Out.Reflection = Unit - Normal * (2 * Dot)
	return true
end

function AxiomX.GetImpactDataInto(Origin: Vector3, Direction: Vector3, Distance: number?, Params: RaycastParams?, Out: ImpactBuffer): boolean
	local Unit = unit(Direction)
	local Length = Distance or AxiomX.RayLimit
	if Unit == ZERO or not AxiomX.IsFiniteVector(Origin) or not finite(Length) or Length <= 0 or Length > AxiomX.MaxRayDistance then
		clearImpact(Out)
		return false
	end
	local Hit = Workspace:Raycast(Origin, Unit * Length, Params)
	if not Hit then clearImpact(Out); return false end
	return fillImpact(Out, Hit, Unit)
end

function AxiomX.GetImpactFromResultInto(Hit: RaycastResult, Direction: Vector3, Out: ImpactBuffer): boolean
	return fillImpact(Out, Hit, unit(Direction))
end

function AxiomX.GetImpactAngleFromResult(Hit: RaycastResult, Direction: Vector3): number?
	local Unit = unit(Direction)
	return if Unit ~= ZERO then math.deg(math.acos(math.clamp(-Unit:Dot(Hit.Normal), -1, 1))) else nil
end

local function clearProjectile(Out: ProjectileBuffer)
	Out.Result = nil
	Out.Position = nil
	Out.Velocity = nil
	Out.Time = nil
end

function AxiomX.TraceProjectileInto(Origin: Vector3, Velocity: Vector3, Duration: number, Steps: number, Params: RaycastParams?, Gravity: Vector3?, Out: ProjectileBuffer): boolean
	local G = gravityVector(Gravity)
	if not finite(Duration) or Duration <= 0 or not finite(Steps) or Steps < 1 or Steps > AxiomX.MaxTrajectorySteps or Steps % 1 ~= 0 or not AxiomX.IsFiniteVector(Origin) or not AxiomX.IsFiniteVector(Velocity) or not AxiomX.IsFiniteVector(G) then
		clearProjectile(Out)
		return false
	end
	local Step = Duration / Steps
	local Previous = Origin
	for Index = 1, Steps do
		local Time = Index * Step
		local Next = Origin + Velocity * Time + G * (0.5 * Time * Time)
		local Segment = Next - Previous
		local LengthSquared = Segment:Dot(Segment)
		if not finite(LengthSquared) or LengthSquared > AxiomX.MaxRayDistance * AxiomX.MaxRayDistance then clearProjectile(Out); return false end
		if LengthSquared > EPS * EPS then
			local Hit = Workspace:Raycast(Previous, Segment, Params)
			if Hit then
				local HitTime = (Index - 1) * Step + Step * math.clamp(Hit.Distance / math.sqrt(LengthSquared), 0, 1)
				Out.Result = Hit
				Out.Position = Hit.Position
				Out.Velocity = Velocity + G * HitTime
				Out.Time = HitTime
				return true
			end
		end
		Previous = Next
	end
	clearProjectile(Out)
	return false
end

function AxiomX.TraceProjectileSphereInto(Origin: Vector3, Velocity: Vector3, Radius: number, Duration: number, Steps: number, Params: RaycastParams?, Gravity: Vector3?, Out: ProjectileBuffer): boolean
	local G = gravityVector(Gravity)
	if not finite(Radius) or Radius <= 0 or Radius > AxiomX.MaxSphereRadius or not finite(Duration) or Duration <= 0 or not finite(Steps) or Steps < 1 or Steps > AxiomX.MaxTrajectorySteps or Steps % 1 ~= 0 or not AxiomX.IsFiniteVector(Origin) or not AxiomX.IsFiniteVector(Velocity) or not AxiomX.IsFiniteVector(G) then
		clearProjectile(Out)
		return false
	end
	local Step = Duration / Steps
	local Previous = Origin
	for Index = 1, Steps do
		local Time = Index * Step
		local Next = Origin + Velocity * Time + G * (0.5 * Time * Time)
		local Segment = Next - Previous
		local LengthSquared = Segment:Dot(Segment)
		if not finite(LengthSquared) or LengthSquared > AxiomX.MaxSweepDistance * AxiomX.MaxSweepDistance then clearProjectile(Out); return false end
		if LengthSquared > EPS * EPS then
			local Hit = Workspace:Spherecast(Previous, Radius, Segment, Params)
			if Hit then
				local HitTime = (Index - 1) * Step + Step * math.clamp(Hit.Distance / math.sqrt(LengthSquared), 0, 1)
				Out.Result = Hit
				Out.Position = Hit.Position
				Out.Velocity = Velocity + G * HitTime
				Out.Time = HitTime
				return true
			end
		end
		Previous = Next
	end
	clearProjectile(Out)
	return false
end

-- Caller-owned table; table.clear preserves reserved array capacity for reuse.
function AxiomX.SampleProjectilePathInto(Origin: Vector3, Velocity: Vector3, Duration: number, Steps: number, Gravity: Vector3?, Out: {Vector3}): number
	table.clear(Out)
	if not finite(Duration) or Duration < 0 or not finite(Steps) or Steps < 1 or Steps > AxiomX.MaxTrajectorySteps or Steps % 1 ~= 0 then return 0 end
	local G = gravityVector(Gravity)
	if not AxiomX.IsFiniteVector(Origin) or not AxiomX.IsFiniteVector(Velocity) or not AxiomX.IsFiniteVector(G) then return 0 end
	for Index = 0, Steps do
		local Time = Duration * Index / Steps
		Out[Index + 1] = Origin + Velocity * Time + G * (0.5 * Time * Time)
	end
	return Steps + 1
end

-- WorldRoot overlap queries *always* create an engine result array. Into reuses your own table only.
function AxiomX.GetPartsInRadiusInto(Center: Vector3, Radius: number, Params: OverlapParams?, Out: {BasePart}): number
	table.clear(Out)
	if not finite(Radius) or Radius <= 0 or not AxiomX.IsFiniteVector(Center) then return 0 end
	local Parts = Workspace:GetPartBoundsInRadius(Center, Radius, Params)
	for Index = 1, #Parts do Out[Index] = Parts[Index] end
	return #Parts
end

function AxiomX.GetPartsInBoxInto(Box: CFrame, Size: Vector3, Params: OverlapParams?, Out: {BasePart}): number
	table.clear(Out)
	if not AxiomX.IsFiniteVector(Size) or Size.X <= 0 or Size.Y <= 0 or Size.Z <= 0 then return 0 end
	local Parts = Workspace:GetPartBoundsInBox(Box, Size, Params)
	for Index = 1, #Parts do Out[Index] = Parts[Index] end
	return #Parts
end

function AxiomX.MakeImpactBuffer(): ImpactBuffer
	local Buffer: ImpactBuffer = {Result = nil, Instance = nil, Material = nil, Position = nil, Normal = nil, Distance = nil, Angle = nil, SlopeAngle = nil, Reflection = nil}
	return Buffer
end

function AxiomX.MakeProjectileBuffer(): ProjectileBuffer
	local Buffer: ProjectileBuffer = {Result = nil, Position = nil, Velocity = nil, Time = nil}
	return Buffer
end

-- AxiomX Codec v5: fixed-schema quantized snapshots, allocated only by explicit constructors.
-- Bit layouts are little-endian within Roblox buffers (bit offsets start at zero).
-- The codec cannot losslessly compress arbitrary binary data. Never use it for exact currency, inventories, or security-sensitive state.
export type FullSnapshot = {
	Position: Vector3,
	Velocity: Vector3,
	Yaw: number,
	Pitch: number,
	Roll: number,
	TickMs: number,
	EntityId: number,
	Flags: number,
	Health: number,
	Sequence: number,
	Metadata: number,
}

export type PoseSnapshot = {Position: Vector3, Yaw: number, Pitch: number, Roll: number}
export type MotionSnapshot = {Position: Vector3, Velocity: Vector3}

local Codec = {}
Codec.Version = 1
Codec.PositionProfile = 1
Codec.PoseProfile = 2
Codec.MotionProfile = 3
Codec.FullProfile = 4
Codec.PositionBytes = 9
Codec.PoseBytes = 14
Codec.MotionBytes = 15
Codec.FullBytes = 30
Codec.PositionResolution = 0.01
Codec.VelocityResolution = 0.02

local function isUnsignedInteger(Value: number, Max: number): boolean
	return typeof(Value) == "number" and finite(Value) and Value >= 0 and Value <= Max and Value % 1 == 0
end

local function quantized(Value: number, InverseStep: number, Bits: number): number?
	if typeof(Value) ~= "number" or not finite(Value) then return nil end
	local Number = math.round(Value * InverseStep)
	local Limit = 2 ^ (Bits - 1)
	if Number < -Limit or Number >= Limit then return nil end
	return if Number < 0 then Number + 2 ^ Bits else Number
end

local function dequantized(Raw: number, Bits: number, Step: number): number
	local Limit = 2 ^ (Bits - 1)
	return (if Raw >= Limit then Raw - 2 ^ Bits else Raw) * Step
end

local function angleCode(Degrees: number, Bits: number): number?
	if typeof(Degrees) ~= "number" or not finite(Degrees) then return nil end
	local Count = 2 ^ Bits
	return math.floor(((Degrees + 180) % 360) * Count / 360 + 0.5) % Count
end

local function decodeAngle(Raw: number, Bits: number): number
	return Raw * 360 / (2 ^ Bits) - 180
end

local function validPosition(Position: Vector3): boolean
	return typeof(Position) == "Vector3" and AxiomX.IsFiniteVector(Position)
end

local function validPayload(Input: any, Length: number, Profile: number, PaddingOffset: number, PaddingBits: number): boolean
	return typeof(Input) == "buffer" and buffer.len(Input) == Length and buffer.readu8(Input, 0) == 0x50 + Profile and buffer.readbits(Input, PaddingOffset, PaddingBits) == 0
end

local function positionCodes(Position: Vector3): (number?, number?, number?)
	if not validPosition(Position) then return nil, nil, nil end
	return quantized(Position.X, 100, 21), quantized(Position.Y, 100, 21), quantized(Position.Z, 100, 21)
end

local function writePositionBits(Destination: buffer, X: number, Y: number, Z: number)
	buffer.writebits(Destination, 8, 21, X)
	buffer.writebits(Destination, 29, 21, Y)
	buffer.writebits(Destination, 50, 21, Z)
end

local function readPositionBits(Input: buffer): Vector3
	return Vector3.new(dequantized(buffer.readbits(Input, 8, 21), 21, 0.01), dequantized(buffer.readbits(Input, 29, 21), 21, 0.01), dequantized(buffer.readbits(Input, 50, 21), 21, 0.01))
end

function Codec.GetBytes(Profile: number): number?
	if Profile == Codec.PositionProfile then return 9 end
	if Profile == Codec.PoseProfile then return 14 end
	if Profile == Codec.MotionProfile then return 15 end
	if Profile == Codec.FullProfile then return 30 end
	return nil
end

function Codec.NewBuffer(Profile: number): buffer?
	local Length = Codec.GetBytes(Profile)
	return if Length then buffer.create(Length) else nil
end

function Codec.NewFullSnapshot(): FullSnapshot
	return {Position = ZERO, Velocity = ZERO, Yaw = 0, Pitch = 0, Roll = 0, TickMs = 0, EntityId = 0, Flags = 0, Health = 0, Sequence = 0, Metadata = 0}
end

function Codec.NewPoseSnapshot(): PoseSnapshot
	return {Position = ZERO, Yaw = 0, Pitch = 0, Roll = 0}
end

function Codec.NewMotionSnapshot(): MotionSnapshot
	return {Position = ZERO, Velocity = ZERO}
end

local function clearFull(Out: FullSnapshot)
	Out.Position = ZERO
	Out.Velocity = ZERO
	Out.Yaw = 0
	Out.Pitch = 0
	Out.Roll = 0
	Out.TickMs = 0
	Out.EntityId = 0
	Out.Flags = 0
	Out.Health = 0
	Out.Sequence = 0
	Out.Metadata = 0
end

local function clearPose(Out: PoseSnapshot)
	Out.Position = ZERO
	Out.Yaw = 0
	Out.Pitch = 0
	Out.Roll = 0
end

local function clearMotion(Out: MotionSnapshot)
	Out.Position = ZERO
	Out.Velocity = ZERO
end

-- Position: 8-bit version/profile, 3 x signed 21-bit coords, 1 reserved bit = 9 bytes.
function Codec.WritePositionInto(Destination: buffer, Position: Vector3): boolean
	if typeof(Destination) ~= "buffer" or buffer.len(Destination) ~= Codec.PositionBytes then return false end
	local X, Y, Z = positionCodes(Position)
	if X == nil or Y == nil or Z == nil then return false end
	buffer.writeu8(Destination, 0, 0x51)
	writePositionBits(Destination, X, Y, Z)
	buffer.writebits(Destination, 71, 1, 0)
	return true
end

function Codec.ReadPosition(Input: buffer): Vector3?
	if not validPayload(Input, 9, 1, 71, 1) then return nil end
	return readPositionBits(Input)
end

-- Pose: position, yaw (12 bits), pitch (11), roll (11), 7 reserved bits = 14 bytes.
function Codec.WritePoseInto(Destination: buffer, Snapshot: PoseSnapshot): boolean
	if typeof(Destination) ~= "buffer" or buffer.len(Destination) ~= Codec.PoseBytes or typeof(Snapshot) ~= "table" then return false end
	local X, Y, Z = positionCodes(Snapshot.Position)
	local Yaw = angleCode(Snapshot.Yaw, 12)
	local Pitch = angleCode(Snapshot.Pitch, 11)
	local Roll = angleCode(Snapshot.Roll, 11)
	if X == nil or Y == nil or Z == nil or Yaw == nil or Pitch == nil or Roll == nil then return false end
	buffer.writeu8(Destination, 0, 0x52)
	writePositionBits(Destination, X, Y, Z)
	buffer.writebits(Destination, 71, 12, Yaw)
	buffer.writebits(Destination, 83, 11, Pitch)
	buffer.writebits(Destination, 94, 11, Roll)
	buffer.writebits(Destination, 105, 7, 0)
	return true
end

function Codec.ReadPoseInto(Input: buffer, Out: PoseSnapshot): boolean
	if typeof(Out) ~= "table" then return false end
	if not validPayload(Input, 14, 2, 105, 7) then clearPose(Out); return false end
	Out.Position = readPositionBits(Input)
	Out.Yaw = decodeAngle(buffer.readbits(Input, 71, 12), 12)
	Out.Pitch = decodeAngle(buffer.readbits(Input, 83, 11), 11)
	Out.Roll = decodeAngle(buffer.readbits(Input, 94, 11), 11)
	return true
end

-- Motion: position + three signed 14-bit velocity components, 7 padding bits = 15 bytes.
function Codec.WriteMotionInto(Destination: buffer, Snapshot: MotionSnapshot): boolean
	if typeof(Destination) ~= "buffer" or buffer.len(Destination) ~= Codec.MotionBytes or typeof(Snapshot) ~= "table" then return false end
	local X, Y, Z = positionCodes(Snapshot.Position)
	if typeof(Snapshot.Velocity) ~= "Vector3" then return false end
	local VX = quantized(Snapshot.Velocity.X, 50, 14)
	local VY = quantized(Snapshot.Velocity.Y, 50, 14)
	local VZ = quantized(Snapshot.Velocity.Z, 50, 14)
	if X == nil or Y == nil or Z == nil or VX == nil or VY == nil or VZ == nil then return false end
	buffer.writeu8(Destination, 0, 0x53)
	writePositionBits(Destination, X, Y, Z)
	buffer.writebits(Destination, 71, 14, VX)
	buffer.writebits(Destination, 85, 14, VY)
	buffer.writebits(Destination, 99, 14, VZ)
	buffer.writebits(Destination, 113, 7, 0)
	return true
end

function Codec.ReadMotionInto(Input: buffer, Out: MotionSnapshot): boolean
	if typeof(Out) ~= "table" then return false end
	if not validPayload(Input, 15, 3, 113, 7) then clearMotion(Out); return false end
	Out.Position = readPositionBits(Input)
	Out.Velocity = Vector3.new(dequantized(buffer.readbits(Input, 71, 14), 14, 0.02), dequantized(buffer.readbits(Input, 85, 14), 14, 0.02), dequantized(buffer.readbits(Input, 99, 14), 14, 0.02))
	return true
end

-- Full: 8 header + 63 position + 42 velocity + 34 angles + 24 tick + 20 entity + 12 flags + 10 health + 16 sequence + 8 metadata + 3 reserved = 240 bits (30 bytes).
-- 21-bit signed position: +/-10485.76 studs, 0.01 resolution. 14-bit signed velocity: +/-163.84 studs/s, 0.02 resolution.
-- Version/profile header is 0x54. Strict validation prevents silent truncation/overflow.
function Codec.WriteFullInto(Destination: buffer, Snapshot: FullSnapshot): boolean
	if typeof(Destination) ~= "buffer" or buffer.len(Destination) ~= Codec.FullBytes or typeof(Snapshot) ~= "table" then return false end
	local X, Y, Z = positionCodes(Snapshot.Position)
	if typeof(Snapshot.Velocity) ~= "Vector3" then return false end
	local VX = quantized(Snapshot.Velocity.X, 50, 14)
	local VY = quantized(Snapshot.Velocity.Y, 50, 14)
	local VZ = quantized(Snapshot.Velocity.Z, 50, 14)
	local Yaw = angleCode(Snapshot.Yaw, 12)
	local Pitch = angleCode(Snapshot.Pitch, 11)
	local Roll = angleCode(Snapshot.Roll, 11)
	if X == nil or Y == nil or Z == nil or VX == nil or VY == nil or VZ == nil or Yaw == nil or Pitch == nil or Roll == nil then return false end
	if not isUnsignedInteger(Snapshot.TickMs, 16777215) or not isUnsignedInteger(Snapshot.EntityId, 1048575) or not isUnsignedInteger(Snapshot.Flags, 4095) then return false end
	if not isUnsignedInteger(Snapshot.Health, 1023) or not isUnsignedInteger(Snapshot.Sequence, 65535) or not isUnsignedInteger(Snapshot.Metadata, 255) then return false end
	buffer.writeu8(Destination, 0, 0x54)
	writePositionBits(Destination, X, Y, Z)
	buffer.writebits(Destination, 71, 14, VX)
	buffer.writebits(Destination, 85, 14, VY)
	buffer.writebits(Destination, 99, 14, VZ)
	buffer.writebits(Destination, 113, 12, Yaw)
	buffer.writebits(Destination, 125, 11, Pitch)
	buffer.writebits(Destination, 136, 11, Roll)
	buffer.writebits(Destination, 147, 24, Snapshot.TickMs)
	buffer.writebits(Destination, 171, 20, Snapshot.EntityId)
	buffer.writebits(Destination, 191, 12, Snapshot.Flags)
	buffer.writebits(Destination, 203, 10, Snapshot.Health)
	buffer.writebits(Destination, 213, 16, Snapshot.Sequence)
	buffer.writebits(Destination, 229, 8, Snapshot.Metadata)
	buffer.writebits(Destination, 237, 3, 0)
	return true
end

function Codec.ReadFullInto(Input: buffer, Out: FullSnapshot): boolean
	if typeof(Out) ~= "table" then return false end
	if not validPayload(Input, 30, 4, 237, 3) then clearFull(Out); return false end
	Out.Position = readPositionBits(Input)
	Out.Velocity = Vector3.new(dequantized(buffer.readbits(Input, 71, 14), 14, 0.02), dequantized(buffer.readbits(Input, 85, 14), 14, 0.02), dequantized(buffer.readbits(Input, 99, 14), 14, 0.02))
	Out.Yaw = decodeAngle(buffer.readbits(Input, 113, 12), 12)
	Out.Pitch = decodeAngle(buffer.readbits(Input, 125, 11), 11)
	Out.Roll = decodeAngle(buffer.readbits(Input, 136, 11), 11)
	Out.TickMs = buffer.readbits(Input, 147, 24)
	Out.EntityId = buffer.readbits(Input, 171, 20)
	Out.Flags = buffer.readbits(Input, 191, 12)
	Out.Health = buffer.readbits(Input, 203, 10)
	Out.Sequence = buffer.readbits(Input, 213, 16)
	Out.Metadata = buffer.readbits(Input, 229, 8)
	return true
end

-- Compare actual byte counts; this is NOT a measurement of DataStore billing or on-wire engine compression.
function Codec.SavingsPercent(OriginalBytes: number, EncodedBytes: number): number
	if not finite(OriginalBytes) or OriginalBytes <= 0 or not finite(EncodedBytes) or EncodedBytes < 0 then return 0 end
	return (OriginalBytes - EncodedBytes) / OriginalBytes * 100
end

AxiomX.Codec = Codec

return AxiomX
