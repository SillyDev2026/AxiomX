# AxiomX v1.0.1 — API reference

Generated from the public Luau declarations in [AxiomX.luau](../AxiomX.luau). **178 engine functions, 14 codec methods**. These are signatures, not measured performance claims.

The module exports `ImpactData`, `ImpactBuffer`, `ProjectileHit`, `ProjectileBuffer`, `FullSnapshot`, `PoseSnapshot` and `MotionSnapshot`.

Methods suffixed `Into` reuse a caller-owned output table where applicable; Roblox physics APIs may still allocate. `CastRay` uses direction plus distance, while `Raycast` accepts raw displacement. Numerical units are studs, seconds, and degrees unless otherwise specified.

## Scalar mathematics

```luau
function AxiomX.IsFinite(N: number): boolean
function AxiomX.Clamp01(N: number): number
function AxiomX.Lerp(A: number, B: number, Alpha: number): number
function AxiomX.InverseLerp(A: number, B: number, Value: number): number
function AxiomX.Remap(Value: number, FromMin: number, FromMax: number, ToMin: number, ToMax: number): number
function AxiomX.SmoothStep(A: number, B: number, Value: number): number
function AxiomX.SmootherStep(A: number, B: number, Value: number): number
function AxiomX.Damp(Current: number, Target: number, Speed: number, DeltaTime: number): number
function AxiomX.MoveTowards(Current: number, Target: number, MaxDelta: number): number
function AxiomX.Wrap(Value: number, Minimum: number, Maximum: number): number
function AxiomX.PingPong(Value: number, Length: number): number
function AxiomX.DeltaAngle(A: number, B: number): number
function AxiomX.LerpAngle(A: number, B: number, Alpha: number): number
function AxiomX.NearlyEqual(A: number, B: number, Tolerance: number?): boolean
function AxiomX.RoundTo(Value: number, Step: number): number
```

## Vector utilities

```luau
function AxiomX.IsFiniteVector(V: Vector3): boolean
function AxiomX.SafeUnit(V: Vector3): Vector3
function AxiomX.Direction(Origin: Vector3, Target: Vector3): Vector3
function AxiomX.DistanceSquared(A: Vector3, B: Vector3): number
function AxiomX.AngleBetween(A: Vector3, B: Vector3): number
function AxiomX.SignedAngle(A: Vector3, B: Vector3, Axis: Vector3): number
function AxiomX.Project(V: Vector3, Onto: Vector3): Vector3
function AxiomX.Reject(V: Vector3, From: Vector3): Vector3
function AxiomX.Reflect(Direction: Vector3, Normal: Vector3): Vector3
function AxiomX.Refract(Direction: Vector3, Normal: Vector3, IndexFrom: number, IndexTo: number): Vector3?
function AxiomX.RotateAroundAxis(V: Vector3, Axis: Vector3, AngleDegrees: number): Vector3
function AxiomX.LerpVector(A: Vector3, B: Vector3, Alpha: number): Vector3
function AxiomX.DampVector(Current: Vector3, Target: Vector3, Speed: number, DeltaTime: number): Vector3
function AxiomX.MoveTowardsVector(Current: Vector3, Target: Vector3, MaxDelta: number): Vector3
function AxiomX.FlatDirection(Origin: Vector3, Target: Vector3): Vector3
function AxiomX.HorizontalDistance(A: Vector3, B: Vector3): number
function AxiomX.LookAtSafe(Origin: Vector3, Target: Vector3, Up: Vector3?): CFrame
```

## Spatial geometry

