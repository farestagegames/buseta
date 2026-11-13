extends GutTest
## The tutorial highlight ring must wrap the focused control on phone screens.

const STEPS := [
	{"focus": "go"},
	{"focus": "steer"},
	{"focus": "brake"},
	{"focus": "view"},
	{"focus": "indicator"},
	{"focus": "map"},
	{"focus": "doors"},
	{"focus": "doors"},
]

var _saved_size: Vector2i
var _saved_insets: Variant


func before_all() -> void:
	_saved_size = get_viewport().size
	_saved_insets = UiStyle.test_insets_override


func before_each() -> void:
	# The indicator step only runs with the indicator buttons on screen.
	GameSettings.show_indicator_buttons = true


func after_each() -> void:
	GameSettings.show_indicator_buttons = false
	UiStyle.test_insets_override = _saved_insets
	get_viewport().size = _saved_size
	await wait_frames(2)


func _ring_global(panel: TutorialPanel) -> Rect2:
	# ring() is panel-local; convert back to global for comparison with control rects.
	var local := panel.ring()
	return Rect2(local.position + panel.get_global_rect().position, local.size)


func _assert_rings_fit(size: Vector2i, insets: Vector4) -> void:
	UiStyle.test_insets_override = insets
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var host := SubViewportContainer.new()
	host.size = Vector2(size)
	host.add_child(vp)
	add_child_autofree(host)
	await get_tree().process_frame
	var hud := DriveHud.new()
	vp.add_child(hud)
	await wait_physics_frames(6)
	hud.tutorial_panel.visible = true
	for step: Dictionary in STEPS:
		var control := hud.control_rect(step["focus"])
		assert_true(control.has_area(), "Control rect missing for %s" % step["focus"])
		hud.tutorial_panel.show_step("test", control)
		await wait_physics_frames(1)
		var ring := _ring_global(hud.tutorial_panel)
		var diff := maxf(maxf(absf(ring.position.x - control.position.x), absf(ring.position.y - control.position.y)),
			maxf(absf(ring.end.x - control.end.x), absf(ring.end.y - control.end.y)))
		assert_lte(diff, 4.0, "%s offset at %s ring=%s control=%s" % [step["focus"], size, ring, control])


func test_ring_wraps_focused_controls_on_phone_screens() -> void:
	await _assert_rings_fit(Vector2i(2400, 1080), Vector4(80.0, 0.0, 0.0, 40.0))
	await _assert_rings_fit(Vector2i(1600, 720), Vector4(60.0, 0.0, 0.0, 24.0))


func test_hidden_indicator_buttons_have_no_ring_and_the_step_is_skipped() -> void:
	GameSettings.show_indicator_buttons = false
	var hud := DriveHud.new()
	add_child_autofree(hud)
	await wait_frames(2)
	assert_false(hud.control_rect("indicator").has_area(), "No ring round hidden buttons")
	var steps := TutorialScript.new()
	steps.skipped.append("indicate")
	while steps.step()["id"] != "indicate":
		steps.index += 1
	steps.update({"stop_index": 0}, 0.0)
	assert_ne(steps.step()["id"], "indicate", "The step moves on by itself")
