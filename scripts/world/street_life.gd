class_name StreetLife
extends Node3D
## People walking the pavements. They are drawn as one instanced batch and only
## ever follow the pavement, so a busy street costs almost nothing.

const SIDE_DISTANCE := RoadNetwork.ROAD_HALF_WIDTH + 1.7
## Near a bus stop the pavement moves back to make room for the bay.
const AROUND_A_BAY := 2.8
const WALK_LOW := 0.9
const WALK_HIGH := 1.5

var strollers: Array[Stroller] = []

var _ground: GroundSurface
var _batch: MultiMesh


class Stroller:
	var path: PackedVector2Array
	var segment: int = 0
	var along: float = 0.0
	var speed: float = 1.2
	var heading: int = 1

	## Walks to the end of the pavement, then turns around.
	func walk(dt: float) -> void:
		along += speed * dt
		var length := path[segment].distance_to(path[segment + heading])
		while along >= length:
			along -= length
			var next := segment + heading
			if next + heading < 0 or next + heading >= path.size():
				heading = -heading
			else:
				segment = next
			length = path[segment].distance_to(path[segment + heading])

	func position() -> Vector2:
		var start := path[segment]
		var finish := path[segment + heading]
		return start.move_toward(finish, along)

	func direction() -> Vector2:
		return (path[segment + heading] - path[segment]).normalized()


func setup(network: RoadNetwork, ground: GroundSurface, route: RouteRunner) -> void:
	_ground = ground
	var random := RandomNumberGenerator.new()
	random.seed = 909
	var roads: Array = network.roads.values().filter(func(road: Dictionary) -> bool: return road["length"] > 80.0)
	var count: int = GraphicsQuality.current_profile()["pedestrians"]
	for i in count:
		var road: Dictionary = roads[i % roads.size()]
		var side := 1.0 if i % 2 == 0 else -1.0
		var stroller := Stroller.new()
		stroller.path = _pavement(network, road, side, route)
		stroller.segment = random.randi_range(1, stroller.path.size() - 3)
		stroller.heading = 1 if random.randf() < 0.5 else -1
		stroller.speed = random.randf_range(WALK_LOW, WALK_HIGH)
		strollers.append(stroller)
	_build_batch(random)


func _pavement(network: RoadNetwork, road: Dictionary, side: float, route: RouteRunner) -> PackedVector2Array:
	var path := PackedVector2Array()
	var along := 22.0
	var last: float = float(road["length"]) - 22.0
	while along < last:
		var placed: Dictionary = network.sample(road["id"], along, SIDE_DISTANCE * side)
		var spot: Vector2 = placed["position"]
		for stop in route.stops:
			if spot.distance_to(stop.position) < RoadNetwork.BAY_LENGTH:
				spot = network.sample(road["id"], along, (SIDE_DISTANCE + AROUND_A_BAY) * side)["position"]
		path.append(spot)
		along += RoadNetwork.SAMPLE_SPACING * 2.0
	return path


func _build_batch(random: RandomNumberGenerator) -> void:
	var b := LowPolyBuilder.new()
	b.box(Vector3(0.0, 1.22, 0.0), Vector3(0.42, 0.62, 0.24), Color.WHITE)
	b.box(Vector3(0.0, 0.46, 0.0), Vector3(0.36, 0.9, 0.2), Color(0.28, 0.28, 0.3))
	b.box(Vector3(0.0, 1.66, 0.0), Vector3(0.22, 0.24, 0.22), Color(0.7, 0.55, 0.45))
	_batch = MultiMesh.new()
	_batch.transform_format = MultiMesh.TRANSFORM_3D
	_batch.use_colors = true
	_batch.mesh = b.build(LowPolyBuilder.vertex_colour_material())
	_batch.instance_count = strollers.size()
	var tops: Array = Country.pack.passengers()["tops"]
	for i in strollers.size():
		var top: Array = tops[random.randi_range(0, tops.size() - 1)]
		_batch.set_instance_color(i, Color(top[0], top[1], top[2]))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _batch
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	instance.custom_aabb = AABB(Vector3(-2000.0, -200.0, -2000.0), Vector3(4000.0, 400.0, 4000.0))
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _process(dt: float) -> void:
	for i in strollers.size():
		var stroller := strollers[i]
		stroller.walk(dt)
		var spot := stroller.position()
		var facing := RoadNetwork.heading_of(stroller.direction())
		_batch.set_instance_transform(i, Transform3D(Basis(Vector3.UP, facing), Vector3(spot.x, _ground.terrain_height(spot) + 0.12, spot.y)))
