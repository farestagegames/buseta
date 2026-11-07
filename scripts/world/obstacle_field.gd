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
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)


func _add_prop(kind: String, ground_position: Vector2, yaw: float) -> void:
	var height := _ground.height_at(ground_position) + 0.1
	var start := Vector3(ground_position.x, height, ground_position.y)
	props.append(KnockableProp.new(kind, start, KINDS[kind]["radius"], yaw))


func _physics_process(dt: float) -> void:
	for prop in props:
		if prop.is_moving() or prop.cooldown > 0.0 or prop.in_contact():
			prop.update(dt, _ground.height_at(Vector2(prop.position.x, prop.position.z)) + 0.1)
			_write_transform(prop)


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
	for kind: String in counts:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = kind == "car" or kind == "stall"
		multi.mesh = _mesh_for(kind).build(material)
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