```luau
function AxiomX.PointOnRay(Origin: Vector3, Direction: Vector3, Distance: number): Vector3
function AxiomX.ClosestPointOnLine(Point: Vector3, A: Vector3, B: Vector3): Vector3
function AxiomX.ClosestPointOnRay(Point: Vector3, Origin: Vector3, Direction: Vector3): Vector3
function AxiomX.ClosestPointOnSegment(Point: Vector3, A: Vector3, B: Vector3): Vector3
function AxiomX.DistanceToSegment(Point: Vector3, A: Vector3, B: Vector3): number
function AxiomX.PointInSphere(Point: Vector3, Center: Vector3, Radius: number): boolean
function AxiomX.PointInAABB(Point: Vector3, Center: Vector3, Size: Vector3): boolean
function AxiomX.PointInBox(Point: Vector3, Box: CFrame, Size: Vector3): boolean
function AxiomX.SpheresOverlap(CenterA: Vector3, RadiusA: number, CenterB: Vector3, RadiusB: number): boolean
function AxiomX.PointInCone(Point: Vector3, Apex: Vector3, Forward: Vector3, AngleDegrees: number, MaxDistance: number): boolean
function AxiomX.PointInViewCone(Point: Vector3, Camera: CFrame, FullAngleDegrees: number, MaxDistance: number?): boolean
```

## Roblox physics queries

```luau
function AxiomX.GetSlopeAngle(Normal: Vector3): number
function AxiomX.MakeRaycastParams(Exclude: {Instance}?, CollisionGroup: string?): RaycastParams
function AxiomX.MakeOverlapParams(Exclude: {Instance}?, MaxParts: number?, CollisionGroup: string?): OverlapParams
function AxiomX.Raycast(Origin: Vector3, Displacement: Vector3, Params: RaycastParams?): RaycastResult?
function AxiomX.CastRay(Origin: Vector3, Direction: Vector3, Distance: number?, Params: RaycastParams?): RaycastResult?
function AxiomX.CastSphere(Origin: Vector3, Radius: number, Direction: Vector3, Distance: number?, Params: RaycastParams?): RaycastResult?
function AxiomX.CastBlock(Box: CFrame, Size: Vector3, Direction: Vector3, Distance: number?, Params: RaycastParams?): RaycastResult?
function AxiomX.GetImpactData(Origin: Vector3, Direction: Vector3, Distance: number?, Params: RaycastParams?): ImpactData?
function AxiomX.GetImpactAngle(Origin: Vector3, Direction: Vector3, Distance: number?, Params: RaycastParams?): number?
function AxiomX.GetImpactPosition(Origin: Vector3, Direction: Vector3, Distance: number?, Params: RaycastParams?): Vector3?
function AxiomX.GetGroundHit(Origin: Vector3, Distance: number?, Params: RaycastParams?): RaycastResult?
function AxiomX.GetGroundDistance(Origin: Vector3, Distance: number?, Params: RaycastParams?): number?
function AxiomX.HasLineOfSight(Origin: Vector3, Target: Vector3, Params: RaycastParams?, TargetInstance: Instance?): boolean
function AxiomX.GetPartsInRadius(Center: Vector3, Radius: number, Params: OverlapParams?): {BasePart}
function AxiomX.GetPartsInBox(Box: CFrame, Size: Vector3, Params: OverlapParams?): {BasePart}
function AxiomX.GetPartsInPart(Part: BasePart, Params: OverlapParams?): {BasePart}
function AxiomX.ProjectilePosition(Origin: Vector3, Velocity: Vector3, Time: number, Gravity: Vector3?): Vector3
function AxiomX.ProjectileVelocity(Velocity: Vector3, Time: number, Gravity: Vector3?): Vector3
function AxiomX.SolveLaunchVelocity(Origin: Vector3, Target: Vector3, TravelTime: number, Gravity: Vector3?): Vector3?
function AxiomX.SolveBallisticArc(Origin: Vector3, Target: Vector3, Speed: number, Gravity: number?): (Vector3?, Vector3?)
```

## Ballistics and interception

