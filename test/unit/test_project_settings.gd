extends GutTest
## A mistyped key in project.godot fails silently, so check the mobile setup.


func test_landscape_on_phones() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 4, "Sensor landscape")


func test_tilt_sensors_are_enabled() -> void:
	assert_true(ProjectSettings.get_setting("input_devices/sensors/enable_gravity"))
	assert_true(ProjectSettings.get_setting("input_devices/sensors/enable_accelerometer"))


func test_mobile_renderer_is_compatibility() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"), "gl_compatibility")


func test_physics_runs_at_60_with_interpolation() -> void:
	assert_eq(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"), 60)
	assert_true(ProjectSettings.get_setting("physics/common/physics_interpolation"))


func test_mouse_can_stand_in_for_touch_on_desktop() -> void:
	assert_true(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"))


func test_touch_also_drives_buttons_and_lists() -> void:
	assert_true(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"),
		"Buttons and lists listen to the mouse events Godot makes from a touch")


func test_a_shaky_tap_is_not_a_scroll() -> void:
	assert_gte(ProjectSettings.get_setting("gui/common/default_scroll_deadzone"), 10)


func test_texture_compression_for_android_is_on() -> void:
	assert_true(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc"))


func test_shadows_are_filtered_on_phones() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size.mobile"), 4096)
	assert_gt(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile"), 0)


func _presets() -> ConfigFile:
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	return presets


func _preset_section(presets: ConfigFile, platform: String) -> String:
	for section in presets.get_sections():
		if presets.get_value(section, "platform", "") == platform:
			return section
	return ""


func test_there_is_an_ios_preset_that_exports_like_android() -> void:
	var presets := _presets()
	var ios := _preset_section(presets, "iOS")
	var android := _preset_section(presets, "Android")
	assert_ne(ios, "", "An iOS export preset exists")
	assert_ne(android, "")
	for key: String in ["include_filter", "exclude_filter", "export_filter"]:
		assert_eq(presets.get_value(ios, key), presets.get_value(android, key), key + " matches Android, so both ship the same game")
	var options := ios + ".options"
	assert_eq(presets.get_value(options, "application/bundle_identifier"), presets.get_value(android + ".options", "package/unique_name"))
	assert_true(presets.get_value(options, "architectures/arm64"))
	assert_eq(presets.get_value(options, "application/app_store_team_id"), "", "No account details are committed")


## iOS has no Java and no Android singletons, so game code must not call them.
func test_game_code_has_no_android_only_calls() -> void:
	var banned := ["JavaClassWrapper", "JavaScriptBridge", "Engine.get_singleton(\"Godot", "OS.get_name() == \"Android\"", "request_permissions"]
	var found: Array[String] = []
	_scan("res://scripts", banned, found)
	assert_eq(found, [] as Array[String])


func _scan(folder: String, banned: Array, found: Array[String]) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			var text := FileAccess.get_file_as_string(folder + "/" + file)
			for word: String in banned:
				if text.contains(word):
					found.append("%s/%s: %s" % [folder, file, word])
	for sub in DirAccess.get_directories_at(folder):
		_scan(folder + "/" + sub, banned, found)


func test_safe_area_insets_clear_a_notch_and_the_home_indicator() -> void:
	# An iPhone in landscape: notch on the left, home indicator along the bottom.
	var insets := UiStyle.both_ways(UiStyle.safe_insets(Vector2(1280, 720), Vector2i(2532, 1170), Rect2i(141, 0, 2250, 1107)))
	assert_gt(insets.x, 60.0, "Clear of the notch")
	assert_eq(insets.x, insets.z, "Both sides, since the phone can turn round")
	assert_gt(insets.w, 30.0, "Clear of the home indicator")
