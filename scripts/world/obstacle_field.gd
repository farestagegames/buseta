class_name ObstacleField
extends Node3D
## Cones, bins, crates and barriers. Rendered as one instanced batch per kind,
## and tested against the bus outline, so hundreds cost almost nothing.

const KINDS := {
	"cone": {"radius": 0.3, "speed_loss": 0.03},
	"bin": {"radius": 0.42, "speed_loss": 0.35},
	"crate": {"radius": 0.55, "speed_loss": 0.5},
	"barrier": {"radius": 0.75, "speed_loss": 0.45},
	"car": {"radius": 1.25, "speed_loss": 0.0},
	"lamp": {"radius": 0.3, "speed_loss": 0.0},
	"stall": {"radius": 0.95, "speed_loss": 0.4},
}
## Share of the bus's speed lost to a parked car. A bus outweighs a car about
## nine to one, so even a head-on hit shoves the car rather than stopping the bus.
const CAR_LOSS_GLANCING := 0.14
const CAR_LOSS_HEAD_ON := 0.5
## Speed lost per later hit while the bus keeps pushing the same car.
const CAR_PUSH_LOSS_SHARE := 0.1
## A lamp post costs this share of bus speed and falls over.
const LAMP_LOSS := 0.3
const CAR_MIN_HIT_SPEED := 0.15
## Below this a bus pushes a car along with hardly any loss of speed.
const CAR_FULL_IMPACT_SPEED := 5.0
const STALL_COLOURS: Array[Color] = [
	Color(0.95, 0.3, 0.2), Color(0.98, 0.78, 0.15), Color(0.15, 0.6, 0.65), Color(0.9, 0.35, 0.55), Color(0.3, 0.65, 0.3),
]
## Below this the bus nudges past rather than knocking things over.
const MIN_HIT_SPEED := 0.6
const CHECK_RADIUS := 15.0
## After dark, lamps and stalls glow and throw a pool of light on the ground. The
## pools are flat discs added on top, not real lights, so a night street costs two
## draws. Each is radius and where it sits from the prop, along its own +X.
const POOLS := {
	"lamp": {"radius": 8.0, "reach": 1.6, "colour": Color(0.78, 0.56, 0.3)},
	"stall": {"radius": 3.8, "reach": 0.0, "colour": Color(0.7, 0.48, 0.22)},
}
const POOL_LIFT := 0.17 ## Over the road markings, under anything standing.
const GLOW_OFF := Color(0.78, 0.78, 0.74)
const GLOW_ON := Color(1.0, 0.86, 0.58)

var props: Array[KnockableProp] = []

var _ground: GroundSurface
var _spec: BusSpec
var _batches: Dictionary = {} ## Kind to MultiMesh.
var _parked_colours: Array[Color] = []
var _indices: Dictionary = {} ## Prop to instance index.
var _bus_position: Vector2 = Vector2.ZERO
var _bus_heading: float = 0.0
var _bus_speed: float = 0.0
var _trailer_axle: Vector2 = Vector2.ZERO
var _trailer_heading: float = 0.0
var _glow := StandardMaterial3D.new()
var _pool_material := StandardMaterial3D.new()
var _pools: MultiMesh
var _pools_instance: MultiMeshInstance3D
var _pool_of: Dictionary = {} ## Prop to its pool's instance, while it stands.
var _pools_wanted: bool = false
## The pools are drawn, black, for the first ticks, so their shader is built before
## the first storm clouds switch the lamps on mid-shift.
var _warm_ticks: int = 3


func setup(map_data: Dictionary, network: RoadNetwork, ground: GroundSurface, spec: BusSpec, lamps: Array[Dictionary] = []) -> void:
	_ground = ground
	_spec = spec
	_parked_colours = CityTheme.from_data(map_data).car_colours
	for entry: Dictionary in map_data.get("knockables", []):
		var placed: Dictionary = network.sample(entry["road"], entry["along"], entry["lateral"], entry["dir"])
		_add_prop(entry["kind"], placed["position"], placed["heading"])
	for line: Dictionary in map_data.get("cone_lines", []):
		var along: float = line["from"]
		while along <= float(line["to"]):
			var placed: Dictionary = network.sample(line["road"], along, line["lateral"], line["dir"])
			_add_prop("cone", placed["position"], 0.0)
			along += float(line["spacing"])
	for car: Dictionary in map_data.get("parked_cars", []):
		var placed: Dictionary = network.sample(car["road"], car["along"], RoadNetwork.ROAD_HALF_WIDTH - 1.0, car["dir"])
		_add_prop("car", placed["position"], placed["heading"])
		props[props.size() - 1].heavy = true
	for lamp: Dictionary in lamps:
		_add_prop("lamp", lamp["position"], lamp["yaw"])
		props[props.size() - 1].tips_over = true
	_build_batches()
	_build_pools()
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.lighting_changed.connect(_on_lighting)