```luau
function AxiomX.TimeToReachHeight(StartY: number, TargetY: number, InitialVerticalSpeed: number, Gravity: number?): (number?, number?)
function AxiomX.PredictIntercept(Origin: Vector3, TargetPosition: Vector3, TargetVelocity: Vector3, ProjectileSpeed: number): (Vector3?, number?)
function AxiomX.BounceVelocity(Velocity: Vector3, Normal: Vector3, Restitution: number?, Friction: number?): Vector3
function AxiomX.TraceProjectile(Origin: Vector3, Velocity: Vector3, Duration: number, Steps: number, Params: RaycastParams?, Gravity: Vector3?): ProjectileHit?
function AxiomX.LerpClamped(A: number, B: number, Alpha: number): number
function AxiomX.InverseLerpClamped(A: number, B: number, Value: number): number
function AxiomX.RemapClamped(Value: number, FromMin: number, FromMax: number, ToMin: number, ToMax: number): number
function AxiomX.Fract(Value: number): number
function AxiomX.Step(Edge: number, Value: number): number
function AxiomX.SignNonZero(Value: number): number
function AxiomX.MoveTowardsAngle(Current: number, Target: number, MaxDelta: number): number
function AxiomX.DampAngle(Current: number, Target: number, Speed: number, DeltaTime: number): number
```

## Advanced interpolation

```luau
function AxiomX.SmoothPulse(Start: number, End: number, Fade: number, Value: number): number
function AxiomX.SmoothDamp(Current: number, Target: number, CurrentVelocity: number, SmoothTime: number, DeltaTime: number, MaxSpeed: number?): (number, number)
function AxiomX.SmoothDampAngle(Current: number, Target: number, CurrentVelocity: number, SmoothTime: number, DeltaTime: number, MaxSpeed: number?): (number, number)
function AxiomX.QuadraticBezier(A: number, B: number, C: number, Alpha: number): number
function AxiomX.CubicBezier(A: number, B: number, C: number, D: number, Alpha: number): number
function AxiomX.Hermite(A: number, TangentA: number, B: number, TangentB: number, Alpha: number): number
function AxiomX.ClampFinite(Value: number, Minimum: number, Maximum: number, Fallback: number?): number
function AxiomX.VectorMagnitudeSquared(V: Vector3): number
function AxiomX.VectorNearlyEqual(A: Vector3, B: Vector3, Tolerance: number?): boolean
function AxiomX.ClampMagnitude(V: Vector3, Maximum: number): Vector3
function AxiomX.FlattenOnPlane(V: Vector3, Normal: Vector3): Vector3
function AxiomX.Perpendicular(V: Vector3): Vector3
function AxiomX.OrthonormalBasis(Forward: Vector3, Up: Vector3?): (Vector3, Vector3, Vector3)
function AxiomX.SlerpUnit(A: Vector3, B: Vector3, Alpha: number): Vector3
function AxiomX.SlerpVector(A: Vector3, B: Vector3, Alpha: number): Vector3
function AxiomX.RotateTowardsVector(Current: Vector3, Target: Vector3, MaximumDegrees: number): Vector3
function AxiomX.VectorQuadraticBezier(A: Vector3, B: Vector3, C: Vector3, Alpha: number): Vector3
function AxiomX.VectorCubicBezier(A: Vector3, B: Vector3, C: Vector3, D: Vector3, Alpha: number): Vector3
function AxiomX.VectorCubicBezierDerivative(A: Vector3, B: Vector3, C: Vector3, D: Vector3, Alpha: number): Vector3
function AxiomX.VectorHermite(A: Vector3, TangentA: Vector3, B: Vector3, TangentB: Vector3, Alpha: number): Vector3
function AxiomX.SmoothDampVector(Current: Vector3, Target: Vector3, CurrentVelocity: Vector3, SmoothTime: number, DeltaTime: number, MaxSpeed: number?): (Vector3, Vector3)
function AxiomX.LerpCFrame(A: CFrame, B: CFrame, Alpha: number): CFrame
function AxiomX.LookAlongSafe(Origin: Vector3, Forward: Vector3, Up: Vector3?): CFrame
function AxiomX.AlignToNormal(Position: Vector3, Normal: Vector3, Forward: Vector3?): CFrame
function AxiomX.ClosestPointOnAABB(Point: Vector3, Center: Vector3, Size: Vector3): Vector3
```

## 3D intersections

