class_name TrafficSystem
extends Node3D
## Draws the traffic, runs the signals' lamps and checks the bus for crashes.
## TrafficFlow does the driving. Sees the bus only through telemetry.

const CAR_HALF_LENGTH := TrafficAgent.CAR_HALF_LENGTH
const CAR_HALF_WIDTH := TrafficAgent.CAR_HALF_WIDTH
const SIGNAL_RANGE := 75.0
const CROSSING_REACH := 5.0 ## Sideways reach of a stop line, in metres.
const LAMP_HEIGHT := 4.3
const CONTACT_CHECK_RADIUS := 14.0
const BUS_FAULT_SPEED := 0.3 ## Slower than this, the bus is not to blame.
const HIT_REPEAT_SECONDS := 1.0
const SEPARATION_PER_TICK := 0.06
## Ticks between ground height checks for each vehicle. In between, the height
## follows the last slope, which is smooth and saves most of the cost.
const GROUND_REFRESH_TICKS := 4

const MOTO_HALF_LENGTH := TrafficAgent.MOTO_HALF_LENGTH
const MOTO_HALF_WIDTH := TrafficAgent.MOTO_HALF_WIDTH
const MOTO_RADIUS := 0.55
const MOTO_COLLISION := 2.0 ## How hard a moto counts as a knock, in m/s lost.
## Share of the bus's speed a moto hit takes off. It was nothing, so the bus
## seemed to drive straight through motorbikes, worst at arcade boost speed.
const MOTO_LOSS_SHARE := 0.4
## How hard a hit moto is thrown clear of the bus's path, sideways, in m/s.
const MOTO_SIDE_SHOVE := 4.0
const LAMP_SHADER := preload("res://assets/shaders/vehicle_lamps.gdshader")
const MOTO_COLOURS: Array[Color] = [
	Color(0.85, 0.15, 0.12), Color(0.12, 0.2, 0.55), Color(0.12, 0.12, 0.14), Color(0.9, 0.9, 0.92), Color(0.15, 0.55, 0.3),
]

var flow: TrafficFlow
var graph: LaneGraph:
	get:
		return flow.graph
var agents: Array[TrafficAgent]:
	get:
		return flow.agents
var plans: Dictionary:
	get:
		return flow.plans
var time: float:
	get:
		return flow.time
	set(value):
		flow.time = value

var _ground: GroundSurface
var _spec: BusSpec:
	get:
		return flow.spec
	set(value):
		flow.spec = value
var _bus_position: Vector2:
	get:
		return flow.bus_rear
	set(value):
		flow.bus_rear = value
var _bus_heading: float:
	get:
		return flow.bus_heading
	set(value):
		flow.bus_heading = value
var _bus_speed: float:
	get:
		return flow.bus_speed
	set(value):
		flow.bus_speed = value
var _bus_active: bool:
	get:
		return flow.bus_active
var _trailer_axle: Vector2:
	get:
		return flow.trailer_axle
var _trailer_heading: float:
	get:
		return flow.trailer_heading
var _batch: MultiMesh
var _lamp_material := ShaderMaterial.new()
var _moto_batch: MultiMesh
var _car_colours: Array[Color] = []
var _lamps: MultiMesh
var _approaches: Array[Dictionary] = [] ## lane, node, group, line, forward.
var _previous_side: Dictionary = {} ## Approach index to sign of bus nose position.
var _tick: int = 0
## The car standing in for a transit police patrol, or -1. PoliceSystem picks it.
var police_index: int = -1
var _police_mesh: MeshInstance3D
var _police_lamps: Array[MeshInstance3D] = []
var _police_flash: float = 0.0


## density is the time of day's share of the usual traffic.
func setup(map_data: Dictionary, network: RoadNetwork, ground: GroundSurface, spec: BusSpec, density: float = 1.0) -> void:
	_ground = ground
	_car_colours = CityTheme.from_data(map_data).car_colours
	flow = TrafficFlow.new(LaneGraph.build(network, map_data), spec)
	flow.horn_sounded.connect(func(spot: Vector2, kind: int) -> void: GameEvents.traffic_horn.emit(spot, kind))
	_build_signals()
	var profile := GraphicsQuality.current_profile()
	flow.spawn(scaled_count(profile["traffic_cars"], density), scaled_count(profile["traffic_motos"], density))
	_build_car_batch()
	_build_police_car()
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.weather_updated.connect(_on_weather)
	GameEvents.lighting_changed.connect(_on_lighting)