func _add_prop(kind: String, ground_position: Vector2, yaw: float) -> void:
	var height := _ground.height_at(ground_position) + 0.1
	var start := Vector3(ground_position.x, height, ground_position.y)
	props.append(KnockableProp.new(kind, start, KINDS[kind]["radius"], yaw))


func _physics_process(dt: float) -> void:
	if _warm_ticks > 0 and _pools_instance != null:
		_warm_ticks -= 1
		_pools_instance.visible = _warm_ticks > 0 or _pools_wanted
	for prop in props:
		if prop.is_moving() or prop.cooldown > 0.0 or prop.in_contact():
			prop.update(dt, _ground.height_at(Vector2(prop.position.x, prop.position.z)) + 0.1)
			_write_transform(prop)
			if _pool_of.has(prop) and (prop.state != KnockableProp.State.STANDING or prop.tip_angle > 0.0):
				# A knocked lamp or stall no longer lights the street.
				_pools.set_instance_transform(_pool_of[prop], Transform3D(Basis().scaled(Vector3.ZERO), prop.position))
				_pool_of.erase(prop)


func _on_lighting(lights: float, _headlights: bool) -> void:
	_glow.albedo_color = GLOW_OFF.lerp(GLOW_ON, clampf(lights * 1.5, 0.0, 1.0))
	_pool_material.albedo_color = Color.WHITE * clampf(lights, 0.0, 1.0)
	_pools_wanted = lights > 0.02
	if _pools_instance != null:
		_pools_instance.visible = _pools_wanted or _warm_ticks > 0


func _on_telemetry(data: BusTelemetry) -> void:
	_bus_position = Vector2(data.position.x, data.position.z)
	_bus_heading = data.heading
	_bus_speed = data.speed
	_trailer_axle = data.trailer_axle
	_trailer_heading = data.trailer_heading
	var reach := CHECK_RADIUS + _spec.full_length() - _spec.overall_length()
	var bus_speed := absf(_bus_speed)
	if bus_speed < CAR_MIN_HIT_SPEED:
		return
	var forward := Vector2(-sin(_bus_heading), -cos(_bus_heading))
	var centre := BusFootprint.body_centre(_bus_position, _bus_heading, _spec)
	for prop in props:
		if not _can_be_hit(prop, bus_speed):
			continue
		var ground_position := Vector2(prop.position.x, prop.position.z)
		if ground_position.distance_squared_to(centre) > reach * reach:
			continue
		var touching := false
		if prop.heavy:
			var car_forward := Vector2(-sin(prop.rotation.y), -cos(prop.rotation.y))
			touching = BusFootprint.touches_car(_bus_position, _bus_heading, _spec, ground_position, car_forward)
		else:
			touching = BusFootprint.touches(_bus_position, _bus_heading, _spec, ground_position, prop.radius)
		if _spec.is_articulated() and BusFootprint.touches_trailer(_trailer_axle, _trailer_heading, _spec, ground_position, prop.radius):
			touching = true
		if touching:
			if prop.heavy:
				_shove(prop, forward, ground_position - centre)
			elif prop.tips_over:
				_knock_lamp(prop, ground_position - centre, forward * signf(_bus_speed))
			else:
				prop.hit(forward * _bus_speed, ground_position - centre)
				GameEvents.obstacle_hit.emit(prop.kind, float(KINDS[prop.kind]["speed_loss"]))


func _can_be_hit(prop: KnockableProp, bus_speed: float) -> bool:
	if prop.heavy:
		var prop_speed := Vector2(prop.velocity.x, prop.velocity.z).length()
		return prop.cooldown <= 0.0 and prop_speed < bus_speed
	return prop.state == KnockableProp.State.STANDING and bus_speed >= MIN_HIT_SPEED


func _knock_lamp(prop: KnockableProp, away: Vector2, direction: Vector2) -> void:
	prop.tip(direction + away.normalized() * 0.3)
	var loss := absf(_bus_speed) * LAMP_LOSS
	GameEvents.obstacle_hit.emit(prop.kind, loss)
	if loss > 0.5:
		GameEvents.bus_collided.emit(loss)