```luau
function AxiomX.ClosestPointOnBox(Point: Vector3, Box: CFrame, Size: Vector3): Vector3
function AxiomX.DistanceToBox(Point: Vector3, Box: CFrame, Size: Vector3): number
function AxiomX.PointInCapsule(Point: Vector3, A: Vector3, B: Vector3, Radius: number): boolean
function AxiomX.CapsuleSphereOverlap(A: Vector3, B: Vector3, CapsuleRadius: number, Center: Vector3, SphereRadius: number): boolean
function AxiomX.PointInCylinder(Point: Vector3, Center: Vector3, Axis: Vector3, Radius: number, HalfHeight: number): boolean
function AxiomX.SignedDistanceToPlane(Point: Vector3, PlanePoint: Vector3, PlaneNormal: Vector3): number
function AxiomX.RayPlaneIntersection(Origin: Vector3, Direction: Vector3, PlanePoint: Vector3, PlaneNormal: Vector3): (Vector3?, number?)
function AxiomX.SegmentPlaneIntersection(A: Vector3, B: Vector3, PlanePoint: Vector3, PlaneNormal: Vector3): (Vector3?, number?)
function AxiomX.RaySphereIntersection(Origin: Vector3, Direction: Vector3, Center: Vector3, Radius: number): (Vector3?, number?)
function AxiomX.SegmentSphereIntersection(A: Vector3, B: Vector3, Center: Vector3, Radius: number): (Vector3?, number?)
function AxiomX.RayAABBIntersection(Origin: Vector3, Direction: Vector3, Center: Vector3, Size: Vector3): (Vector3?, number?)
function AxiomX.RayBoxIntersection(Origin: Vector3, Direction: Vector3, Box: CFrame, Size: Vector3): (Vector3?, number?)
function AxiomX.TriangleNormal(A: Vector3, B: Vector3, C: Vector3): Vector3
function AxiomX.TriangleArea(A: Vector3, B: Vector3, C: Vector3): number
function AxiomX.Barycentric(Point: Vector3, A: Vector3, B: Vector3, C: Vector3): (number?, number?, number?)
function AxiomX.PointInTriangle(Point: Vector3, A: Vector3, B: Vector3, C: Vector3, Tolerance: number?): boolean
```

## Extended engine queries

```luau
function AxiomX.SetRaycastFilters(Params: RaycastParams, Include: {Instance}?, Exclude: {Instance}?): ()
function AxiomX.SetOverlapFilters(Params: OverlapParams, Include: {Instance}?, Exclude: {Instance}?): ()
function AxiomX.CastSphereDisplacement(Origin: Vector3, Radius: number, Displacement: Vector3, Params: RaycastParams?): RaycastResult?
function AxiomX.CastBlockDisplacement(Box: CFrame, Size: Vector3, Displacement: Vector3, Params: RaycastParams?): RaycastResult?
function AxiomX.CastShape(Part: BasePart, Direction: Vector3, Distance: number?, Params: RaycastParams?, CFrameOverride: CFrame?, SizeOverride: Vector3?): RaycastResult?
function AxiomX.CastShapeDisplacement(Part: BasePart, Displacement: Vector3, Params: RaycastParams?, CFrameOverride: CFrame?, SizeOverride: Vector3?): RaycastResult?
function AxiomX.CastRayTo(Origin: Vector3, Target: Vector3, Params: RaycastParams?): RaycastResult?
function AxiomX.GetGroundSphere(Origin: Vector3, Radius: number, Distance: number?, Params: RaycastParams?): RaycastResult?
function AxiomX.GetGroundBlock(Box: CFrame, Size: Vector3, Distance: number?, Params: RaycastParams?): RaycastResult?
function AxiomX.IsGrounded(Origin: Vector3, Distance: number, MaxSlopeDegrees: number?, Params: RaycastParams?): boolean
function AxiomX.GetImpactFromResult(Result: RaycastResult, IncomingDirection: Vector3): ImpactData?
function AxiomX.GetSurfaceFrame(Result: RaycastResult, PreferredForward: Vector3?): CFrame
function AxiomX.GetPartCentersInRadius(Center: Vector3, Radius: number, Params: OverlapParams?): {BasePart}
function AxiomX.GetPartCentersInCone(Apex: Vector3, Forward: Vector3, HalfAngleDegrees: number, Radius: number, Params: OverlapParams?): {BasePart}
```

