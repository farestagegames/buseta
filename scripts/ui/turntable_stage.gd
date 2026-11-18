class_name TurntableStage
extends PreviewStage
## A full-screen 3D stage behind the main menu with the player's bus on a turntable.
##
## The bus stands on a low round platform with a yellow edge, surrounded by a flat
## light-grey street and pastel background buildings. The turntable can be dragged
## to spin the bus, and camera view presets allow framing from different angles.

signal dragged

const IDLE_SPIN: float = 0.35
const DRAG_RADIANS_PER_PIXEL: float = 0.01
const EASE_OUT_DURATION: float = 0.8
const VIEW_TWEEN_DURATION: float = 0.5
const BUMP_DURATION: float = 0.22
## While it shows, the stage draws every frame rather than "when visible": on a
## phone after a shift Home came up black, the stage never drawn (17 Nov).
const SHOWN_UPDATE := SubViewport.UPDATE_ALWAYS

const DUSK_BLUE := Color(0.38, 0.46, 0.60)
const YELLOW_RING := Color(1.0, 0.78, 0.2)
const DISC_GREY := Color(0.18, 0.19, 0.22)
const ROAD_GREY := Color(0.55, 0.57, 0.60)
const PAVEMENT_GREY := Color(0.72, 0.74, 0.77)

const PRESETS: Dictionary = {
	"home": {
		# Straight down the arm at the island, so the bus stands in the middle of the
		# screen (tester Claudio, 17 Nov), far enough back that a long bus spinning
		# passes under the bus card and the Home cards at the top corners.
		"position": Vector3(0.0, 8.6, 24.0),
		"rotation": Vector3(deg_to_rad(-10.0), 0.0, 0.0),
		"fov": 42.0,
		# No camera offset: the height alone puts the bus a little below the
		# middle, under the corner cards.
		"offset": Vector2.ZERO,
	},
	"top": {
		"position": Vector3(-0.8, 11.0, 14.0),
		"rotation": Vector3(deg_to_rad(-38.0), 0.0, 0.0),
		"fov": 42.0,
	},
	"side": {
		"position": Vector3(-0.8, 2.2, 9.5),
		"rotation": Vector3(deg_to_rad(-4.0), 0.0, 0.0),
		"fov": 42.0,
	},
}

const VIEW_ORDER: Array[String] = ["home", "top", "side"]

## A close-up from inside the cab, where the cab decorations hang. Not in the
## camera button's cycle: the Garage turns it on when a decoration is tried on.
const CAB_VIEW := "cab"
const CAB_FOV := 46.0
## Seat covers are seen looking back down the aisle, the rest looking at the dash.
const CAB_SEATS_FOV := 60.0

const BUILDINGS: Array[Dictionary] = [
	{"pos": Vector3(-28.0, 0.0, -17.0), "size": Vector3(7.0, 14.0, 6.0), "colour": Color(0.88, 0.74, 0.70)},
	{"pos": Vector3(-20.0, 0.0, -16.0), "size": Vector3(6.0, 10.0, 5.5), "colour": Color(0.72, 0.82, 0.80)},
	{"pos": Vector3(-13.0, 0.0, -18.0), "size": Vector3(6.5, 16.0, 6.0), "colour": Color(0.85, 0.82, 0.74)},
	{"pos": Vector3(-6.0, 0.0, -16.5),  "size": Vector3(5.5, 12.0, 5.0), "colour": Color(0.74, 0.78, 0.86)},
	{"pos": Vector3(1.0, 0.0, -17.5),   "size": Vector3(6.0, 15.0, 5.5), "colour": Color(0.86, 0.78, 0.82)},
	{"pos": Vector3(8.0, 0.0, -16.0),   "size": Vector3(5.5, 11.0, 5.0), "colour": Color(0.90, 0.84, 0.72)},
	{"pos": Vector3(15.0, 0.0, -18.0),  "size": Vector3(6.5, 17.0, 6.0), "colour": Color(0.76, 0.84, 0.78)},
	{"pos": Vector3(23.0, 0.0, -16.5),  "size": Vector3(7.0, 13.0, 5.5), "colour": Color(0.84, 0.76, 0.70)},
]

## Whether the turntable rendering and spinning are paused.
var paused: bool = false:
	set(value):
		if paused == value:
			return
		paused = value
		if stage != null:
			stage.render_target_update_mode = SubViewport.UPDATE_DISABLED if paused else SHOWN_UPDATE
		set_process(not paused)
		if paused:
			if _ease_tween != null and _ease_tween.is_valid():
				_ease_tween.pause()
			if _camera_tween != null and _camera_tween.is_valid():
				_camera_tween.pause()
		else:
			if _ease_tween != null and _ease_tween.is_valid():
				_ease_tween.play()
			if _camera_tween != null and _camera_tween.is_valid():
				_camera_tween.play()

