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


## Every vertex of a mesh, so a test can see where its geometry ended up.
func _points(mesh: ArrayMesh) -> PackedVector3Array:
	return PackedVector3Array() if mesh.get_surface_count() == 0 else mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func test_clip_trims_a_box_that_is_partly_outside() -> void:
	var b := LowPolyBuilder.new()
	b.clip = AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	b.box(Vector3(1.0, 0.0, 0.0), Vector3(2.0, 1.0, 1.0), Color.WHITE)
	var points := _points(b.build(StandardMaterial3D.new()))
	assert_gt(points.size(), 0)
	var grown := b.clip.grow(0.0001)
	for point in points:
		assert_true(grown.has_point(point), str(point))
	assert_almost_eq(Array(points).map(func(p: Vector3) -> float: return p.x).max(), 1.0, 0.0001, "Cut at the edge")


func test_clip_leaves_out_a_box_wholly_outside() -> void:
	var b := LowPolyBuilder.new()
	b.clip = AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	b.box(Vector3(5.0, 0.0, 0.0), Vector3.ONE, Color.WHITE)
	assert_eq(b.build(StandardMaterial3D.new()).get_surface_count(), 0)


func test_clip_trims_turned_and_flat_shapes_too() -> void:
	var b := LowPolyBuilder.new()
	b.clip = AABB(Vector3(-0.5, -1.0, -0.5), Vector3(1.0, 2.0, 1.0))
	b.turned_box(Vector3.ZERO, Vector3(2.0, 0.1, 2.0), PI / 4.0, Color.WHITE)
	b.quad(Vector3(-2, 0, -2), Vector3(-2, 0, 2), Vector3(2, 0, 2), Vector3(2, 0, -2), Color.WHITE)
	var points := _points(b.build(StandardMaterial3D.new()))
	assert_gt(points.size(), 0)
	var grown := b.clip.grow(0.0001)
	for point in points:
		assert_true(grown.has_point(point), str(point))
	assert_eq(points.size() % 3, 0, "Still whole triangles")


func test_a_polygon_keeps_its_area_inside_the_window() -> void:
	var square := PackedVector3Array([Vector3(0, 0, 0), Vector3(2, 0, 0), Vector3(2, 2, 0), Vector3(0, 2, 0)])
	var inside := LowPolyBuilder.clipped(square, AABB(Vector3(1, 1, -1), Vector3(5, 5, 2)))
	assert_eq(inside.size(), 4)
	for point in inside:
		assert_between(point.x, 1.0, 2.0)
		assert_between(point.y, 1.0, 2.0)
	assert_eq(LowPolyBuilder.clipped(square, AABB(Vector3(5, 5, -1), Vector3(1, 1, 2))).size(), 0)


func test_game_style_reaches_every_button() -> void:
	var box: StyleBoxFlat = ThemeDB.get_default_theme().get_stylebox("normal", "Button")
	assert_eq(box.bg_color, UiStyle.RAISED)


func test_language_change_does_not_reset_graphics() -> void:
	var before := GameSettings.graphics_quality
	GameSettings.language = "es"
	assert_eq(GameSettings.graphics_quality, before)
	GameSettings.language = "en"
