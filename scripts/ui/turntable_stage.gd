class_name TurntableStage
extends PreviewStage
## A full-screen 3D stage behind the main menu with the player's bus on a turntable.
##
## The bus stands on a low round platform with a yellow edge, on the island of an
## open roundabout in the seaside town of Puerto Marisol, ringed by pastel buildings. The turntable can be dragged
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

const YELLOW_RING := Color(1.0, 0.78, 0.2)
const DISC_GREY := Color(0.18, 0.19, 0.22)

## The roundabout in Puerto Marisol, in metres with the island at the origin.
const ROAD_Y := -0.08
const PAVEMENT_Y := 0.07
const RING_RADIUS := 15.0
const ARM_WIDTH := 10.0
const ARM_FACE := 8.0 ## Where the buildings' faces stand, from the arm's middle.
const WORLD_EDGE := 90.0
const ARC_SEGMENTS := 10
const ZEBRA_AT := 20.0
const STOREY := 3.2
const PALM_HEIGHT := 6.0
const LAMP_HEIGHT := 5.0
const SCENERY_SEED := 20260117
const ASPHALT := Color(0.30, 0.31, 0.33)
const PAVEMENT := Color(0.88, 0.82, 0.72)
const KERB := Color(0.92, 0.92, 0.9)
const WINDOW_GLASS := Color(0.22, 0.3, 0.38)
const WINDOW_LIT := Color(1.0, 0.82, 0.5)
const WINDOW_NIGHT_DARK := Color(0.1, 0.13, 0.18)
const LAMP_ON := Color(1.0, 0.85, 0.55)
const LAMP_OFF := Color(0.85, 0.85, 0.8)

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

## The time of day the stage is lit for.
var shown_time: TimeOfDay

var _visual: BusVisual
var _scenery_meshes: int = 0
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _night_light: OmniLight3D
var _lamp_material: StandardMaterial3D
var _windows_instance: MultiMeshInstance3D
var _windows: MultiMesh
var _window_rolls := PackedFloat32Array()
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
	set_time_of_day(Profile.chosen_time())
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


## How many meshes the scenery made, for the test that keeps the phone's draw calls down.
func scenery_mesh_count() -> int:
	return _scenery_meshes


## Whether the lamps, windows and the light over the bus are on.
func lights_on() -> bool:
	return shown_time != null and shown_time.lights > 0.5


func sun_light() -> DirectionalLight3D:
	return _sun


func night_light() -> OmniLight3D:
	return _night_light


func world_environment() -> Environment:
	return _environment


## Sets the sky, fog, sun and ambient light to a time of day, and lights the lamps
## and windows when it is night.
func set_time_of_day(time: TimeOfDay) -> void:
	shown_time = time
	if time == null or stage == null:
		return
	var air := Atmosphere.mix(time, RainSettings.new(), 0.0, 0.0)
	if _sky_material != null:
		_sky_material.sky_top_color = air.sky_top
		_sky_material.sky_horizon_color = air.sky_horizon
		_sky_material.ground_horizon_color = air.sky_horizon
		_sky_material.ground_bottom_color = air.ground_bottom
	if _environment != null:
		_environment.fog_light_color = air.fog
		_environment.ambient_light_color = air.ambient
		_environment.ambient_light_energy = air.ambient_energy
	if _sun != null:
		_sun.light_color = air.sun_colour
		_sun.light_energy = air.sun_energy
		_sun.rotation = air.sun_rotation
		_sun.shadow_enabled = false
	var night := lights_on()
	if _night_light != null:
		_night_light.visible = night
	if _lamp_material != null:
		_lamp_material.emission_enabled = night
		_lamp_material.albedo_color = LAMP_ON if night else LAMP_OFF
	_light_windows(night, maxf(time.windows, 0.5))