var _visual: BusVisual
var _camera: Camera3D
var _current_view: String = "home"

var _camera_tween: Tween
var _ease_tween: Tween
var _bump_tween: Tween

var _is_dragging: bool = false
var _is_easing: bool = false
var _drag_velocity: float = 0.0
var _last_drag_time: int = 0


func _ready() -> void:
	var home_preset: Dictionary = PRESETS["home"]
	build_stage(home_preset["position"], rad_to_deg(home_preset["rotation"].x), home_preset["fov"])
	mouse_filter = Control.MOUSE_FILTER_PASS
	stage.transparent_bg = false

	var cam := _get_camera()
	if cam != null:
		cam.rotation = home_preset["rotation"]
		var offset: Vector2 = home_preset.get("offset", Vector2.ZERO)
		cam.h_offset = offset.x
		cam.v_offset = offset.y

	_build_scenery()
	show_spec(CityShift.chosen_spec(), CityShift.chosen_decoration())

	stage.render_target_update_mode = SubViewport.UPDATE_DISABLED if paused else SHOWN_UPDATE
	set_process(not paused)


func _exit_tree() -> void:
	if _ease_tween != null and _ease_tween.is_valid():
		_ease_tween.kill()
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	if _bump_tween != null and _bump_tween.is_valid():
		_bump_tween.kill()


## Shows the given bus specification and cab decoration on the turntable.
func show_spec(spec: BusSpec, decoration: Dictionary = {}) -> void:
	if _visual != null:
		_visual.free()
	_visual = BusVisual.new()
	_visual.spec = spec
	_visual.driver_look = CityShift.chosen_look()
	_visual.decoration = decoration
	_visual.position.z = spec.front_overhang + spec.wheelbase - spec.full_length() / 2.0
	pivot.add_child(_visual)
	if _current_view == CAB_VIEW:
		_visual.show_driver(false)
		_aim_cab_camera(false)
	else:
		bump()


## The bus specification currently shown on the turntable.
func shown_spec() -> BusSpec:
	return _visual.spec if _visual != null else null


## The cab decoration currently fitted to the shown bus.
func shown_decoration() -> Dictionary:
	return _visual.decoration if _visual != null else {}


## The visual 3D bus instance on the turntable, or null if none.
func visual() -> BusVisual:
	return _visual


## The name of the active camera view preset.
func current_view() -> String:
	return _current_view


## Moves the camera to one of the presets ("home", "top", "side") over 0.5 s with cubic easing.
func set_view(preset_name: String) -> void:
	if preset_name == CAB_VIEW:
		_enter_cab()
		return
	if not PRESETS.has(preset_name):
		return
	if _current_view == CAB_VIEW and _visual != null:
		_visual.show_driver(true)
	_current_view = preset_name
	var cam := _get_camera()
	if cam == null:
		return
	var preset: Dictionary = PRESETS[preset_name]
	if not is_inside_tree():
		cam.position = preset["position"]
		cam.rotation = preset["rotation"]
		cam.fov = preset["fov"]
		cam.h_offset = (preset.get("offset", Vector2.ZERO) as Vector2).x
		cam.v_offset = (preset.get("offset", Vector2.ZERO) as Vector2).y
		return
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(cam, "position", preset["position"], VIEW_TWEEN_DURATION)
	_camera_tween.tween_property(cam, "rotation", preset["rotation"], VIEW_TWEEN_DURATION)
	_camera_tween.tween_property(cam, "fov", preset["fov"], VIEW_TWEEN_DURATION)
	var offset: Vector2 = preset.get("offset", Vector2.ZERO)
	_camera_tween.tween_property(cam, "h_offset", offset.x, VIEW_TWEEN_DURATION)
	_camera_tween.tween_property(cam, "v_offset", offset.y, VIEW_TWEEN_DURATION)


## Whether the camera is in the cab looking at the decorations.
func in_cab() -> bool:
	return _current_view == CAB_VIEW


## Stops the turntable facing away from the camera and moves the camera into the
## cab, over the driver's seat, where the dash toy, mirror charm and pennant show.
func _enter_cab() -> void:
	_current_view = CAB_VIEW
	_is_dragging = false
	if _ease_tween != null and _ease_tween.is_valid():
		_ease_tween.kill()
	_is_easing = false
	if _visual != null:
		_visual.show_driver(false)
	_aim_cab_camera(true)


