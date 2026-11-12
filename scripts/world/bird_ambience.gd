class_name BirdAmbience
extends Node3D
## Positional birds from the map's clusters. Sound plays at every cluster; the
## selected flocks share one low-poly MultiMesh and only fly when the bus is near.

const DEFAULT_SOUND := "res://assets/audio/ambience/birds.wav"
const SILENT_DB := -80.0
const BIRD_DB := -7.0
const FADE_SECONDS := 0.8
const NIGHT_LIGHTS := 0.3

var players: Array[AudioStreamPlayer3D] = []
var start_offsets := PackedFloat32Array()
var sound_level: float = 1.0

var _flocks: Array[Dictionary] = []
var _batch: MultiMesh
var _bus_spot := Vector3.ZERO
var _has_bus: bool = false
var _rain: float = 0.0
var _night: bool = false
var _random := RandomNumberGenerator.new()


func setup(map_data: Dictionary, ground: GroundSurface, time_of_day: TimeOfDay, random_seed: int = 0) -> void:
	_random.seed = random_seed
	_night = time_of_day.is_dark()
	sound_level = _target_gain()
	var entries: Array = map_data.get("bird_clusters", [])
	var stream: AudioStream = null
	if not entries.is_empty():
		stream = AudioDirector.looped(load(Country.pack.resolve(Country.pack.sound("birds", DEFAULT_SOUND))))
	var bird_total := 0
	for entry: Dictionary in entries:
		var centre := Vector3(float(entry["x"]), ground.terrain_height(Vector2(float(entry["x"]), float(entry["z"]))) + float(entry["perch"]), float(entry["z"]))
		var player := AudioStreamPlayer3D.new()
		player.stream = stream
		player.position = centre
		player.max_distance = float(entry["range"])
		player.unit_size = maxf(1.0, float(entry["range"]) * 0.4)
		add_child(player)
		players.append(player)
		var offset := _random.randf() * stream.get_length()
		start_offsets.append(offset)
		player.play(offset)
		var count := int(entry["flock"])
		if count > 0:
			_flocks.append({"state": BirdFlockState.new(), "centre": centre, "count": count, "first": bird_total})
			bird_total += count
	if bool(GraphicsQuality.current_profile().get("bird_flocks", true)) and bird_total > 0:
		_build_flocks(bird_total)
	_apply_sound(0.0)
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.rain_changed.connect(_on_rain)
	GameEvents.weather_updated.connect(_on_weather)
	GameEvents.lighting_changed.connect(_on_lighting)


func flock_visual_count() -> int:
	return _batch.instance_count if _batch != null else 0


func _build_flocks(count: int) -> void:
	var shape := LowPolyBuilder.new()
	var feathers := Color(0.16, 0.2, 0.22)
	shape.box(Vector3(0.0, 0.16, 0.0), Vector3(0.2, 0.2, 0.42), feathers)
	shape.box(Vector3(0.0, 0.28, -0.2), Vector3(0.16, 0.16, 0.16), feathers.lightened(0.08))
	shape.box(Vector3(0.0, 0.27, -0.32), Vector3(0.06, 0.04, 0.12), Color(0.85, 0.65, 0.18))
	shape.box(Vector3(0.0, 0.15, 0.28), Vector3(0.12, 0.05, 0.24), feathers.darkened(0.12))
	shape.flag(Vector3(-0.08, 0.2, -0.12), Vector3(-0.62, 0.18, 0.08), Vector3(-0.08, 0.18, 0.18), feathers.lightened(0.12))
	shape.flag(Vector3(0.08, 0.2, -0.12), Vector3(0.08, 0.18, 0.18), Vector3(0.62, 0.18, 0.08), feathers.lightened(0.12))
	_batch = MultiMesh.new()
	_batch.transform_format = MultiMesh.TRANSFORM_3D
	_batch.mesh = shape.build(LowPolyBuilder.vertex_colour_material())
	_batch.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	instance.custom_aabb = AABB(Vector3(-2000.0, -200.0, -2000.0), Vector3(4000.0, 400.0, 4000.0))
	add_child(instance)
	for flock: Dictionary in _flocks:
		_write_flock(flock)


func _process(dt: float) -> void:
	_apply_sound(dt)
	if _batch == null or not _has_bus:
		return
	for flock: Dictionary in _flocks:
		var state: BirdFlockState = flock["state"]
		var was_flying := state.is_flying()
		state.update(dt, _bus_spot, flock["centre"])
		if was_flying or state.is_flying():
			_write_flock(flock)


func _write_flock(flock: Dictionary) -> void:
	var state: BirdFlockState = flock["state"]
	var centre: Vector3 = flock["centre"]
	var first := int(flock["first"])
	for i in int(flock["count"]):
		var yaw := -float(i) * 2.399963
		var orientation := Basis(Vector3.UP, yaw)
		if state.is_flying():
			orientation = orientation * Basis(Vector3.FORWARD, sin(state.elapsed * 12.0 + float(i)) * 0.12)
		_batch.set_instance_transform(first + i, Transform3D(orientation, state.bird_position(i, centre)))


func _on_telemetry(telemetry: BusTelemetry) -> void:
	_bus_spot = telemetry.position
	_has_bus = true


func _on_rain(amount: float) -> void:
	_rain = clampf(amount, 0.0, 1.0)


func _on_weather(weather: WeatherClock) -> void:
	_rain = clampf(weather.rain, 0.0, 1.0)
	_night = weather.time.is_dark()


func _on_lighting(lights: float, _headlights: bool) -> void:
	_night = lights >= NIGHT_LIGHTS


func _target_gain() -> float:
	return 0.0 if _night else 1.0 - _rain


## Ease the shared gain, then pause inaudible loops so they cost nothing to mix.
func _apply_sound(dt: float) -> void:
	var target := _target_gain()
	if dt > 0.0 and sound_level == target:
		return
	sound_level = move_toward(sound_level, target, dt / FADE_SECONDS)
	var silent := sound_level <= 0.0001
	var volume := SILENT_DB if silent else BIRD_DB + linear_to_db(maxf(sound_level, 0.001))
	for player: AudioStreamPlayer3D in players:
		if player.stream_paused != silent:
			player.stream_paused = silent
		if absf(player.volume_db - volume) > 0.01:
			player.volume_db = volume
