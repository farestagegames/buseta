extends Control
## The title screen: the store's feature graphic, full screen, and a pulsing
## "tap to start". Any tap, click, key or gamepad button opens the main menu,
## except on the very first launch, which goes straight into the tutorial shift.
## Narrower screens than the art show all of it, with the sky and the road
## carried on above and below; wider screens crop a little sky and road.

const MENU_SCENE := "res://scenes/main/main_menu.tscn"
const SHIFT_SCENE := "res://scenes/main/city_shift.tscn"
const ART := preload("res://assets/textures/title_art.png")
## Top of the sky and the asphalt in the art, for the bands on narrow screens.
const SKY := Color8(24, 150, 196)
const ROAD := Color8(58, 58, 66)
const ART_ASPECT := 1024.0 / 500.0

signal started

## Off in tests, so starting does not swap the running scene.
var change_scene: bool = true
## The scene starting opened, for tests.
var next_scene: String = ""
var art: TextureRect
var prompt: Label
var _leaving: bool = false
var _time: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sky := ColorRect.new()
	sky.color = SKY
	sky.anchor_right = 1.0
	sky.anchor_bottom = 0.5
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	var road := ColorRect.new()
	road.color = ROAD
	road.anchor_top = 0.5
	road.anchor_right = 1.0
	road.anchor_bottom = 1.0
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(road)
	art = TextureRect.new()
	art.texture = ART
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	prompt = Label.new()
	prompt.text = "Tap to start"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.anchor_left = 0.5
	prompt.anchor_right = 0.5
	prompt.anchor_top = 1.0
	prompt.anchor_bottom = 1.0
	prompt.offset_left = -240.0
	prompt.offset_right = 240.0
	prompt.offset_top = -104.0
	prompt.offset_bottom = -32.0
	# A dark pill, so the words read over the lane markings.
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.05, 0.05, 0.07, 0.6)
	pill.set_corner_radius_all(36)
	prompt.add_theme_stylebox_override("normal", pill)
	prompt.add_theme_font_size_override("font_size", 40)
	prompt.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.06))
	prompt.add_theme_constant_override("outline_size", 10)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt)
	resized.connect(_fit)
	_fit()


## Covers wide screens and fits narrow ones, so the title and the bus always show.
func _fit() -> void:
	art.stretch_mode = stretch_for(size)


static func stretch_for(screen: Vector2) -> TextureRect.StretchMode:
	if screen.x / maxf(screen.y, 1.0) >= ART_ASPECT:
		return TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _process(dt: float) -> void:
	_time += dt
	prompt.modulate.a = 0.55 + 0.45 * cos(_time * 3.0)


func _input(event: InputEvent) -> void:
	var start: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed)
	if start:
		get_viewport().set_input_as_handled()
		open_menu()


func open_menu() -> void:
	if _leaving:
		return
	_leaving = true
	started.emit()
	var scene := MENU_SCENE
	if goes_to_tutorial(Profile.data):
		Profile.data.first_launch_done = true
		Profile.route_override = ""
		Profile.save()
		scene = SHIFT_SCENE
	next_scene = scene
	if change_scene:
		get_tree().change_scene_to_file.call_deferred(scene)


## Only a brand-new player skips the menu, once: the tutorial shift then plays,
## since city_shift opens with it until intro_done. Every later launch, and any
## save with progress, goes to the menu.
static func goes_to_tutorial(profile: PlayerProfile) -> bool:
	return not profile.first_launch_done and not profile.intro_done and profile.xp == 0
