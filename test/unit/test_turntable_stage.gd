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
	assert_eq(stage.stage.render_target_update_mode, TurntableStage.SHOWN_UPDATE)
	assert_true(stage.is_processing())

	stage.paused = true
	assert_true(stage.paused)
	assert_eq(stage.stage.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	assert_false(stage.is_processing())

	stage.paused = false
	assert_false(stage.paused)
	assert_eq(stage.stage.render_target_update_mode, TurntableStage.SHOWN_UPDATE)
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


func test_cab_view_stops_the_spin_and_hides_the_driver() -> void:
	var stage := TurntableStage.new()
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(1280, 720)
	add_child_autofree(stage)
	stage.show_spec(stage.shown_spec(), {"id": "x", "kind": "dash_toy"})
	stage.set_view(TurntableStage.CAB_VIEW)
	assert_true(stage.in_cab())
	assert_false(stage.visual().driver_shown(), "the driver would fill the close-up")
	await wait_seconds(0.6)
	assert_almost_eq(wrapf(stage.pivot.rotation.y, -PI, PI), 0.0, 0.01, "the turntable comes to rest")
	var rest := stage.pivot.rotation.y
	await wait_seconds(0.2)
	assert_eq(stage.pivot.rotation.y, rest, "no idle spin in the cab")
	var cam := stage.stage.get_camera_3d()
	assert_almost_eq(cam.position.distance_to(stage.cab_camera_transform().origin), 0.0, 0.01)
	assert_eq(cam.fov, TurntableStage.CAB_FOV)


func test_cab_camera_sits_inside_the_bus_over_the_dash() -> void:
	var stage := TurntableStage.new()
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(1280, 720)
	add_child_autofree(stage)
	stage.show_spec(stage.shown_spec(), {"id": "x", "kind": "pennant"})
	var spec := stage.shown_spec()
	var eye := stage.cab_camera_transform().origin
	assert_lt(absf(eye.x), spec.body_width / 2.0, "inside the sides")
	assert_lt(eye.y, spec.body_height, "under the roof")
	var visual := stage.visual()
	var anchor_z := visual.position.z + visual.cockpit_anchor.position.z
	assert_almost_eq(eye.z, anchor_z + 0.35, 0.01, "just behind the driver's seat")
	assert_gt(stage.cab_camera_transform().basis.z.z, 0.0, "the camera's back faces the rear, so it looks to the front")
	stage.show_spec(spec, {"id": "y", "kind": "seat_cover"})
	assert_lt(stage.cab_camera_transform().basis.z.z, 0.0, "seat covers are seen looking back down the aisle")


func test_cab_view_survives_a_new_bus_and_leaves_with_a_preset() -> void:
	var stage := TurntableStage.new()
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(1280, 720)
	add_child_autofree(stage)
	stage.set_view(TurntableStage.CAB_VIEW)
	stage.show_spec(stage.shown_spec(), {"id": "x", "kind": "dash_toy"})
	assert_true(stage.in_cab())
	assert_false(stage.visual().driver_shown(), "a rebuilt bus keeps its driver hidden in the cab")
	assert_eq(stage.cycle_view(), "home", "the camera button leaves the cab")
	assert_true(stage.visual().driver_shown())
	var press := InputEventMouseButton.new()
	stage.set_view(TurntableStage.CAB_VIEW)
	await wait_seconds(0.6)
	var rest := stage.pivot.rotation.y
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	stage._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(50.0, 0.0)
	stage._gui_input(motion)
	assert_eq(stage.pivot.rotation.y, rest, "no dragging in the cab")


func _made_stage() -> TurntableStage:
	var stage := TurntableStage.new()
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(1280, 720)
	add_child_autofree(stage)
	return stage


func test_roundabout_scenery_stays_within_the_mesh_budget() -> void:
	var stage := _made_stage()
	assert_lt(stage.scenery_mesh_count(), 60)
	assert_gt(stage.scenery_mesh_count(), 8)
	assert_eq(stage.world_environment().background_mode, Environment.BG_SKY)


func test_night_lights_the_lamps_and_windows_and_dims_the_sun() -> void:
	var stage := _made_stage()
	var times := Profile.times_of_day()
	var night := TimeOfDay.find(times, "noche")
	var morning := TimeOfDay.find(times, "manana")
	assert_not_null(night)
	assert_not_null(morning)
	stage.set_time_of_day(morning)
	assert_false(stage.lights_on())
	assert_false(stage.night_light().visible)
	var morning_sun := stage.sun_light().light_energy
	stage.set_time_of_day(night)
	assert_eq(stage.shown_time, night)
	assert_true(stage.lights_on())
	assert_true(stage.night_light().visible)
	assert_lt(stage.sun_light().light_energy, morning_sun, "night is dimmer than morning")
	assert_false(stage.sun_light().shadow_enabled)