## A share of a vehicle count, never fewer than two so a quiet night still has some.
static func scaled_count(count: int, density: float) -> int:
	return maxi(roundi(float(count) * density), mini(count, 2))


func _on_weather(weather: WeatherClock) -> void:
	flow.speed_share = weather.traffic_speed()
	flow.gap_scale = weather.traffic_gap()


func _on_lighting(_lights: float, headlights: bool) -> void:
	_lamp_material.set_shader_parameter("on", 1.0 if headlights else 0.0)


## Lets traffic see cones, bins, stalls and parked cars standing in the road.
func watch_props(props: Array[KnockableProp]) -> void:
	flow.watch_props(props)


func light_at(node_id: String, group: int) -> TrafficLightPlan.Light:
	return flow.light_at(node_id, group)


## The signal the bus is approaching, for the HUD and the autopilot.
## Returns {state, distance} with state -1 when there is none.
func bus_signal() -> Dictionary:
	var forward := Vector2(-sin(_bus_heading), -cos(_bus_heading))
	var nose := _bus_position + forward * (_spec.wheelbase + _spec.front_overhang)
	var best := {"state": -1, "distance": INF}
	for approach in _approaches:
		var direction: Vector2 = approach["forward"]
		if direction.dot(forward) < 0.7:
			continue
		var offset: Vector2 = approach["line"] - nose
		var ahead := offset.dot(direction)
		var across := absf(offset.cross(direction))
		if ahead > -1.0 and ahead < SIGNAL_RANGE and across < CROSSING_REACH and ahead < float(best["distance"]):
			best = {"state": int(light_at(approach["node"], approach["group"])), "distance": ahead}
	return best


## Gap from the bus nose to the nearest car ahead of it, for the autopilot.
func bus_gap_ahead() -> Dictionary:
	var forward := Vector2(-sin(_bus_heading), -cos(_bus_heading))
	var nose := _bus_position + forward * (_spec.wheelbase + _spec.front_overhang)
	var right := Vector2(-forward.y, forward.x)
	var best := {"gap": INF, "speed": 0.0}
	for i in agents.size():
		var agent := agents[i]
		var facing := flow.forwards[i].dot(forward)
		if facing < -0.5:
			continue
		var offset := flow.positions[i] - nose
		var ahead := offset.dot(forward)
		if ahead > 0.0 and ahead < float(best["gap"]) and absf(offset.dot(right)) < 2.3:
			# A car crossing in front is not going our way, so treat it as stopped.
			best = {"gap": ahead - agent.half_length(), "speed": agent.speed if facing > 0.7 else 0.0}
	return best


func _physics_process(dt: float) -> void:
	flow.step(dt)
	_tick += 1
	for i in agents.size():
		_write_car(i, agents[i])
	_check_bus_hits()
	_update_lamps()
	_flash_police(dt)
	if _bus_active:
		_check_red_lights()
		var ahead := bus_signal()
		GameEvents.signal_ahead.emit(ahead["state"], ahead["distance"])


func _on_telemetry(data: BusTelemetry) -> void:
	flow.set_bus(Vector2(data.position.x, data.position.z), data.heading, data.speed, data.trailer_axle, data.trailer_heading, data.door_open_amount > 0.9)


func _position_of(agent: TrafficAgent) -> Vector2:
	return flow.position_of(agent)


## Any contact between the bus and a car counts, whoever is moving. Only a bus
## that was moving is at fault. A car running into a parked bus just stops.
func _check_bus_hits() -> void:
	var forward := Vector2(-sin(_bus_heading), -cos(_bus_heading))
	var bus_velocity := forward * _bus_speed
	var centre := BusFootprint.body_centre(_bus_position, _bus_heading, _spec)
	var reach := CONTACT_CHECK_RADIUS + _spec.full_length() - _spec.overall_length()
	for i in agents.size():
		var agent := agents[i]
		var spot := flow.positions[i]
		if spot.distance_squared_to(centre) > reach * reach:
			continue
		var car_forward := flow.forwards[i]
		if agent.is_moto:
			_check_moto_hit(agent, spot, bus_velocity)
			continue
		if not BusFootprint.touches_car(_bus_position, _bus_heading, _spec, spot, car_forward) and not _trailer_touches(spot, BusFootprint.CAR_CIRCLE_RADIUS):
			continue
		var away := (spot - centre).normalized()
		var closing := (bus_velocity - car_forward * agent.speed).length()
		if absf(_bus_speed) >= BUS_FAULT_SPEED and agent.stunned <= TrafficAgent.STUN_SECONDS - HIT_REPEAT_SECONDS:
			agent.hit_by_bus(bus_velocity)
			flow.honk_after_hit(i)
			var loss := absf(_bus_speed) * ObstacleField.CAR_LOSS_HEAD_ON * 0.7
			GameEvents.obstacle_hit.emit("car", loss)
			if loss > 0.5:
				GameEvents.bus_collided.emit(loss)
		elif closing > 0.0:
			agent.stop_against_bus(away * SEPARATION_PER_TICK)