## Where the cab camera stands, in the stage's space with the turntable at rest.
func cab_camera_transform() -> Transform3D:
	if _visual == null or _visual.cockpit_anchor == null:
		return Transform3D(Basis.from_euler(PRESETS["home"]["rotation"]), PRESETS["home"]["position"])
	var anchor := _visual.cockpit_anchor.position
	var target := _visual.decoration_focus()
	var eye: Vector3
	if str(_visual.decoration.get("kind", "")) == "seat_cover":
		# From the windscreen, down the aisle to the seats.
		eye = Vector3(-anchor.x * 0.2, 2.2, anchor.z - 0.9)
	else:
		# From behind the driver's seat, over by the aisle, clear of the wheel.
		eye = anchor + Vector3(-anchor.x * 0.85, 0.05, 0.35)
	var offset := _visual.position
	offset.y = 0.0
	return Transform3D.IDENTITY.translated(offset) * Transform3D.IDENTITY.translated(eye).looking_at(target, Vector3.UP)


func _aim_cab_camera(animate: bool) -> void:
	var cam := _get_camera()
	if cam == null or pivot == null:
		return
	var to := cab_camera_transform()
	var fov := CAB_SEATS_FOV if _visual != null and str(_visual.decoration.get("kind", "")) == "seat_cover" else CAB_FOV
	var rest := pivot.rotation.y + wrapf(-pivot.rotation.y, -PI, PI)
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	if not animate or not is_inside_tree():
		pivot.rotation.y = 0.0
		cam.transform = to
		cam.fov = fov
		return
	_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(pivot, "rotation:y", rest, VIEW_TWEEN_DURATION)
	_camera_tween.tween_property(cam, "position", to.origin, VIEW_TWEEN_DURATION)
	_camera_tween.tween_property(cam, "rotation", to.basis.get_euler(), VIEW_TWEEN_DURATION)
	_camera_tween.tween_property(cam, "fov", fov, VIEW_TWEEN_DURATION)


## Cycles to the next camera view preset and returns its name.
func cycle_view() -> String:
	var idx := VIEW_ORDER.find(_current_view)
	var next_idx := (idx + 1) % VIEW_ORDER.size()
	var next_name := VIEW_ORDER[next_idx]
	set_view(next_name)
	return next_name