## Advanced ballistics

```luau
function AxiomX.ProjectileVelocityDrag(Velocity: Vector3, Time: number, Drag: number, Gravity: Vector3?): Vector3
function AxiomX.ProjectilePositionDrag(Origin: Vector3, Velocity: Vector3, Time: number, Drag: number, Gravity: Vector3?): Vector3
function AxiomX.GetApexTime(InitialVerticalSpeed: number, Gravity: number?): number?
function AxiomX.GetMaximumHeight(StartY: number, InitialVerticalSpeed: number, Gravity: number?): number?
function AxiomX.SampleProjectilePath(Origin: Vector3, Velocity: Vector3, Duration: number, Steps: number, Gravity: Vector3?): {Vector3}
function AxiomX.TraceProjectileSphere(Origin: Vector3, Velocity: Vector3, Radius: number, Duration: number, Steps: number, Params: RaycastParams?, Gravity: Vector3?): ProjectileHit?
function AxiomX.PredictInterceptAcceleration(Origin: Vector3, TargetPosition: Vector3, TargetVelocity: Vector3, TargetAcceleration: Vector3, ProjectileSpeed: number, MaxTime: number?, Iterations: number?): (Vector3?, number?)
```

## Fast paths and query budgets

```luau
function AxiomX.FastDistanceSquared(A: Vector3, B: Vector3): number
function AxiomX.FastDistanceSquaredXZ(A: Vector3, B: Vector3): number
function AxiomX.FastMagnitudeSquared(V: Vector3): number
function AxiomX.FastMagnitudeSquaredXZ(V: Vector3): number
function AxiomX.WithinDistance(A: Vector3, B: Vector3, Radius: number): boolean
function AxiomX.WithinDistanceXZ(A: Vector3, B: Vector3, Radius: number): boolean
function AxiomX.FastNormalDot(Direction: Vector3, Normal: Vector3): number
function AxiomX.FastAngleDegrees(A: Vector3, B: Vector3): number
function AxiomX.FastImpactAngle(Direction: Vector3, SurfaceNormal: Vector3): number
function AxiomX.FastSlopeAngle(Normal: Vector3): number
function AxiomX.IsWalkableNormal(Normal: Vector3, MaximumSlopeDegrees: number): boolean
function AxiomX.FastReflect(Direction: Vector3, Normal: Vector3): Vector3
function AxiomX.FastDampFactor(Speed: number, DeltaTime: number): number
function AxiomX.FastDampScalar(Current: number, Target: number, Speed: number, DeltaTime: number): number
function AxiomX.FastDampVector(Current: Vector3, Target: Vector3, Speed: number, DeltaTime: number): Vector3
function AxiomX.FastClosestSegmentParameter(Point: Vector3, A: Vector3, B: Vector3): number
function AxiomX.FastPointSegmentDistanceSquared(Point: Vector3, A: Vector3, B: Vector3): number
function AxiomX.FastSphereContains(Point: Vector3, Center: Vector3, Radius: number): boolean
function AxiomX.FastCapsuleContains(Point: Vector3, A: Vector3, B: Vector3, Radius: number): boolean
function AxiomX.FastSphereOverlaps(A: Vector3, RadiusA: number, B: Vector3, RadiusB: number): boolean
function AxiomX.FastAABBContains(Point: Vector3, Center: Vector3, HalfSize: Vector3): boolean
function AxiomX.FastAABBOverlaps(CenterA: Vector3, HalfA: Vector3, CenterB: Vector3, HalfB: Vector3): boolean
function AxiomX.FastRayPlaneTime(Origin: Vector3, Direction: Vector3, PlanePoint: Vector3, PlaneNormal: Vector3): number?
function AxiomX.FastRaySphereTime(Origin: Vector3, Direction: Vector3, Center: Vector3, Radius: number): number?
function AxiomX.FastRayAABBTime(Origin: Vector3, Direction: Vector3, Center: Vector3, HalfSize: Vector3): number?
function AxiomX.FastSegmentSphereTime(A: Vector3, B: Vector3, Center: Vector3, Radius: number): number?
function AxiomX.FastSegmentAABBTime(A: Vector3, B: Vector3, Center: Vector3, HalfSize: Vector3): number?
function AxiomX.FastProjectilePosition(Origin: Vector3, InitialVelocity: Vector3, Gravity: Vector3, Time: number): Vector3
function AxiomX.FastProjectileVelocity(InitialVelocity: Vector3, Gravity: Vector3, Time: number): Vector3
function AxiomX.TryConsumeQueryBudget(Used: number, Maximum: number, Cost: number?): (boolean, number)
function AxiomX.SetRaycastShapeTuning(Params: RaycastParams, Margin: number?, SizeGradient: number?): boolean
```

