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


func test_texture_compression_for_android_is_on() -> void:
	assert_true(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc"))


func test_shadows_are_filtered_on_phones() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size.mobile"), 4096)
	assert_gt(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile"), 0)
