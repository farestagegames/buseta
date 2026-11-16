extends GutTest
## The animated main-menu scenery.

var backdrop: MenuBackdrop


func before_each() -> void:
	backdrop = MenuBackdrop.new()
	# Full-rect anchors would override a set size; a test sizes it by hand.
	backdrop.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child_autofree(backdrop)
	backdrop.size = Vector2(1280, 720)


func test_hills_are_built_inside_the_rect() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for hill in [backdrop.hill_back, backdrop.hill_front]:
		assert_false(hill.is_empty())
		for p: Vector2 in hill:
			assert_true(rect.grow(0.01).has_point(p), "hill point %s outside" % p)


func test_bus_stays_within_its_travel_range() -> void:
	var t := 0.0
	while t < 60.0:
		backdrop.advance(0.5)
		t += 0.5
		assert_true(backdrop.bus_x >= -400.0 and backdrop.bus_x <= 1281.0, "bus_x %f" % backdrop.bus_x)


func test_bus_wraps_around() -> void:
	backdrop.advance(30.0)
	var x := backdrop.bus_x
	backdrop.advance(30.0)
	assert_true(x != backdrop.bus_x or x > 1280.0)
	assert_true(backdrop.bus_x <= 1281.0)


func test_time_scale_zero_freezes_the_bus() -> void:
	backdrop.advance(5.0)
	var x := backdrop.bus_x
	backdrop.time_scale = 0.0
	backdrop.advance(10.0)
	assert_eq(backdrop.bus_x, x)


func test_ignores_mouse() -> void:
	assert_eq(backdrop.mouse_filter, Control.MOUSE_FILTER_IGNORE)