func _light_windows(night: bool, share: float) -> void:
	if _windows == null:
		return
	var count := _window_rolls.size()
	for i in count:
		var colour := WINDOW_GLASS
		if night:
			colour = WINDOW_LIT if _window_rolls[i] < share else WINDOW_NIGHT_DARK
		_windows.set_instance_color(i, colour)
	var material: StandardMaterial3D = _windows_instance.material_override
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if night else BaseMaterial3D.SHADING_MODE_PER_PIXEL


func _build_scenery() -> void:
	_scenery_meshes = 0
	var theme := CityTheme.new()
	var map_path := Country.pack.resolve("maps/puerto_marisol.json")
	if FileAccess.file_exists(map_path):
		theme = CityTheme.from_data(MapLoader.read_json(map_path))

	# Sky and light haze.
	for child in stage.get_children():
		if child is WorldEnvironment and child.environment != null:
			_environment = child.environment
		elif child is DirectionalLight3D:
			_sun = child
	if _environment != null:
		_sky_material = ProceduralSkyMaterial.new()
		var sky := Sky.new()
		sky.sky_material = _sky_material
		_environment.sky = sky
		_environment.background_mode = Environment.BG_SKY
		_environment.fog_enabled = true
		_environment.fog_density = 0.004
		_environment.fog_sky_affect = 0.3
	if _sun != null:
		_sun.shadow_enabled = false

	# The turntable is the central island: yellow ring and dark disc.
	_add_mesh(pivot, _cylinder(7.0, 0.08, YELLOW_RING), Vector3(0.0, -0.04, 0.0))
	_add_mesh(pivot, _cylinder(6.65, 0.082, DISC_GREY), Vector3(0.0, -0.039, 0.0))

	# Asphalt: roads are wherever the pavement is not.
	var ground := PlaneMesh.new()
	ground.size = Vector2(240.0, 240.0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = ASPHALT
	ground_mat.roughness = 0.95
	ground.material = ground_mat
	_add_mesh(stage, ground, Vector3(0.0, ROAD_Y, 0.0))

	_add_mesh(stage, _build_sidewalks(), Vector3.ZERO)
	_build_markings()

	var rng := RandomNumberGenerator.new()
	rng.seed = SCENERY_SEED
	_build_town(rng, theme)
	_build_palms(rng, theme)
	_build_lamps()

	_night_light = OmniLight3D.new()
	_night_light.position = Vector3(0.0, 7.0, 0.0)
	_night_light.omni_range = 22.0
	_night_light.light_energy = 1.6
	_night_light.light_color = Color(1.0, 0.85, 0.6)
	_night_light.shadow_enabled = false
	_night_light.visible = false
	stage.add_child(_night_light)


func _cylinder(radius: float, height: float, colour: Color) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	mesh.material = material
	return mesh


func _add_mesh(parent: Node, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	_scenery_meshes += 1
	return instance


func _vertex_colour_material(roughness: float = 0.9) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = roughness
	return material


## One MultiMesh of a mesh at many transforms, optionally one colour each.
func _multi(mesh: Mesh, transforms: Array[Transform3D], colours: Array[Color], material: Material) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not colours.is_empty()
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
		if not colours.is_empty():
			multi.set_instance_color(i, colours[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(instance)
	_scenery_meshes += 1
	return instance


static func _box_transform(centre: Vector3, scale: Vector3, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), centre)


## A triangle whose front (clockwise) side faces the wanted normal.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, colour: Color) -> void:
	var cross := (b - a).cross(c - a)
	if cross.dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
	st.set_color(colour)
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_color(colour)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_color(colour)
	st.set_normal(normal)
	st.add_vertex(c)


## A kerb wall from road level to the pavement top along a line, facing the road.
static func _kerb(st: SurfaceTool, a: Vector2, b: Vector2, normal: Vector3) -> void:
	var a_low := Vector3(a.x, ROAD_Y, a.y)
	var b_low := Vector3(b.x, ROAD_Y, b.y)
	var a_high := Vector3(a.x, PAVEMENT_Y, a.y)
	var b_high := Vector3(b.x, PAVEMENT_Y, b.y)
	_tri(st, a_low, b_low, b_high, normal, KERB)
	_tri(st, a_low, b_high, a_high, normal, KERB)


## The four corner pavements as one mesh, with kerbs along the arc and arm edges.
func _build_sidewalks() -> ArrayMesh:
	var half_arm := ARM_WIDTH / 2.0
	var reach := sqrt(RING_RADIUS * RING_RADIUS - half_arm * half_arm)
	var quadrant := PackedVector2Array()
	var angle_from := atan2(reach, half_arm)
	var angle_to := atan2(half_arm, reach)
	for i in ARC_SEGMENTS + 1:
		var angle := lerpf(angle_from, angle_to, float(i) / ARC_SEGMENTS)
		quadrant.append(Vector2(cos(angle), sin(angle)) * RING_RADIUS)
	# Pin the ends exactly onto the arm edges.
	quadrant[0] = Vector2(half_arm, reach)
	quadrant[ARC_SEGMENTS] = Vector2(reach, half_arm)
	quadrant.append(Vector2(WORLD_EDGE, half_arm))
	quadrant.append(Vector2(WORLD_EDGE, WORLD_EDGE))
	quadrant.append(Vector2(half_arm, WORLD_EDGE))
	var triangles := Geometry2D.triangulate_polygon(quadrant)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var flip := Vector2(sx, sz)
			var points := PackedVector2Array()
			for p in quadrant:
				points.append(p * flip)
			for t in range(0, triangles.size(), 3):
				var a := points[triangles[t]]
				var b := points[triangles[t + 1]]
				var c := points[triangles[t + 2]]
				_tri(st, Vector3(a.x, PAVEMENT_Y, a.y), Vector3(b.x, PAVEMENT_Y, b.y), Vector3(c.x, PAVEMENT_Y, c.y), Vector3.UP, PAVEMENT)
			for i in ARC_SEGMENTS:
				var mid := (points[i] + points[i + 1]) * 0.5
				var inward := -mid.normalized()
				_kerb(st, points[i], points[i + 1], Vector3(inward.x, 0.0, inward.y))
			_kerb(st, Vector2(half_arm * sx, reach * sz), Vector2(half_arm * sx, WORLD_EDGE * sz), Vector3(-sx, 0.0, 0.0))
			_kerb(st, Vector2(reach * sx, half_arm * sz), Vector2(WORLD_EDGE * sx, half_arm * sz), Vector3(0.0, 0.0, -sz))
	var mesh := st.commit()
	mesh.surface_set_material(0, _sidewalk_material())
	return mesh


func _sidewalk_material() -> StandardMaterial3D:
	var material := _vertex_colour_material()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Roundabout dashes, centre lines and zebra crossings as one MultiMesh.
func _build_markings() -> void:
	var transforms: Array[Transform3D] = []
	var y := ROAD_Y + 0.02
	for i in 24:
		var angle := TAU * float(i) / 24.0
		var at := Vector3(cos(angle), 0.0, sin(angle)) * 11.0
		at.y = y
		transforms.append(_box_transform(at, Vector3(1.8, 0.02, 0.25), -(angle + PI / 2.0)))
	for arm in 4:
		var yaw := PI / 2.0 * arm
		var along := Basis(Vector3.UP, yaw) * Vector3.RIGHT
		var across := Basis(Vector3.UP, yaw) * Vector3.BACK
		var r := 17.0
		while r + 1.5 <= 80.0:
			if absf(r + 1.5 - ZEBRA_AT) > 3.2:
				transforms.append(_box_transform(along * (r + 1.5) + Vector3(0.0, y, 0.0), Vector3(3.0, 0.02, 0.25), yaw))
			r += 6.0
		for s in 6:
			var offset := -4.0 + 1.6 * s
			transforms.append(_box_transform(along * ZEBRA_AT + across * offset + Vector3(0.0, y, 0.0), Vector3(3.0, 0.02, 0.6), yaw))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.95, 0.92)
	material.roughness = 0.9
	var none: Array[Color] = []
	_multi(BoxMesh.new(), transforms, none, material)


func _build_town(rng: RandomNumberGenerator, theme: CityTheme) -> void:
	var transforms: Array[Transform3D] = []
	var colours: Array[Color] = []
	var roof_transforms: Array[Transform3D] = []
	var roof_colours: Array[Color] = []
	var window_transforms: Array[Transform3D] = []
	var rolls := PackedFloat32Array()

	# Corner blocks fronting the ring.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var faces: Array[Vector3] = [Vector3(-sx, 0.0, 0.0), Vector3(0.0, 0.0, -sz)]
			_add_building(rng, theme, Vector3(sx * 18.0, 0.0, sz * 18.0), Vector2(10.0, 10.0), rng.randf_range(7.0, 10.0), faces,
					transforms, colours, roof_transforms, roof_colours, window_transforms, rolls)

	# Both sides of every arm.
	for arm in 4:
		var yaw := PI / 2.0 * arm
		var along := Basis(Vector3.UP, yaw) * Vector3.RIGHT
		var across := Basis(Vector3.UP, yaw) * Vector3.BACK
		var along_x := arm % 2 == 0
		for side: float in [-1.0, 1.0]:
			var start := 24.0
			while true:
				var width := rng.randf_range(8.0, 16.0)
				var depth := rng.randf_range(8.0, 12.0)
				if start + width > 72.0:
					break
				var centre := along * (start + width / 2.0) + across * side * (ARM_FACE + depth / 2.0)
				var footprint := Vector2(width, depth) if along_x else Vector2(depth, width)
				var faces: Array[Vector3] = [-across * side]
				_add_building(rng, theme, centre, footprint, rng.randf_range(6.5, 10.0), faces,
						transforms, colours, roof_transforms, roof_colours, window_transforms, rolls)
				start += width + rng.randf_range(1.0, 2.5)

	# The back row that covers the horizon.
	var x := -120.0
	while x < 120.0:
		var width := rng.randf_range(12.0, 18.0)
		var faces: Array[Vector3] = [Vector3.BACK]
		_add_building(rng, theme, Vector3(x + width / 2.0, 0.0, -78.0), Vector2(width, 10.0), rng.randf_range(11.0, 16.0), faces,
				transforms, colours, roof_transforms, roof_colours, window_transforms, rolls)
		x += width + rng.randf_range(0.0, 1.0)

	var walls_material := _vertex_colour_material()
	_multi(BoxMesh.new(), transforms, colours, walls_material)
	_multi(BoxMesh.new(), roof_transforms, roof_colours, _vertex_colour_material())

	var glass := _vertex_colour_material(0.3)
	var white: Array[Color] = []
	for i in window_transforms.size():
		white.append(WINDOW_GLASS)
	_windows_instance = _multi(BoxMesh.new(), window_transforms, white, glass)
	_windows = _windows_instance.multimesh
	_window_rolls = rolls


func _add_building(rng: RandomNumberGenerator, theme: CityTheme, centre: Vector3, footprint: Vector2, height: float, faces: Array[Vector3],
		transforms: Array[Transform3D], colours: Array[Color], roof_transforms: Array[Transform3D], roof_colours: Array[Color],
		window_transforms: Array[Transform3D], rolls: PackedFloat32Array) -> void:
	transforms.append(_box_transform(Vector3(centre.x, ROAD_Y + height / 2.0, centre.z), Vector3(footprint.x, height, footprint.y)))
	colours.append(theme.walls[rng.randi() % theme.walls.size()])
	roof_transforms.append(_box_transform(Vector3(centre.x, ROAD_Y + height + 0.2, centre.z), Vector3(footprint.x + 0.6, 0.4, footprint.y + 0.6)))
	roof_colours.append(theme.roofs[rng.randi() % theme.roofs.size()])
	var storeys := maxi(2, int(height / STOREY))
	for face in faces:
		var along_x := absf(face.x) > 0.5
		var reach := footprint.x / 2.0 if along_x else footprint.y / 2.0
		var width := footprint.y if along_x else footprint.x
		var tangent := Vector3.BACK if along_x else Vector3.RIGHT
		var columns := maxi(1, int(width / 3.5))
		var step := width / columns
		var scale := Vector3(0.1, 1.4, 1.2) if along_x else Vector3(1.2, 1.4, 0.1)
		for storey in storeys:
			for column in columns:
				var offset := -width / 2.0 + step * (column + 0.5)
				var at := centre + face * (reach + 0.06) + tangent * offset
				at.y = ROAD_Y + storey * STOREY + 1.9
				window_transforms.append(_box_transform(at, scale))
				rolls.append(rng.randf())


func _build_palms(rng: RandomNumberGenerator, theme: CityTheme) -> void:
	var spots: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			spots.append(Vector3(sx * 11.5, PAVEMENT_Y, sz * 11.5))
			spots.append(Vector3(sx * 18.0, PAVEMENT_Y, sz * 6.5))
			spots.append(Vector3(sx * 6.5, PAVEMENT_Y, sz * 18.0))
	var trunks: Array[Transform3D] = []
	var fronds: Array[Transform3D] = []
	for spot in spots:
		var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.09, 0.09), 0.0, rng.randf_range(-0.09, 0.09)))
		trunks.append(Transform3D(tilt, spot + tilt * Vector3(0.0, PALM_HEIGHT / 2.0, 0.0)))
		var top := spot + tilt * Vector3(0.0, PALM_HEIGHT, 0.0)
		var spin := rng.randf() * TAU
		for i in 6:
			var yaw := Basis(Vector3.UP, spin + TAU * i / 6.0)
			var droop := deg_to_rad(-20.0)
			var basis := yaw * Basis(Vector3.BACK, droop) * Basis.from_scale(Vector3(3.2, 0.12, 0.7))
			var centre := top + yaw * Vector3(1.5 * cos(droop), 1.5 * sin(droop), 0.0)
			fronds.append(Transform3D(basis, centre))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.26
	trunk_mesh.height = PALM_HEIGHT
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = theme.palm_trunk
	trunk_material.roughness = 0.9
	var none: Array[Color] = []
	_multi(trunk_mesh, trunks, none, trunk_material)
	var leaf_material := StandardMaterial3D.new()
	leaf_material.albedo_color = theme.palm_leaf
	leaf_material.roughness = 0.9
	_multi(BoxMesh.new(), fronds, none, leaf_material)


