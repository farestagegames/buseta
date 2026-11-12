extends GutTest
## Positional bird sound, deterministic flock flights and map validation.

var _quality: int


func before_each() -> void:
	_quality = GameSettings.graphics_quality


func after_each() -> void:
	GameSettings.graphics_quality = _quality


func _cluster(id: String = "trees", flock: int = 4, hearing_range: float = 30.0) -> Dictionary:
	return {"id": id, "x": 10.0, "z": 20.0, "perch": 3.0, "flock": flock, "range": hearing_range}


func _make(entries: Array, quality: int = GraphicsQuality.Level.HIGH, lights: float = 0.0) -> BirdAmbience:
	GameSettings.graphics_quality = quality
	var birds := BirdAmbience.new()
	add_child_autofree(birds)
	birds.set_process(false)
	var time := TimeOfDay.new()
	time.lights = lights
	birds.setup({"bird_clusters": entries}, GroundSurface.new(), time, 23)
	return birds


func test_one_positional_looping_player_per_cluster_with_its_own_range() -> void:
	var first := _cluster("palms", 0, 25.0)
	var second := _cluster("roof", 3, 35.0)
	second["x"] = -8.0
	second["z"] = 42.0
	second["perch"] = 5.0
	var birds := _make([first, second])
	assert_eq(birds.players.size(), 2)
	for i in 2:
		var entry: Dictionary = [first, second][i]
		var player := birds.players[i]
		var expected := Vector3(float(entry["x"]), float(entry["perch"]), float(entry["z"]))
		assert_almost_eq(player.global_position.distance_to(expected), 0.0, 0.001)
		assert_eq(player.max_distance, float(entry["range"]))
		var wav := player.stream as AudioStreamWAV
		assert_not_null(wav)
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		assert_between(birds.start_offsets[i], 0.0, wav.get_length())
	assert_ne(birds.start_offsets[0], birds.start_offsets[1], "Loops do not all start together")


func test_flock_takes_off_only_near_the_bus_and_eventually_returns() -> void:
	var flock := BirdFlockState.new()
	var centre := Vector3(10.0, 3.0, 20.0)
	var settled := flock.bird_position(0, centre)
	flock.update(0.1, centre + Vector3(BirdFlockState.TAKEOFF_RANGE + 1.0, 0.0, 0.0), centre)
	assert_eq(flock.phase, BirdFlockState.Phase.PERCHED)
	flock.update(0.1, centre + Vector3(BirdFlockState.TAKEOFF_RANGE - 1.0, 0.0, 0.0), centre)
	assert_eq(flock.phase, BirdFlockState.Phase.OUTBOUND)
	flock.update(1.0, centre + Vector3(100.0, 0.0, 0.0), centre)
	assert_gt(flock.bird_position(0, centre).distance_to(settled), 0.1)
	for i in 12:
		flock.update(1.0, centre + Vector3(100.0, 0.0, 0.0), centre)
	assert_eq(flock.phase, BirdFlockState.Phase.PERCHED)
	assert_eq(flock.bird_position(0, centre), settled)


func test_fake_bus_telemetry_drives_the_same_flight_as_real_telemetry() -> void:
	var birds := _make([_cluster()])
	var state: BirdFlockState = birds._flocks[0]["state"]
	var centre: Vector3 = birds._flocks[0]["centre"]
	var telemetry := BusTelemetry.new()
	telemetry.position = Vector3(26.0, 0.0, 20.0)
	GameEvents.bus_telemetry_updated.emit(telemetry)
	birds._process(0.1)
	assert_eq(state.phase, BirdFlockState.Phase.PERCHED)
	telemetry.position = Vector3(10.0, 0.0, 20.0)
	GameEvents.bus_telemetry_updated.emit(telemetry)
	birds._process(0.1)
	assert_eq(state.phase, BirdFlockState.Phase.OUTBOUND)
	var before: Vector3 = state.bird_position(0, centre)
	birds._process(0.2)
	assert_gt(state.bird_position(0, centre).distance_to(before), 0.01, "The pooled bird's flight transform moves too")


func test_full_rain_and_night_fade_and_pause_every_player() -> void:
	var birds := _make([_cluster("one"), _cluster("two", 0)])
	GameEvents.rain_changed.emit(1.0)
	birds._process(BirdAmbience.FADE_SECONDS)
	assert_eq(birds.sound_level, 0.0)
	for player: AudioStreamPlayer3D in birds.players:
		assert_eq(player.volume_db, BirdAmbience.SILENT_DB)
	GameEvents.rain_changed.emit(0.0)
	birds._process(BirdAmbience.FADE_SECONDS)
	assert_eq(birds.sound_level, 1.0)
	assert_eq(birds.players[0].volume_db, BirdAmbience.BIRD_DB)
	GameEvents.lighting_changed.emit(1.0, true)
	birds._process(BirdAmbience.FADE_SECONDS)
	assert_eq(birds.sound_level, 0.0)
	assert_eq(birds.players[0].volume_db, BirdAmbience.SILENT_DB)


func test_a_shift_that_starts_at_night_starts_silent() -> void:
	var birds := _make([_cluster()], GraphicsQuality.Level.HIGH, 1.0)
	assert_eq(birds.sound_level, 0.0)
	assert_eq(birds.players[0].volume_db, BirdAmbience.SILENT_DB)


func test_low_has_sound_but_no_flock_meshes() -> void:
	var entries := [_cluster("one", 3), _cluster("two", 4), _cluster("sound only", 0)]
	var low := _make(entries, GraphicsQuality.Level.LOW)
	assert_eq(low.players.size(), 3)
	assert_eq(low.flock_visual_count(), 0)
	assert_eq(low.get_children().filter(func(child: Node) -> bool: return child is MultiMeshInstance3D).size(), 0)
	var high := _make(entries, GraphicsQuality.Level.HIGH)
	assert_eq(high.players.size(), 3)
	assert_eq(high.flock_visual_count(), 7, "Sound-only clusters create no birds")
	assert_eq(high.get_children().filter(func(child: Node) -> bool: return child is MultiMeshInstance3D).size(), 1, "All birds share one mesh pool")


func test_bird_cluster_data_is_validated_without_touching_the_map() -> void:
	assert_eq(MapLoader.check_bird_clusters([_cluster("quiet", 0, 25.0), _cluster("busy", 6, 35.0)]), [] as Array[String])
	assert_eq(MapLoader.check_bird_clusters(null), [] as Array[String], "Older maps need no birds")
	assert_true(MapLoader.check_bird_clusters("trees").has("bird_clusters must be a list"))
	var bad := _cluster("palms", 2, 40.0)
	var problems := MapLoader.check_bird_clusters([bad, bad.duplicate()])
	assert_true(problems.has("Bird clusters have palms twice"), str(problems))
	assert_true(problems.has("Bird cluster palms needs flock as 0 or 3 to 6"), str(problems))
	assert_true(problems.has("Bird cluster palms needs range from 25 to 35"), str(problems))
	bad = _cluster("broken")
	bad["x"] = "near the road"
	assert_true(MapLoader.check_bird_clusters([bad]).has("Bird cluster broken needs x as a number"))