## A motorbike stays upright: the rider just stops, and the bus takes the blame.
func _check_moto_hit(agent: TrafficAgent, spot: Vector2, bus_velocity: Vector2) -> void:
	if not BusFootprint.touches(_bus_position, _bus_heading, _spec, spot, MOTO_RADIUS) and not _trailer_touches(spot, MOTO_RADIUS):
		return
	if absf(_bus_speed) >= BUS_FAULT_SPEED and agent.stunned <= TrafficAgent.STUN_SECONDS - HIT_REPEAT_SECONDS:
		var forward := Vector2(-sin(_bus_heading), -cos(_bus_heading))
		var away := spot - BusFootprint.body_centre(_bus_position, _bus_heading, _spec)
		var side := away - forward * away.dot(forward)
		if side.length_squared() < 0.0001:
			side = Vector2(-forward.y, forward.x)
		agent.hit_by_bus(bus_velocity * 0.3 + side.normalized() * MOTO_SIDE_SHOVE)
		flow.honk_after_hit(agents.find(agent))
		var loss := absf(_bus_speed) * MOTO_LOSS_SHARE
		GameEvents.obstacle_hit.emit("moto", loss)
		GameEvents.bus_collided.emit(maxf(loss, MOTO_COLLISION))
	else:
		agent.stop_against_bus((spot - _bus_position).normalized() * SEPARATION_PER_TICK)


func _trailer_touches(spot: Vector2, radius: float) -> bool:
	return _spec.is_articulated() and BusFootprint.touches_trailer(_trailer_axle, _trailer_heading, _spec, spot, radius)


func _check_red_lights() -> void:
	var forward := Vector2(-sin(_bus_heading), -cos(_bus_heading))
	var nose := _bus_position + forward * (_spec.wheelbase + _spec.front_overhang)
	for i in _approaches.size():
		var approach: Dictionary = _approaches[i]
		var direction: Vector2 = approach["forward"]
		var offset: Vector2 = nose - approach["line"]
		var side := signf(offset.dot(direction))
		var was: float = _previous_side.get(i, side)
		_previous_side[i] = side
		if was < 0.0 and side > 0.0 and absf(offset.cross(direction)) < CROSSING_REACH and direction.dot(forward) > 0.5:
			if light_at(approach["node"], approach["group"]) == TrafficLightPlan.Light.RED:
				GameEvents.red_light_run.emit()


func _build_car_batch() -> void:
	var field := ObstacleField.new()
	var moto_total := agents.filter(func(agent: TrafficAgent) -> bool: return agent.is_moto).size()
	_lamp_material.shader = LAMP_SHADER
	_batch = _vehicle_batch(field._mesh_for("car"), agents.size() - moto_total, _lamps_for(false))
	_moto_batch = _vehicle_batch(field._mesh_for("moto"), moto_total, _lamps_for(true))
	field.free()
	for i in agents.size():
		var agent := agents[i]
		var colours := MOTO_COLOURS if agent.is_moto else _car_colours
		var batch := _moto_batch if agent.is_moto else _batch
		batch.set_instance_color(agent.batch_index, colours[agent.batch_index % colours.size()])
		_write_car(i, agent)


## Head and tail lamps, as a second part of the vehicle's mesh. One extra draw for
## the whole batch, and they glow after dark through the shader's "on".
func _lamps_for(moto: bool) -> LowPolyBuilder:
	var b := LowPolyBuilder.new()
	if moto:
		b.box(Vector3(0.0, 0.98, -0.62), Vector3(0.16, 0.12, 0.06), Color.WHITE)
		b.box(Vector3(0.0, 0.82, 0.63), Vector3(0.14, 0.08, 0.04), Color.WHITE)
		return b
	for x: float in [-0.62, 0.62]:
		b.box(Vector3(x, 0.66, -2.16), Vector3(0.34, 0.14, 0.04), Color.WHITE)
		b.box(Vector3(x, 0.7, 2.16), Vector3(0.3, 0.12, 0.04), Color.WHITE)
	return b