func _shove(prop: KnockableProp, forward: Vector2, away: Vector2) -> void:
	var direction := forward * signf(_bus_speed)
	var head_on := clampf(direction.dot(away.normalized()), 0.0, 1.0)
	var bus_speed := absf(_bus_speed)
	var hardness := clampf(bus_speed / CAR_FULL_IMPACT_SPEED, 0.05, 1.0)
	var loss := bus_speed * lerpf(CAR_LOSS_GLANCING, CAR_LOSS_HEAD_ON, head_on) * hardness
	if prop.in_contact():
		loss *= CAR_PUSH_LOSS_SHARE
	prop.shove(forward * _bus_speed, away)
	GameEvents.obstacle_hit.emit(prop.kind, loss)
	if loss > 0.5:
		GameEvents.bus_collided.emit(loss)


func _build_batches() -> void:
	var counts := {}
	for prop in props:
		counts[prop.kind] = int(counts.get(prop.kind, 0)) + 1
	var material := LowPolyBuilder.vertex_colour_material()
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.albedo_color = GLOW_OFF
	for kind: String in counts:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = kind == "car" or kind == "stall"
		var mesh := _mesh_for(kind).build(material)
		_bulbs_for(kind).build_into(mesh, _glow)
		multi.mesh = mesh
		multi.instance_count = counts[kind]
		_batches[kind] = multi
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		instance.custom_aabb = AABB(Vector3(-2000.0, -200.0, -2000.0), Vector3(4000.0, 400.0, 4000.0))
		add_child(instance)
	var next := {}
	for prop in props:
		var index: int = next.get(prop.kind, 0)
		next[prop.kind] = index + 1
		_indices[prop] = index
		if prop.kind == "car":
			(_batches["car"] as MultiMesh).set_instance_color(index, _parked_colours[index % _parked_colours.size()])
		elif prop.kind == "stall":
			(_batches["stall"] as MultiMesh).set_instance_color(index, STALL_COLOURS[index % STALL_COLOURS.size()])
		_write_transform(prop)


## The part of a lamp or stall that glows after dark.
func _bulbs_for(kind: String) -> LowPolyBuilder:
	var b := LowPolyBuilder.new()
	match kind:
		"lamp":
			b.box(Vector3(1.6, 6.9, 0.0), Vector3(0.44, 0.05, 0.44), Color.WHITE)
		"stall":
			b.box(Vector3(0.0, 2.05, 0.0), Vector3(0.16, 0.2, 0.16), Color.WHITE)
	return b


## One flat glow on the ground under each lamp and stall, in a single batch.
func _build_pools() -> void:
	var lit := props.filter(func(prop: KnockableProp) -> bool: return POOLS.has(prop.kind))
	if lit.is_empty():
		return
	var disc := LowPolyBuilder.new()
	disc.glow_disc(Vector3.ZERO, 1.0, Color.WHITE, 18)
	_pool_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pool_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_pool_material.vertex_color_use_as_albedo = true
	_pool_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_pool_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pool_material.disable_fog = true
	_pool_material.albedo_color = Color.BLACK
	_pools = MultiMesh.new()
	_pools.transform_format = MultiMesh.TRANSFORM_3D
	_pools.use_colors = true
	_pools.mesh = disc.build(_pool_material)
	_pools.instance_count = lit.size()
	for i in lit.size():
		var prop: KnockableProp = lit[i]
		var pool: Dictionary = POOLS[prop.kind]
		var reach := Vector2(float(pool["reach"]), 0.0).rotated(-prop.rotation.y)
		var spot := Vector2(prop.position.x, prop.position.z) + reach
		_pools.set_instance_transform(i, _pool_transform(spot, pool["radius"]))
		_pools.set_instance_color(i, pool["colour"])
		_pool_of[prop] = i
	_pools_instance = MultiMeshInstance3D.new()
	_pools_instance.multimesh = _pools
	_pools_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pools_instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_pools_instance.custom_aabb = AABB(Vector3(-2000.0, -200.0, -2000.0), Vector3(4000.0, 400.0, 4000.0))
	_pools_instance.visible = true
	add_child(_pools_instance)


## Lies flat on the ground at spot, tilted to its slope.
func _pool_transform(spot: Vector2, radius: float) -> Transform3D:
	var step := radius * 0.5
	var height := _ground.terrain_height(spot)
	var east := _ground.terrain_height(spot + Vector2(step, 0.0))
	var south := _ground.terrain_height(spot + Vector2(0.0, step))
	var up := Vector3(height - east, step, height - south).normalized()
	var side := Vector3.FORWARD.cross(up).normalized()
	var ahead := up.cross(side).normalized()
	var basis := Basis(side, up, -ahead).orthonormalized() * Basis.from_scale(Vector3(radius, 1.0, radius))
	return Transform3D(basis, Vector3(spot.x, height + POOL_LIFT, spot.y))