func _build_lamps() -> void:
	var poles: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			for degrees: float in [30.0, 60.0]:
				var angle := deg_to_rad(degrees)
				var at := Vector3(cos(angle) * sx, 0.0, sin(angle) * sz) * (RING_RADIUS + 0.5)
				poles.append(Transform3D(Basis.IDENTITY, at + Vector3(0.0, PAVEMENT_Y + LAMP_HEIGHT / 2.0, 0.0)))
				heads.append(Transform3D(Basis.IDENTITY, at + Vector3(0.0, PAVEMENT_Y + LAMP_HEIGHT + 0.2, 0.0)))
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = LAMP_HEIGHT
	pole_mesh.radial_segments = 6
	pole_mesh.rings = 1
	var pole_material := StandardMaterial3D.new()
	pole_material.albedo_color = Color(0.25, 0.27, 0.3)
	var none: Array[Color] = []
	_multi(pole_mesh, poles, none, pole_material)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.28
	head_mesh.height = 0.56
	head_mesh.radial_segments = 8
	head_mesh.rings = 4
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.albedo_color = LAMP_OFF
	_lamp_material.emission = Color(1.0, 0.78, 0.45)
	_lamp_material.emission_energy_multiplier = 3.0
	_lamp_material.emission_enabled = false
	_multi(head_mesh, heads, none, _lamp_material)