func _vehicle_batch(builder: LowPolyBuilder, count: int, lamps: LowPolyBuilder) -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	var mesh := builder.build(LowPolyBuilder.vertex_colour_material())
	lamps.build_into(mesh, _lamp_material)
	batch.mesh = mesh
	batch.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	instance.custom_aabb = AABB(Vector3(-2000.0, -200.0, -2000.0), Vector3(4000.0, 400.0, 4000.0))
	add_child(instance)
	return batch


func _write_car(index: int, agent: TrafficAgent) -> void:
	var spot := flow.positions[index]
	var forward := flow.forwards[index]
	if (index + _tick) % GROUND_REFRESH_TICKS == 0 or agent.ground_spot.distance_squared_to(spot) > 9.0:
		agent.ground_spot = spot
		agent.ground_height = _ground.terrain_height(spot)
		agent.ground_slope = (_ground.terrain_height(spot + forward * 2.0) - agent.ground_height) / 2.0
	var height := agent.ground_height + (spot - agent.ground_spot).dot(forward) * agent.ground_slope + 0.12
	var pitch := atan(agent.ground_slope)
	# Turned a little while moving sideways, so a pass looks steered.
	var kerb := Vector2(-forward.y, forward.x) * float(graph.network.traffic_side)
	var facing := (forward * maxf(agent.speed, 1.5) + kerb * agent.shift_rate).normalized()
	var basis := Basis(Vector3.UP, RoadNetwork.heading_of(facing)) * Basis(Vector3.RIGHT, pitch)
	var batch := _moto_batch if agent.is_moto else _batch
	var placed := Transform3D(basis, Vector3(spot.x, height, spot.y))
	if index == police_index:
		# The patrol car is drawn on its own, and its plain copy is hidden.
		_police_mesh.global_transform = placed
		batch.set_instance_transform(agent.batch_index, Transform3D(Basis().scaled(Vector3.ZERO), placed.origin))
		return
	batch.set_instance_transform(agent.batch_index, placed)


const POLICE_WHITE := Color(0.95, 0.96, 0.97)
const POLICE_GREEN := Color(0.08, 0.5, 0.26)
const POLICE_FLASH_SECONDS := 0.3
## A patrol is picked from cars this far from the bus, in metres, nearest to
## POLICE_PICK_IDEAL first, so it is close enough to notice but not on top of it.
const POLICE_PICK_NEAR := 25.0
const POLICE_PICK_FAR := 140.0
const POLICE_PICK_IDEAL := 60.0


## A white car with a green band and a light bar, shown in place of one traffic car.
func _build_police_car() -> void:
	var field := ObstacleField.new()
	var body := field._mesh_for("car")
	field.free()
	for side: float in [-1.0, 1.0]:
		body.box(Vector3(side * 0.91, 0.62, 0.0), Vector3(0.03, 0.2, 4.1), POLICE_GREEN)
	body.box(Vector3(0.0, 1.4, 0.25), Vector3(1.1, 0.08, 0.32), Color(0.15, 0.15, 0.17))
	var material := LowPolyBuilder.vertex_colour_material()
	material.albedo_color = POLICE_WHITE
	_police_mesh = MeshInstance3D.new()
	_police_mesh.mesh = body.build(material)
	_police_mesh.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_police_mesh.visible = false
	add_child(_police_mesh)
	for entry: Array in [[-0.3, Color(0.95, 0.15, 0.15)], [0.3, Color(0.2, 0.4, 1.0)]]:
		var lamp := LowPolyBuilder.new()
		lamp.box(Vector3(entry[0], 1.49, 0.25), Vector3(0.42, 0.1, 0.26), Color.WHITE)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = entry[1]
		var instance := MeshInstance3D.new()
		instance.mesh = lamp.build(glow)
		_police_mesh.add_child(instance)
		_police_lamps.append(instance)


## Turns the car nearest a good distance from the bus into the patrol: one
## between POLICE_PICK_NEAR and POLICE_PICK_FAR if there is one, else the nearest
## beyond POLICE_PICK_NEAR. False only if there are no cars at all.
func assign_police(near: Vector2) -> bool:
	var best := -1
	var best_score := INF
	for i in agents.size():
		var agent := agents[i]
		if agent.is_moto or agent.stunned > 0.0:
			continue
		var distance := flow.positions[i].distance_to(near)
		if distance < POLICE_PICK_NEAR:
			continue
		var score := absf(distance - POLICE_PICK_IDEAL) if distance <= POLICE_PICK_FAR else distance * 10.0
		if score < best_score:
			best_score = score
			best = i
	if best < 0:
		return false
	clear_police()
	police_index = best
	_police_mesh.visible = true
	return true


