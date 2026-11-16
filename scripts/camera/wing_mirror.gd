class_name WingMirror
extends Control
## The driver's wing mirror in cockpit view: a small, low-resolution rear view in
## a frame at the driver's edge of the screen, flipped left to right as a mirror
## is. It renders only in cockpit view, and then only every other frame, so it
## costs a phone little.

const RENDER_SIZE := Vector2i(192, 112)
const SCREEN_SIZE := Vector2(208.0, 120.0)
const FRAME := 5.0
const EDGE := 24.0
## Below the top buttons and the route goals checklist under them (DriveHud).
const TOP := 188.0
const FOV := 30.0
const NEAR := 0.05
const FAR := 160.0
const FRAMES_PER_RENDER := 2

## Where the mirror sees from, usually BusVisual.wing_mirror_anchor.
var source: Node3D
## The driver sits on the left, so the mirror shows on the left of the screen.
var on_left: bool = true
var viewport: SubViewport
var camera: Camera3D
var picture: TextureRect
var _frame: int = 0
var _active: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	viewport = SubViewport.new()
	viewport.size = RENDER_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	viewport.positional_shadow_atlas_size = 0
	viewport.mesh_lod_threshold = 8.0
	viewport.audio_listener_enable_3d = false
	add_child(viewport)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = NEAR
	camera.far = FAR
	camera.current = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	viewport.add_child(camera)

	var frame := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1)
	style.set_corner_radius_all(10)
	frame.add_theme_stylebox_override("panel", style)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	picture = TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.flip_h = true
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = FRAME
	picture.offset_top = FRAME
	picture.offset_right = -FRAME
	picture.offset_bottom = -FRAME
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)


func _ready() -> void:
	GameEvents.camera_view_changed.connect(_on_view_changed)
	get_viewport().size_changed.connect(_layout)
	_layout()


func is_active() -> bool:
	return _active


func _on_view_changed(view_name: String) -> void:
	set_active(view_name == "Cockpit")


func set_active(on: bool) -> void:
	_active = on and source != null
	visible = _active
	_frame = 0
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if _active else SubViewport.UPDATE_DISABLED


func _process(_dt: float) -> void:
	if not _active or not is_instance_valid(source):
		return
	camera.global_transform = source.get_global_transform_interpolated()
	_frame += 1
	if _frame % FRAMES_PER_RENDER == 0:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## At the driver's edge, below the top row of buttons and clear of notches.
func _layout() -> void:
	var insets := UiStyle.screen_insets(get_viewport_rect().size)
	var x := (EDGE + insets.x) if on_left else (get_viewport_rect().size.x - EDGE - insets.z - SCREEN_SIZE.x)
	position = Vector2(x, TOP)
	size = SCREEN_SIZE
