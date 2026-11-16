extends GutTest
## Unit tests for TurntableStage: stage construction, bus swapping, camera presets,
## pause control, and drag interaction.


func test_builds_without_errors_and_shows_chosen_spec() -> void:
	var stage := TurntableStage.new()
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(1280, 720)
	add_child_autofree(stage)

	assert_not_null(stage.shown_spec(), "TurntableStage should show the chosen bus spec")
	assert_not_null(stage.pivot, "TurntableStage should have a 3D pivot")
	assert_not_null(stage.stage, "TurntableStage should have a SubViewport stage")
	assert_eq(stage.mouse_filter, Control.MOUSE_FILTER_PASS, "mouse_filter must be PASS for dragging")
	assert_false(stage.stage.transparent_bg, "Background must be opaque")
	assert_eq(stage.stage.msaa_3d, Viewport.MSAA_2X, "MSAA should be 2X")


func test_show_spec_swaps_bus() -> void:
	var stage := TurntableStage.new()
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(1280, 720)
	add_child_autofree(stage)
	var first_spec := stage.shown_spec()

	var new_spec := BusSpec.new()
	new_spec.display_name = "Test Chiva"
	new_spec.body_style = "chiva"
	new_spec.front_overhang = 1.2
	new_spec.wheelbase = 4.2
	new_spec.rear_overhang = 1.6
	var decoration := {"id": "charm_palma"}

	stage.show_spec(new_spec, decoration)
	assert_eq(stage.shown_spec(), new_spec, "shown_spec should return the swapped spec")
	assert_eq(stage.shown_decoration(), decoration, "shown_decoration should return the new decoration")
	assert_ne(stage.shown_spec(), first_spec, "Spec should differ from the initial chosen spec")


func test_set_view_moves_camera_after_tween() -> void:
	var stage := TurntableStage.new()
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(1280, 720)
	add_child_autofree(stage)

	var cam := stage.stage.get_camera_3d()
	assert_not_null(cam, "Camera should exist in the stage")
	var initial_pos := cam.position

	stage.set_view("top")
	await wait_seconds(0.6)

	assert_ne(cam.position, initial_pos, "Camera position should move after set_view tween")
	assert_almost_eq(cam.position.y, TurntableStage.PRESETS["top"]["position"].y, 0.1, "Camera Y should match top preset")
	assert_almost_eq(cam.rotation.x, TurntableStage.PRESETS["top"]["rotation"].x, 0.1, "Camera tilt should match top preset")


func test_paused_disables_viewport_update_and_restores_it() -> void:
	var stage := TurntableStage.new()
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(1280, 720)
	add_child_autofree(stage)

	assert_false(stage.paused)
	assert_eq(stage.stage.render_target_update_mode, SubViewport.UPDATE_WHEN_VISIBLE)
	assert_true(stage.is_processing())

	stage.paused = true
	assert_true(stage.paused)
	assert_eq(stage.stage.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	assert_false(stage.is_processing())

	stage.paused = false
	assert_false(stage.paused)
	assert_eq(stage.stage.render_target_update_mode, SubViewport.UPDATE_WHEN_VISIBLE)
	assert_true(stage.is_processing())


func test_drag_turns_pivot_by_about_half_radian_more_than_idle() -> void:
	var stage := TurntableStage.new()
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(1280, 720)
	add_child_autofree(stage)

	watch_signals(stage)

	var initial_rot := stage.pivot.rotation.y

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	stage._gui_input(press)

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(50.0, 0.0)
	stage._gui_input(motion)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	stage._gui_input(release)

	var delta := stage.pivot.rotation.y - initial_rot
	assert_almost_eq(delta, 0.5, 0.05, "Drag with relative.x=50 should turn pivot by about 0.5 rad (50 * 0.01)")
	assert_signal_emitted(stage, "dragged")


func test_cycle_view_cycles_presets() -> void:
	var stage := TurntableStage.new()
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(1280, 720)
	add_child_autofree(stage)

	assert_eq(stage.current_view(), "home")
	assert_eq(stage.cycle_view(), "top")
	assert_eq(stage.current_view(), "top")
	assert_eq(stage.cycle_view(), "side")
	assert_eq(stage.current_view(), "side")
	assert_eq(stage.cycle_view(), "home")
	assert_eq(stage.current_view(), "home")


func test_bump_runs_without_error() -> void:
	var stage := TurntableStage.new()
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(1280, 720)
	add_child_autofree(stage)

	stage.bump()
	await wait_seconds(0.25)
	assert_not_null(stage.visual())
	assert_almost_eq(stage.visual().position.y, 0.0, 0.05, "Bus visual should return to ground after bump")