func clear_police() -> void:
	if police_index >= 0:
		var agent := agents[police_index]
		police_index = -1
		_write_car(agents.find(agent), agent)
	_police_mesh.visible = false


func police_distance(to: Vector2) -> float:
	return flow.positions[police_index].distance_to(to) if police_index >= 0 else INF


func police_position() -> Vector2:
	return flow.positions[police_index] if police_index >= 0 else Vector2(INF, INF)


func _flash_police(dt: float) -> void:
	if police_index < 0:
		return
	_police_flash += dt
	var red_on := int(_police_flash / POLICE_FLASH_SECONDS) % 2 == 0
	_police_lamps[0].visible = red_on
	_police_lamps[1].visible = not red_on


func _build_signals() -> void:
	var nodes := graph.signal_nodes()
	for i in nodes.size():
		var node_id: String = nodes[i]
		for lane_index: int in graph.into_node[node_id]:
			var lane: TrafficLane = graph.lanes[lane_index]
			var line := lane.points[lane.points.size() - 1]
			var forward := lane.forward_at(lane.length - 0.1)
			_approaches.append({"lane": lane_index, "node": node_id, "group": lane.group, "line": line, "forward": forward})
	var housing := LowPolyBuilder.new()
	var lens := LowPolyBuilder.new()
	lens.box(Vector3.ZERO, Vector3(0.24, 0.24, 0.05), Color.WHITE)
	_lamps = MultiMesh.new()
	_lamps.transform_format = MultiMesh.TRANSFORM_3D
	_lamps.use_colors = true
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamps.mesh = lens.build(material)
	_lamps.instance_count = _approaches.size() * 3
	for i in _approaches.size():
		_build_signal_head(housing, i)
	var lamps_instance := MultiMeshInstance3D.new()
	lamps_instance.multimesh = _lamps
	lamps_instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	lamps_instance.custom_aabb = AABB(Vector3(-2000.0, -200.0, -2000.0), Vector3(4000.0, 400.0, 4000.0))
	lamps_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamps_instance)
	var poles := MeshInstance3D.new()
	poles.mesh = housing.build(LowPolyBuilder.vertex_colour_material())
	add_child(poles)


## Each approach has a pole at the near-side corner, facing oncoming drivers.
func _build_signal_head(housing: LowPolyBuilder, index: int) -> void:
	var approach: Dictionary = _approaches[index]
	var forward: Vector2 = approach["forward"]
	var kerb := Vector2(-forward.y, forward.x) * float(graph.network.traffic_side)
	var spot: Vector2 = approach["line"] + kerb * 2.6
	var y := _ground.terrain_height(spot)
	var yaw := RoadNetwork.heading_of(forward)
	var pole := Color(0.15, 0.16, 0.18)
	housing.turned_box(Vector3(spot.x, y + 2.2, spot.y), Vector3(0.13, 4.4, 0.13), yaw, pole)
	var head := Vector3(spot.x, y + LAMP_HEIGHT, spot.y)
	housing.turned_box(head, Vector3(0.42, 1.1, 0.2), yaw, Color(0.05, 0.05, 0.06))
	var facing := Vector3(-forward.x, 0.0, -forward.y) * 0.13
	var basis := Basis(Vector3.UP, yaw)
	for lamp in 3:
		var at := head + facing + Vector3.UP * (0.32 - 0.32 * lamp)
		_lamps.set_instance_transform(index * 3 + lamp, Transform3D(basis, at))


func _update_lamps() -> void:
	var dim := Color(0.12, 0.12, 0.13)
	for i in _approaches.size():
		var approach: Dictionary = _approaches[i]
		var light := light_at(approach["node"], approach["group"])
		_lamps.set_instance_color(i * 3, Color(1.0, 0.15, 0.1) if light == TrafficLightPlan.Light.RED else dim)
		_lamps.set_instance_color(i * 3 + 1, Color(1.0, 0.7, 0.1) if light == TrafficLightPlan.Light.AMBER else dim)
		_lamps.set_instance_color(i * 3 + 2, Color(0.15, 1.0, 0.4) if light == TrafficLightPlan.Light.GREEN else dim)
