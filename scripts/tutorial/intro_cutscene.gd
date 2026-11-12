class_name IntroCutscene
extends CanvasLayer
## A short opening over the real town, with traffic running. Can be skipped.

signal finished

const BAR_HEIGHT := 86.0
const CAPTIONS: Array[String] = [
	"%s. A city that never stops moving.",
	"Seven stops. One timetable. One driver.",
	"Your first shift starts now.",
]

var shots := CameraShots.new()
var playing: bool = false

var _camera: Camera3D
var _caption: Label
var _main_camera: Camera3D


func setup(network: RoadNetwork, ground: GroundSurface, bus: BusController, main_camera: Camera3D) -> void:
	_main_camera = main_camera
	var overview_a := _road_point(network, ground, "market_street", 70.0)
	var overview_b := _road_point(network, ground, "market_street", 230.0)
	shots.add(overview_a + Vector3(-40.0, 46.0, 62.0), overview_b + Vector3(-30.0, 30.0, 46.0),
		overview_a + Vector3(40.0, 0.0, 0.0), overview_b, 4.6, CAPTIONS[0])
	var street_a := _road_point(network, ground, "high_street", 40.0)
	var street_b := _road_point(network, ground, "high_street", 118.0)
	var street_look := _road_point(network, ground, "high_street", 190.0)
	shots.add(street_a + Vector3(0.0, 2.6, 5.0), street_b + Vector3(0.0, 2.2, 5.0),
		street_b + Vector3.UP, street_look + Vector3.UP, 4.4, CAPTIONS[1])
	var heading := bus.rotation.y
	var forward := Vector3(-sin(heading), 0.0, -cos(heading))
	var right := Vector3(-forward.z, 0.0, forward.x)
	var nose := bus.global_position + forward * (bus.spec.wheelbase + bus.spec.front_overhang)
	shots.add(nose + forward * 30.0 + right * 14.0 + Vector3.UP * 7.0, nose + forward * 11.0 + right * 6.0 + Vector3.UP * 2.4,
		bus.global_position + Vector3.UP * 2.0, nose + Vector3.UP * 1.8, 4.2, CAPTIONS[2])
	_build_screen()


func play() -> void:
	playing = true
	visible = true
	_camera.make_current()
	_show_frame()


## Ends the scene at once and hands back to the game.
func skip() -> void:
	if not playing:
		return
	playing = false
	visible = false
	_main_camera.make_current()
	finished.emit()


func _process(dt: float) -> void:
	if not playing:
		return
	shots.update(dt)
	if shots.is_finished():
		skip()
	else:
		_show_frame()


func _show_frame() -> void:
	_camera.global_position = shots.position()
	_camera.look_at(shots.look_target(), Vector3.UP)
	_caption.text = tr(shots.caption()).replace("%s", Country.pack.data["city_name"])


## On a town without the named street (the intro was shot in Puerto Marisol), the
## longest road stands in, so the scene still sets up anywhere.
func _road_point(network: RoadNetwork, ground: GroundSurface, road: String, along: float) -> Vector3:
	if not network.roads.has(road):
		for other: Dictionary in network.roads.values():
			if not network.roads.has(road) or float(other["length"]) > float(network.roads[road]["length"]):
				road = other["id"]
	var spot: Vector2 = network.sample(road, along)["position"]
	return Vector3(spot.x, ground.terrain_height(spot), spot.y)


func _build_screen() -> void:
	layer = 10
	visible = false
	_camera = Camera3D.new()
	_camera.fov = 58.0
	_camera.far = 900.0
	_camera.top_level = true
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_camera)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.add_child(_bar(0.0))
	root.add_child(_bar(1.0))
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 34)
	_caption.anchor_top = 1.0
	_caption.anchor_right = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_left = 180.0
	_caption.offset_right = -180.0
	_caption.offset_top = -BAR_HEIGHT
	root.add_child(_caption)
	var button := Button.new()
	button.text = "Skip"
	button.custom_minimum_size = Vector2(130.0, 62.0)
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_left = -150.0
	button.offset_right = -20.0
	button.offset_top = 12.0
	button.offset_bottom = 74.0
	button.pressed.connect(skip)
	root.add_child(button)


func _bar(anchor_y: float) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.anchor_right = 1.0
	bar.anchor_top = anchor_y
	bar.anchor_bottom = anchor_y
	bar.offset_top = -BAR_HEIGHT if anchor_y > 0.5 else 0.0
	bar.offset_bottom = 0.0 if anchor_y > 0.5 else BAR_HEIGHT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar
