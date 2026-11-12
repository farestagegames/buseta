class_name ArcadeSystem
extends Node
## Runs the arcade mode in the city: a course that keeps growing, a checkpoint
## arch to drive through, boost pads on the road, and the clock. ArcadeRun holds
## the rules; this node draws and reports.

## More course is planned when the bus is this close to its end.
const EXTEND_WHEN := 900.0
const LEGS_PER_PLAN := 6
const ARCH_COLOUR := Color(0.98, 0.72, 0.15)
const PAD_COLOUR := Color(1.0, 0.45, 0.1)
## Pads sit just above the road surface, so the road never hides them.
const PAD_LIFT := 0.1

var run := ArcadeRun.new()
var runner: RouteRunner

var _network: RoadNetwork
var _ground: GroundSurface
var _random := RandomNumberGenerator.new()
var _arch: Node3D
var _pads: MultiMeshInstance3D
var _bus_spot := Vector2.ZERO
var _boosting: float = 0.0
var _status_timer: float = 0.0


func setup(route: RouteRunner, network: RoadNetwork, ground: GroundSurface, random_seed: int) -> void:
	runner = route
	_network = network
	_ground = ground
	_random.seed = random_seed
	run.plan_to(runner.length())
	_build_arch()
	_build_pads()
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.bus_collided.connect(func(impact: float) -> void:
		if impact >= ScoreKeeper.LOST_COLLISION_SPEED:
			run.crash()
			GameEvents.penalty_shown.emit(tr("Crash: -%d s") % roundi(ArcadeRun.CRASH_SECONDS)))


func _on_telemetry(data: BusTelemetry) -> void:
	if run.finished:
		return
	var dt := get_physics_process_delta_time()
	var rear := Vector2(data.position.x, data.position.z)
	_bus_spot = rear
	var forward := Vector2(-sin(data.heading), -cos(data.heading))
	runner.update_position(rear + forward * 3.0, forward)
	if runner.length() - runner.progress < EXTEND_WHEN:
		_extend()
	_boosting = maxf(_boosting - dt, 0.0)
	for event in run.update(runner.progress, runner.distance_from_line(rear), dt):
		match event:
			"checkpoint":
				GameEvents.hint_shown.emit(tr("Checkpoint: +%d s") % roundi(ArcadeRun.CHECKPOINT_SECONDS))
				_place_arch()
			"boost":
				_boosting = ArcadeRun.BOOST_SECONDS
				GameEvents.boost_started.emit(ArcadeRun.BOOST_SECONDS)
				_fill_pads()
			"finished":
				_finish()
				return
	_status_timer -= dt
	if _status_timer <= 0.0:
		_status_timer = 0.1
		var next := run.next_checkpoint()
		var spot: Vector2 = runner.point_at(next)["position"] if next != INF else rear
		GameEvents.arcade_status.emit(run.seconds_left, run.checkpoints_passed + 1, maxf(next - runner.progress, 0.0), spot, _boosting > 0.0)


func _extend() -> void:
	var last := runner.last_leg
	runner.extend(EndlessPlanner.walk(_network, last["road"], int(last["dir"]), LEGS_PER_PLAN, _random), _network, [])
	run.plan_to(runner.length())
	_fill_pads()
	GameEvents.route_extended.emit(runner)


func _finish() -> void:
	GameEvents.shift_completed.emit({
		"route": runner.route_name, "carried": 0, "served": run.checkpoints_passed, "missed": 0,
		"left_behind": 0, "time": run.elapsed, "fares": 0, "accuracy": 1.0, "completed": false,
		"arcade": {"checkpoints": run.checkpoints_passed, "distance": runner.progress},
	})


## A gantry over the road: two posts and a glowing banner.
func _build_arch() -> void:
	var b := LowPolyBuilder.new()
	var half := RoadNetwork.ROAD_HALF_WIDTH + 1.2
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * half, 2.6, 0.0), Vector3(0.35, 5.2, 0.35), Color(0.2, 0.2, 0.24))
	var frame := MeshInstance3D.new()
	frame.mesh = b.build(LowPolyBuilder.vertex_colour_material())
	var banner := LowPolyBuilder.new()
	banner.box(Vector3(0.0, 5.0, 0.0), Vector3(half * 2.0 + 0.35, 0.7, 0.2), Color.WHITE)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = ARCH_COLOUR
	var lit := MeshInstance3D.new()
	lit.mesh = banner.build(glow)
	_arch = Node3D.new()
	_arch.add_child(frame)
	_arch.add_child(lit)
	add_child(_arch)
	_place_arch()


func _place_arch() -> void:
	var next := run.next_checkpoint()
	if next == INF:
		_arch.visible = false
		return
	_arch.visible = true
	var placed := runner.point_at(next)
	var spot: Vector2 = placed["position"]
	var forward: Vector2 = placed["forward"]
	_arch.position = Vector3(spot.x, _ground.height_at(spot), spot.y)
	_arch.rotation.y = RoadNetwork.heading_of(forward)


## Chevrons glowing on the road, one batch for every pad not yet used.
func _build_pads() -> void:
	var b := LowPolyBuilder.new()
	for i in 3:
		var z := -1.2 + i * 1.2
		b.box(Vector3(-0.7, 0.04, z + 0.25), Vector3(1.5, 0.04, 0.35), Color.WHITE)
		b.box(Vector3(0.7, 0.04, z + 0.25), Vector3(1.5, 0.04, 0.35), Color.WHITE)
		b.box(Vector3(0.0, 0.04, z), Vector3(0.5, 0.04, 0.4), Color.WHITE)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = PAD_COLOUR
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = b.build(glow)
	_pads = MultiMeshInstance3D.new()
	_pads.multimesh = batch
	_pads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pads.custom_aabb = AABB(Vector3(-4000.0, -200.0, -4000.0), Vector3(8000.0, 400.0, 8000.0))
	add_child(_pads)
	_fill_pads()


func _fill_pads() -> void:
	var batch := _pads.multimesh
	var shown: Array[Transform3D] = []
	for i in run.boosts.size():
		if run.boosts_used[i]:
			continue
		var placed := runner.point_at(run.boosts[i])
		var forward: Vector2 = placed["forward"]
		var right := Vector2(-forward.y, forward.x) * float(_network.traffic_side)
		# On the bus's own lane, the kerb side of the line.
		var spot: Vector2 = placed["position"] + right * RoadNetwork.LANE_WIDTH / 2.0
		var basis := Basis(Vector3.UP, RoadNetwork.heading_of(forward))
		shown.append(Transform3D(basis, Vector3(spot.x, _ground.height_at(spot) + PAD_LIFT, spot.y)))
	batch.instance_count = shown.size()
	for i in shown.size():
		batch.set_instance_transform(i, shown[i])