func _write_transform(prop: KnockableProp) -> void:
	var multi: MultiMesh = _batches[prop.kind]
	multi.set_instance_transform(_indices[prop], Transform3D(prop.basis(), prop.position))


func _mesh_for(kind: String) -> LowPolyBuilder:
	var b := LowPolyBuilder.new()
	match kind:
		"cone":
			b.box(Vector3(0.0, 0.03, 0.0), Vector3(0.5, 0.06, 0.5), Color(0.1, 0.1, 0.1))
			b.box(Vector3(0.0, 0.2, 0.0), Vector3(0.32, 0.3, 0.32), Color(0.96, 0.42, 0.08))
			b.box(Vector3(0.0, 0.42, 0.0), Vector3(0.22, 0.16, 0.22), Color(0.95, 0.95, 0.95))
			b.box(Vector3(0.0, 0.6, 0.0), Vector3(0.14, 0.2, 0.14), Color(0.96, 0.42, 0.08))
		"bin":
			b.box(Vector3(0.0, 0.5, 0.0), Vector3(0.68, 1.0, 0.68), Color(0.15, 0.4, 0.25))
			b.box(Vector3(0.0, 1.04, 0.0), Vector3(0.74, 0.1, 0.74), Color(0.1, 0.25, 0.16))
		"crate":
			b.box(Vector3(0.0, 0.45, 0.0), Vector3(0.9, 0.9, 0.9), Color(0.6, 0.42, 0.22))
			b.box(Vector3(0.0, 0.9, 0.0), Vector3(0.94, 0.06, 0.94), Color(0.45, 0.3, 0.16))
		"car":
			var glass := Color(0.12, 0.16, 0.2)
			var tyre := Color(0.05, 0.05, 0.06)
			b.box(Vector3(0.0, 0.55, 0.0), Vector3(1.8, 0.55, 4.3), Color.WHITE)
			b.box(Vector3(0.0, 1.05, 0.25), Vector3(1.6, 0.5, 2.3), glass)
			b.box(Vector3(0.0, 1.32, 0.25), Vector3(1.5, 0.06, 2.1), Color.WHITE)
			b.box(Vector3(0.0, 0.34, 2.17), Vector3(1.82, 0.2, 0.08), tyre)
			b.box(Vector3(0.0, 0.34, -2.17), Vector3(1.82, 0.2, 0.08), tyre)
			for z: float in [-1.35, 1.35]:
				for x: float in [-0.85, 0.85]:
					b.box(Vector3(x, 0.32, z), Vector3(0.24, 0.64, 0.64), tyre)
		"jeep":
			# A Willys-style utility jeep ("yipao"). The body is white so it takes
			# the batch's instance colour, as the sedan does.
			var glass := Color(0.12, 0.16, 0.2)
			var tyre := Color(0.05, 0.05, 0.06)
			var canopy := Color(0.95, 0.48, 0.12)
			var sack := Color(0.62, 0.42, 0.24)
			b.box(Vector3(0.0, 0.55, -0.15), Vector3(1.7, 0.5, 2.7), Color.WHITE)
			b.box(Vector3(0.0, 0.74, 1.6), Vector3(1.6, 0.2, 0.9), Color.WHITE)
			b.box(Vector3(0.0, 0.62, 2.12), Vector3(1.5, 0.42, 0.06), Color(0.85, 0.85, 0.86))
			b.box(Vector3(0.0, 0.34, 2.24), Vector3(1.7, 0.16, 0.08), tyre)
			b.box(Vector3(0.0, 1.06, 0.7), Vector3(1.4, 0.5, 0.06), glass)
			for x: float in [-0.7, 0.7]:
				b.box(Vector3(x, 1.0, 0.45), Vector3(0.06, 0.7, 0.06), tyre)
			b.box(Vector3(0.0, 1.36, 0.45), Vector3(1.46, 0.06, 0.06), tyre)
			b.box(Vector3(0.0, 1.28, -0.7), Vector3(1.5, 0.07, 1.5), canopy)
			b.box(Vector3(0.0, 1.0, -1.42), Vector3(1.46, 0.5, 0.07), canopy)
			b.box(Vector3(-0.42, 0.88, -0.75), Vector3(0.5, 0.34, 0.44), sack)
			b.box(Vector3(0.44, 0.88, -0.45), Vector3(0.5, 0.34, 0.44), sack)
			b.box(Vector3(0.0, 0.85, -1.58), Vector3(0.6, 0.6, 0.14), tyre)
			for z: float in [-1.35, 1.35]:
				for x: float in [-0.85, 0.85]:
					b.box(Vector3(x, 0.32, z), Vector3(0.24, 0.64, 0.64), tyre)
		"stall":
			# White parts take the stall's own colour from the batch.
			b.box(Vector3(0.0, 0.62, 0.0), Vector3(1.6, 0.56, 0.86), Color(0.72, 0.56, 0.36))
			b.box(Vector3(0.0, 0.94, 0.0), Vector3(1.66, 0.08, 0.92), Color.WHITE)
			for x: float in [-0.5, 0.0, 0.5]:
				b.box(Vector3(x, 1.03, 0.0), Vector3(0.36, 0.1, 0.6), Color(0.95, 0.75, 0.2))
			for side: float in [-0.62, 0.62]:
				b.box(Vector3(side, 0.18, 0.0), Vector3(0.1, 0.36, 0.7), Color(0.1, 0.1, 0.12))
			b.box(Vector3(0.0, 1.5, 0.0), Vector3(0.06, 2.1, 0.06), Color(0.3, 0.3, 0.32))
			b.flag(Vector3(0.0, 2.75, 0.0), Vector3(-1.4, 2.25, -1.1), Vector3(1.4, 2.25, -1.1), Color.WHITE)
			b.flag(Vector3(0.0, 2.75, 0.0), Vector3(1.4, 2.25, 1.1), Vector3(-1.4, 2.25, 1.1), Color.WHITE)
			b.flag(Vector3(0.0, 2.75, 0.0), Vector3(1.4, 2.25, -1.1), Vector3(1.4, 2.25, 1.1), Color(0.85, 0.85, 0.85))
			b.flag(Vector3(0.0, 2.75, 0.0), Vector3(-1.4, 2.25, 1.1), Vector3(-1.4, 2.25, -1.1), Color(0.85, 0.85, 0.85))
		"moto":
			var tyre := Color(0.05, 0.05, 0.06)
			var skin := Color(0.62, 0.45, 0.33)
			b.box(Vector3(0.0, 0.3, 0.68), Vector3(0.12, 0.6, 0.6), tyre)
			b.box(Vector3(0.0, 0.3, -0.68), Vector3(0.12, 0.6, 0.6), tyre)
			b.box(Vector3(0.0, 0.62, 0.0), Vector3(0.3, 0.32, 1.25), Color.WHITE)
			b.box(Vector3(0.0, 0.84, 0.3), Vector3(0.28, 0.1, 0.7), Color(0.08, 0.08, 0.1))
			b.box(Vector3(0.0, 1.32, 0.16), Vector3(0.42, 0.62, 0.26), Color(0.92, 0.72, 0.18))
			b.box(Vector3(0.0, 0.86, 0.16), Vector3(0.38, 0.3, 0.3), Color(0.16, 0.18, 0.28))
			b.box(Vector3(0.0, 1.76, 0.14), Vector3(0.28, 0.28, 0.3), Color.WHITE)
			for side: float in [-0.25, 0.25]:
				b.box(Vector3(side, 1.2, -0.2), Vector3(0.09, 0.09, 0.62), skin)
		"lamp":
			var pole := Color(0.25, 0.27, 0.3)
			b.box(Vector3(0.0, 0.2, 0.0), Vector3(0.26, 0.4, 0.26), pole)
			b.box(Vector3(0.0, 3.6, 0.0), Vector3(0.14, 7.0, 0.14), pole)
			b.box(Vector3(0.8, 7.05, 0.0), Vector3(1.6, 0.08, 0.08), pole)
			b.box(Vector3(1.6, 6.97, 0.0), Vector3(0.5, 0.1, 0.5), Color(0.8, 0.8, 0.75))
		_:
			b.box(Vector3(0.0, 0.08, 0.0), Vector3(1.5, 0.16, 0.4), Color(0.2, 0.2, 0.2))
			b.box(Vector3(0.0, 0.55, 0.0), Vector3(1.4, 0.3, 0.1), Color(0.92, 0.15, 0.12))
			b.box(Vector3(0.0, 0.9, 0.0), Vector3(1.4, 0.3, 0.1), Color(0.95, 0.95, 0.95))
			for side: float in [-0.6, 0.6]:
				b.box(Vector3(side, 0.55, 0.0), Vector3(0.08, 1.0, 0.08), Color(0.25, 0.25, 0.25))
	return b
