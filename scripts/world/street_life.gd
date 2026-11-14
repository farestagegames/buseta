class_name StreetLife
extends Node3D
## People walking the pavements. They are drawn as three instanced batches, for
## clothes, skin and hair, and only ever follow the pavement, so a busy street costs
## almost nothing. Each is one of the pack's passenger looks.

const SIDE_DISTANCE := RoadNetwork.ROAD_HALF_WIDTH + 1.7
## Near a bus stop the pavement moves back to make room for the bay.
const AROUND_A_BAY := 2.8
const WALK_LOW := 0.9
const WALK_HIGH := 1.5
## People hurry in the rain, by up to this share faster.
const RAIN_HURRY := 0.5
const UMBRELLA_COLOURS: Array[Color] = [
	Color(0.12, 0.12, 0.14), Color(0.85, 0.15, 0.2), Color(0.15, 0.35, 0.75), Color(0.98, 0.78, 0.1), Color(0.2, 0.6, 0.35),
]
const VENDOR_OFFSET := 1.05
const VENDOR_STEP_BACK := 0.45

var strollers: Array[Stroller] = []
var vendors: Array[Vendor] = []

var _ground: GroundSurface
var _network: RoadNetwork
var _obstacles: ObstacleField
var _batches: Array[MultiMesh] = [] ## Clothes, skin, then hair.
var _umbrellas: MultiMesh
var _out_share: float = 1.0 ## Share of walkers still out, lower in a downpour.
var _umbrella_share: float = 0.0
var _hurry: float = 1.0


class Vendor:
	var stall: KnockableProp
	var position_3d: Vector3 = Vector3.ZERO
	var spot: Vector2 = Vector2.ZERO
	var standing_spot: Vector2 = Vector2.ZERO
	var knocked_spot: Vector2 = Vector2.ZERO
	var heading: float = 0.0
	var look: PassengerLook
	var stepped_back: bool = false
	var carries_umbrella: bool = false
	var instance_index: int = -1
	var _life: StreetLife = null

	func _init(stall_prop: KnockableProp, standing: Vector2, knocked: Vector2, face_heading: float, vendor_look: PassengerLook, ground_height: float, life_node: StreetLife) -> void:
		stall = stall_prop
		standing_spot = standing
		knocked_spot = knocked
		spot = standing
		heading = face_heading
		look = vendor_look
		_life = life_node
		position_3d = Vector3(spot.x, ground_height, spot.y)
		if stall != null:
			stall.vendor = self

	func position() -> Vector2:
		return spot

	func ground_position() -> Vector2:
		return spot

	func step_back() -> void:
		if stepped_back:
			return
		stepped_back = true
		spot = knocked_spot
		if _life != null and _life._ground != null:
			position_3d = Vector3(spot.x, _life._ground.terrain_height(spot) + 0.12, spot.y)
			_life._write_vendor_transform(self)

	func on_stall_knocked() -> void:
		step_back()

	func is_knocked() -> bool:
		return stepped_back or (stall != null and stall.is_knocked())

	func is_inside_stall(check_stall: KnockableProp = null) -> bool:
		var target := check_stall if check_stall != null else stall
		if target == null:
			return false
		var stall_2d := Vector2(target.position.x, target.position.z)
		return spot.distance_to(stall_2d) < target.radius

	func is_in_road(network: RoadNetwork) -> bool:
		if network == null:
			return false
		return network.edge_distance(spot) <= 0.0

	func is_on_pavement(network: RoadNetwork) -> bool:
		if network == null:
			return false
		var dist := network.edge_distance(spot)
		return dist > 0.0 and dist <= GroundSurface.PAVEMENT_WIDTH


class Stroller:
	var path: PackedVector2Array
	var segment: int = 0
	var along: float = 0.0
	var speed: float = 1.2
	var heading: int = 1
	var look: PassengerLook ## Who is walking, which sets their colours and size.

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


## density is the time of day's share of the usual number of people about.
func setup(network: RoadNetwork, ground: GroundSurface, route: RouteRunner = null, density: float = 1.0, obstacles: ObstacleField = null) -> void:
	_ground = ground
	_network = network
	_obstacles = obstacles
	var random := RandomNumberGenerator.new()
	random.seed = 909

	if obstacles != null:
		_setup_vendors(obstacles, network, ground)

	var roads: Array = network.roads.values().filter(func(road: Dictionary) -> bool: return road["length"] > 80.0)
	var count := TrafficSystem.scaled_count(GraphicsQuality.current_profile()["pedestrians"], density)
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