## Performs a quick hop and squash on the bus visual when switching buses.
func bump() -> void:
	if _visual == null or not is_inside_tree():
		return
	if _bump_tween != null and _bump_tween.is_valid():
		_bump_tween.kill()
	_visual.position.y = 0.0
	_visual.scale = Vector3.ONE
	_bump_tween = create_tween()
	var half := BUMP_DURATION * 0.5
	_bump_tween.tween_property(_visual, "position:y", 0.18, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bump_tween.parallel().tween_property(_visual, "scale", Vector3(0.96, 1.06, 0.96), half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_bump_tween.chain().tween_property(_visual, "position:y", 0.0, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_bump_tween.parallel().tween_property(_visual, "scale", Vector3.ONE, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _process(dt: float) -> void:
	if paused or pivot == null:
		return
	if not _is_dragging and not _is_easing and _current_view != CAB_VIEW:
		pivot.rotate_y(IDLE_SPIN * dt)


func _gui_input(event: InputEvent) -> void:
	# Inside the cab the turntable stays still: turning it would swing the bus
	# out from under the camera.
	if paused or _current_view == CAB_VIEW:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_start_drag()
			else:
				_end_drag()
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _is_dragging:
			_handle_drag(mm.relative.x, mm.velocity.x)
			accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_start_drag()
		else:
			_end_drag()
		accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if not _is_dragging:
			_start_drag()
		_handle_drag(sd.relative.x, sd.velocity.x)
		accept_event()


func _start_drag() -> void:
	_is_dragging = true
	_drag_velocity = 0.0
	_last_drag_time = Time.get_ticks_msec()
	if _ease_tween != null and _ease_tween.is_valid():
		_ease_tween.kill()
	_is_easing = false


func _handle_drag(relative_x: float, velocity_x: float) -> void:
	var delta_rad := relative_x * DRAG_RADIANS_PER_PIXEL
	pivot.rotate_y(delta_rad)
	if velocity_x != 0.0:
		_drag_velocity = velocity_x * DRAG_RADIANS_PER_PIXEL
	else:
		var now := Time.get_ticks_msec()
		var dt := (now - _last_drag_time) / 1000.0
		if dt > 0.001:
			_drag_velocity = delta_rad / dt
	_last_drag_time = Time.get_ticks_msec()
	dragged.emit()


func _end_drag() -> void:
	if not _is_dragging:
		return
	_is_dragging = false
	_start_release_ease()


func _start_release_ease() -> void:
	if not is_inside_tree() or pivot == null:
		_is_easing = false
		return
	if _ease_tween != null and _ease_tween.is_valid():
		_ease_tween.kill()
	_is_easing = true
	var ease_time := EASE_OUT_DURATION
	var delta_rot := ((_drag_velocity + IDLE_SPIN) * 0.5) * ease_time
	_ease_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ease_tween.tween_property(pivot, "rotation:y", pivot.rotation.y + delta_rot, ease_time)
	_ease_tween.finished.connect(func() -> void:
		_is_easing = false
	)


func _get_camera() -> Camera3D:
	if _camera != null:
		return _camera
	if stage != null:
		_camera = stage.get_camera_3d()
	return _camera


func _build_scenery() -> void:
	# Configure soft dusk blue sky
	for child in stage.get_children():
		if child is WorldEnvironment and child.environment != null:
			child.environment.background_mode = Environment.BG_COLOR
			child.environment.background_color = DUSK_BLUE

	# Turntable platform: yellow ring (~7 m radius, ~0.35 m wide edge)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = YELLOW_RING
	ring_mat.roughness = 0.9

	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 7.0
	ring_mesh.bottom_radius = 7.0
	ring_mesh.height = 0.08
	ring_mesh.radial_segments = 48

	var ring_inst := MeshInstance3D.new()
	ring_inst.mesh = ring_mesh
	ring_inst.material_override = ring_mat
	ring_inst.position = Vector3(0.0, -0.04, 0.0)
	ring_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(ring_inst)

	# Inner dark grey disc (~6.65 m radius, sits 2 mm higher than the yellow outer ring)
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = DISC_GREY
	disc_mat.roughness = 0.9

	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 6.65
	disc_mesh.bottom_radius = 6.65
	disc_mesh.height = 0.082
	disc_mesh.radial_segments = 48

	var disc_inst := MeshInstance3D.new()
	disc_inst.mesh = disc_mesh
	disc_inst.material_override = disc_mat
	disc_inst.position = Vector3(0.0, -0.039, 0.0)
	disc_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(disc_inst)

	# Road plane (static street)
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = ROAD_GREY
	road_mat.roughness = 0.9

	var road_mesh := PlaneMesh.new()
	road_mesh.size = Vector2(80.0, 40.0)

	var road_inst := MeshInstance3D.new()
	road_inst.mesh = road_mesh
	road_inst.material_override = road_mat
	road_inst.position = Vector3(0.0, -0.08, 0.0)
	road_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(road_inst)

	# Pavement strip
	var pave_mat := StandardMaterial3D.new()
	pave_mat.albedo_color = PAVEMENT_GREY
	pave_mat.roughness = 0.9

	var pave_mesh := BoxMesh.new()
	pave_mesh.size = Vector3(80.0, 0.12, 4.0)

	var pave_inst := MeshInstance3D.new()
	pave_inst.mesh = pave_mesh
	pave_inst.material_override = pave_mat
	pave_inst.position = Vector3(0.0, -0.02, -11.0)
	pave_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(pave_inst)

	# Dashed centre lines
	var dash_mat := StandardMaterial3D.new()
	dash_mat.albedo_color = Color(0.95, 0.95, 0.95)
	dash_mat.roughness = 0.9

	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(3.0, 0.02, 0.25)

	for x: float in [-28.0, -20.0, -12.0, 12.0, 20.0, 28.0]:
		var dash_inst := MeshInstance3D.new()
		dash_inst.mesh = dash_mesh
		dash_inst.material_override = dash_mat
		dash_inst.position = Vector3(x, -0.07, 3.5)
		dash_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stage.add_child(dash_inst)

	# Pastel background buildings
	for b_data: Dictionary in BUILDINGS:
		var b_size: Vector3 = b_data["size"]
		var b_mesh := BoxMesh.new()
		b_mesh.size = b_size

		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = b_data["colour"]
		b_mat.roughness = 0.9

		var b_inst := MeshInstance3D.new()
		b_inst.mesh = b_mesh
		b_inst.material_override = b_mat
		b_inst.position = Vector3(b_data["pos"].x, -0.08 + b_size.y * 0.5, b_data["pos"].z)
		b_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stage.add_child(b_inst)
