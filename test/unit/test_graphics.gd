extends GutTest

const GB := GraphicsQuality.GIGABYTE


func test_a_three_gigabyte_phone_gets_low() -> void:
	assert_eq(GraphicsQuality.level_for_memory(3 * GB), GraphicsQuality.Level.LOW)


func test_a_mid_range_phone_gets_medium() -> void:
	assert_eq(GraphicsQuality.level_for_memory(6 * GB), GraphicsQuality.Level.MEDIUM)


func test_a_flagship_gets_high() -> void:
	assert_eq(GraphicsQuality.level_for_memory(12 * GB), GraphicsQuality.Level.HIGH)


func test_unknown_memory_plays_safe() -> void:
	assert_eq(GraphicsQuality.level_for_memory(0), GraphicsQuality.Level.MEDIUM)


func test_player_choice_beats_auto() -> void:
	assert_eq(GraphicsQuality.resolve(GraphicsQuality.Level.HIGH, 2 * GB), GraphicsQuality.Level.HIGH)
	assert_eq(GraphicsQuality.resolve(GraphicsQuality.AUTO, 2 * GB), GraphicsQuality.Level.LOW)


func test_each_level_is_lighter_than_the_one_above() -> void:
	var low: Dictionary = GraphicsQuality.PROFILES[GraphicsQuality.Level.LOW]
	var medium: Dictionary = GraphicsQuality.PROFILES[GraphicsQuality.Level.MEDIUM]
	var high: Dictionary = GraphicsQuality.PROFILES[GraphicsQuality.Level.HIGH]
	assert_false(low["shadows"])
	assert_lt(float(low["render_scale"]), float(medium["render_scale"]))
	assert_lt(float(medium["render_scale"]), float(high["render_scale"]))
	assert_lt(int(low["traffic_cars"]), int(high["traffic_cars"]))
	assert_lt(float(low["view_distance"]), float(medium["view_distance"]))


func test_chunked_builder_splits_by_location_and_keeps_every_triangle() -> void:
	var whole := LowPolyBuilder.new()
	var split := LowPolyBuilder.new()
	split.chunk_size = 100.0
	for builder: LowPolyBuilder in [whole, split]:
		builder.box(Vector3(10.0, 0.0, 10.0), Vector3.ONE, Color.WHITE)
		builder.box(Vector3(350.0, 0.0, 10.0), Vector3.ONE, Color.WHITE)
	var material := StandardMaterial3D.new()
	var whole_meshes := whole.build_all(material)
	var split_meshes := split.build_all(material)
	assert_eq(whole_meshes.size(), 1)
	assert_eq(split_meshes.size(), 2)
	var whole_vertices: int = whole_meshes[0].surface_get_array_len(0)
	var split_vertices: int = split_meshes[0].surface_get_array_len(0) + split_meshes[1].surface_get_array_len(0)
	assert_eq(split_vertices, whole_vertices)


func test_game_style_reaches_every_button() -> void:
	var box: StyleBoxFlat = ThemeDB.get_default_theme().get_stylebox("normal", "Button")
	assert_eq(box.bg_color, UiStyle.RAISED)


func test_language_change_does_not_reset_graphics() -> void:
	var before := GameSettings.graphics_quality
	GameSettings.language = "es"
	assert_eq(GameSettings.graphics_quality, before)
	GameSettings.language = "en"