func _setup_vendors(obstacles: ObstacleField, network: RoadNetwork, ground: GroundSurface) -> void:
	vendors.clear()
	var stall_props := obstacles.stalls()
	for stall_prop in stall_props:
		var stall_2d := Vector2(stall_prop.position.x, stall_prop.position.z)
		var forward := stall_prop.forward
		if forward == Vector2.ZERO:
			forward = Vector2(-sin(stall_prop.rotation.y), -cos(stall_prop.rotation.y))
		var right := Vector2(-forward.y, forward.x)
		var kerb_side := 1.0 if stall_prop.dir == 0 else float(network.traffic_side)
		var away_from_road := (right * kerb_side).normalized()
		var towards_road := -away_from_road

		var standing_spot := stall_2d + away_from_road * VENDOR_OFFSET
		var knocked_spot := stall_2d + away_from_road * (VENDOR_OFFSET + VENDOR_STEP_BACK)
		var facing := RoadNetwork.heading_of(towards_road)
		var height := ground.terrain_height(standing_spot) + 0.12

		var vendor := Vendor.new(stall_prop, standing_spot, knocked_spot, facing, null, height, self)
		vendors.append(vendor)

	obstacles.vendors = vendors


func _pavement(network: RoadNetwork, road: Dictionary, side: float, route: RouteRunner) -> PackedVector2Array:
	var path := PackedVector2Array()
	var along := 22.0
	var last: float = float(road["length"]) - 22.0
	while along < last:
		var placed: Dictionary = network.sample(road["id"], along, SIDE_DISTANCE * side)
		var spot: Vector2 = placed["position"]
		if route != null:
			for stop in route.stops:
				if spot.distance_to(stop.position) < RoadNetwork.BAY_LENGTH:
					spot = network.sample(road["id"], along, (SIDE_DISTANCE + AROUND_A_BAY) * side)["position"]
		path.append(spot)
		along += RoadNetwork.SAMPLE_SPACING * 2.0
	return path


## Instance colours multiply the mesh's own, so each batch is white where it takes
## a look's colour: the shirt, the face and hands, and the hair or hat.
func _build_batch(random: RandomNumberGenerator) -> void:
	var clothes := LowPolyBuilder.new()
	clothes.box(Vector3(0.0, 1.22, 0.0), Vector3(0.42, 0.62, 0.24), Color.WHITE)
	clothes.box(Vector3(0.0, 0.48, 0.0), Vector3(0.36, 0.86, 0.2), Color(0.28, 0.28, 0.3))
	# Chunky shoes, dark whatever the top's colour, poking out in front.
	for side: float in [-0.1, 0.1]:
		clothes.box(Vector3(side, 0.05, -0.04), Vector3(0.15, 0.1, 0.3), Color(0.07, 0.07, 0.08))
	var skin := LowPolyBuilder.new()
	skin.box(Vector3(0.0, 1.69, 0.0), Vector3(0.3, 0.3, 0.28), Color.WHITE)
	for side: float in [-0.25, 0.25]:
		skin.box(Vector3(side, 0.95, 0.0), Vector3(0.1, 0.12, 0.1), Color.WHITE)
	var hair := LowPolyBuilder.new()
	hair.box(Vector3(0.0, 1.87, 0.01), Vector3(0.32, 0.07, 0.3), Color.WHITE)
	hair.box(Vector3(0.0, 1.76, 0.13), Vector3(0.32, 0.2, 0.05), Color.WHITE)
	var material := LowPolyBuilder.vertex_colour_material()
	for builder: LowPolyBuilder in [clothes, skin, hair]:
		_batches.append(_batch_of(builder, material))

	var cast := Country.pack.passenger_looks()
	var looks := cast.looks
	var vendor_looks := cast.vendors if not cast.vendors.is_empty() else looks

	for i in vendors.size():
		var vendor := vendors[i]
		vendor.instance_index = i
		var look: PassengerLook = vendor_looks[i % vendor_looks.size()]
		vendor.look = look
		_batches[0].set_instance_color(i, look.top)
		_batches[1].set_instance_color(i, look.skin)
		_batches[2].set_instance_color(i, look.crown_colour())
		_write_vendor_transform(vendor)

	for i in strollers.size():
		var batch_idx := vendors.size() + i
		var look := looks[random.randi_range(0, looks.size() - 1)]
		strollers[i].look = look
		strollers[i].speed *= look.pace
		_batches[0].set_instance_color(batch_idx, look.top)
		_batches[1].set_instance_color(batch_idx, look.skin)
		_batches[2].set_instance_color(batch_idx, look.crown_colour())

	_umbrellas = _batch_of(_umbrella_shape(), material)
	for i in vendors.size():
		_umbrellas.set_instance_color(i, UMBRELLA_COLOURS[i % UMBRELLA_COLOURS.size()])
		_umbrellas.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), vendors[i].position_3d))
	for i in strollers.size():
		var batch_idx := vendors.size() + i
		_umbrellas.set_instance_color(batch_idx, UMBRELLA_COLOURS[batch_idx % UMBRELLA_COLOURS.size()])
		_umbrellas.set_instance_transform(batch_idx, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))

	_umbrellas.visible_instance_count = 0
	GameEvents.weather_updated.connect(_on_weather)


