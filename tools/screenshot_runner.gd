extends Node
## Developer tool: runs the test scene with scripted input and saves screenshots
## to tools/screens/. Not included in exported builds.

const SCENE := "res://scenes/test/test_drive.tscn"


func _ready() -> void:
	await get_tree().process_frame
	var scene: Node = load(SCENE).instantiate()
	add_child(scene)
	var hud: DriveHud = scene.get_node("Hud")
	await _frames(20)
	await _shot("1_close_start")

	GameEvents.ui_pedals_changed.emit(1.0, 0.0)
	await _seconds(5.0)
	GameEvents.ui_wheel_changed.emit(0.55)
	hud.wheel.tracker.rotation_degrees = 110.0
	await _seconds(1.5)
	await _shot("2_close_turning")
	GameEvents.camera_cycle_requested.emit()
	await _frames(30)
	await _shot("3_far")
	GameEvents.camera_cycle_requested.emit()
	await _frames(10)
	await _shot("4_cockpit")

	GameEvents.ui_wheel_changed.emit(0.0)
	hud.wheel.tracker.rotation_degrees = 0.0
	GameEvents.ui_pedals_changed.emit(0.0, 1.0)
	await _seconds(5.0)
	GameEvents.door_toggle_requested.emit()
	GameEvents.indicator_toggle_requested.emit(BusIndicators.TurnSide.LEFT)
	GameEvents.camera_cycle_requested.emit()
	await _seconds(1.6)
	await _shot("5_doors_open")
	GameSettings.steering_mode = SteeringMapper.Mode.BUTTONS
	await _frames(5)
	await _shot("6_buttons_mode")
	hud._open_settings()
	await _frames(5)
	await _shot("7_settings")
	var phone_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	print("viewport ", phone_rect.size)
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://tools/screens/%s.png" % shot_name)
	image.save_png(path)
	print("saved ", shot_name)