## Reusable outputs

```luau
function AxiomX.GetImpactDataInto(Origin: Vector3, Direction: Vector3, Distance: number?, Params: RaycastParams?, Out: ImpactBuffer): boolean
function AxiomX.GetImpactFromResultInto(Hit: RaycastResult, Direction: Vector3, Out: ImpactBuffer): boolean
function AxiomX.GetImpactAngleFromResult(Hit: RaycastResult, Direction: Vector3): number?
function AxiomX.TraceProjectileInto(Origin: Vector3, Velocity: Vector3, Duration: number, Steps: number, Params: RaycastParams?, Gravity: Vector3?, Out: ProjectileBuffer): boolean
function AxiomX.TraceProjectileSphereInto(Origin: Vector3, Velocity: Vector3, Radius: number, Duration: number, Steps: number, Params: RaycastParams?, Gravity: Vector3?, Out: ProjectileBuffer): boolean
function AxiomX.SampleProjectilePathInto(Origin: Vector3, Velocity: Vector3, Duration: number, Steps: number, Gravity: Vector3?, Out: {Vector3}): number
function AxiomX.GetPartsInRadiusInto(Center: Vector3, Radius: number, Params: OverlapParams?, Out: {BasePart}): number
function AxiomX.GetPartsInBoxInto(Box: CFrame, Size: Vector3, Params: OverlapParams?, Out: {BasePart}): number
function AxiomX.MakeImpactBuffer(): ImpactBuffer
function AxiomX.MakeProjectileBuffer(): ProjectileBuffer
```

## Binary snapshot codec

Four fixed-profile encodings: 9-byte position, 14-byte pose, 15-byte motion, and 30-byte full snapshot. Wire protocol version remains 1.

```luau
function Codec.GetBytes(Profile: number): number?
function Codec.NewBuffer(Profile: number): buffer?
function Codec.NewFullSnapshot(): FullSnapshot
function Codec.NewPoseSnapshot(): PoseSnapshot
function Codec.NewMotionSnapshot(): MotionSnapshot
function Codec.WritePositionInto(Destination: buffer, Position: Vector3): boolean
function Codec.ReadPosition(Input: buffer): Vector3?
function Codec.WritePoseInto(Destination: buffer, Snapshot: PoseSnapshot): boolean
function Codec.ReadPoseInto(Input: buffer, Out: PoseSnapshot): boolean
function Codec.WriteMotionInto(Destination: buffer, Snapshot: MotionSnapshot): boolean
function Codec.ReadMotionInto(Input: buffer, Out: MotionSnapshot): boolean
function Codec.WriteFullInto(Destination: buffer, Snapshot: FullSnapshot): boolean
function Codec.ReadFullInto(Input: buffer, Out: FullSnapshot): boolean
function Codec.SavingsPercent(OriginalBytes: number, EncodedBytes: number): number
```

Read the [README](../README.md) for valid ranges, quantization, safety, usage examples, type checking, and Studio benchmarks.