func _write_vendor_transform(vendor: Vendor) -> void:
	if vendor.instance_index < 0 or _batches.is_empty():
		return
	var rot_basis := Basis(Vector3.UP, vendor.heading).scaled(Vector3.ONE * vendor.look.size)
	var place := Transform3D(rot_basis, vendor.position_3d)
	for batch in _batches:
		batch.set_instance_transform(vendor.instance_index, place)
	if _umbrellas != null:
		var carries := vendor.carries_umbrella and _umbrella_share > 0.0
		_umbrellas.set_instance_transform(vendor.instance_index, place if carries else Transform3D(Basis().scaled(Vector3.ZERO), place.origin))


## A canopy over the head on a short stick, held in one hand.
func _umbrella_shape() -> LowPolyBuilder:
	var b := LowPolyBuilder.new()
	b.box(Vector3(0.25, 1.55, 0.0), Vector3(0.03, 0.7, 0.03), Color(0.2, 0.2, 0.2))
	b.box(Vector3(0.12, 2.08, 0.0), Vector3(1.0, 0.06, 1.0), Color.WHITE)
	b.box(Vector3(0.12, 2.15, 0.0), Vector3(0.62, 0.08, 0.62), Color.WHITE)
	return b


## In a downpour most people shelter, and those still out hurry, some under umbrellas.
func _on_weather(weather: WeatherClock) -> void:
	_out_share = weather.pedestrians()
	_umbrella_share = weather.umbrellas()
	_hurry = 1.0 + RAIN_HURRY * clampf(weather.rain * 1.5, 0.0, 1.0)
	var shown_strollers := walkers_out(strollers.size(), _out_share)
	var total_shown := vendors.size() + shown_strollers
	for batch in _batches:
		batch.visible_instance_count = total_shown
	_umbrellas.visible_instance_count = total_shown if _umbrella_share > 0.0 else 0
	for vendor in vendors:
		vendor.carries_umbrella = _umbrella_share > 0.0
		_write_vendor_transform(vendor)


## How many of count walkers are out when share of them are. Never all gone.
static func walkers_out(count: int, share: float) -> int:
	return clampi(ceili(float(count) * share), mini(count, 2), count)


func _batch_of(builder: LowPolyBuilder, material: Material) -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = builder.build(material)
	batch.instance_count = vendors.size() + strollers.size()
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	instance.custom_aabb = AABB(Vector3(-2000.0, -200.0, -2000.0), Vector3(4000.0, 400.0, 4000.0))
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return batch


func _process(dt: float) -> void:
	for vendor in vendors:
		if not vendor.stepped_back and vendor.stall != null and vendor.stall.is_knocked():
			vendor.step_back()

	var shown := _batches[0].visible_instance_count if not _batches.is_empty() else (vendors.size() + strollers.size())
	if shown < 0:
		shown = vendors.size() + strollers.size()
	var stroller_shown: int = maxi(0, shown - vendors.size())
	var umbrellas := _umbrellas != null and _umbrellas.visible_instance_count > 0

	for i in strollers.size():
		var stroller := strollers[i]
		stroller.walk(dt * _hurry)
		if i >= stroller_shown:
			continue
		var spot := stroller.position()
		var facing := RoadNetwork.heading_of(stroller.direction())
		var rot_basis := Basis(Vector3.UP, facing).scaled(Vector3.ONE * stroller.look.size)
		var place := Transform3D(rot_basis, Vector3(spot.x, _ground.terrain_height(spot) + 0.12, spot.y))
		var batch_idx := vendors.size() + i
		for batch in _batches:
			batch.set_instance_transform(batch_idx, place)
		if umbrellas:
			# A steady share carry one; the rest walk with their heads down.
			var carries := float((i * 37) % 100) / 100.0 < _umbrella_share
			_umbrellas.set_instance_transform(batch_idx, place if carries else Transform3D(Basis().scaled(Vector3.ZERO), place.origin))
