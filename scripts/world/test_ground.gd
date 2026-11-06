class_name TestGround
extends Node3D
## Flat proving ground for Phase 1: a road strip with a slalom, a marked bus bay
## and solid blocks to test collisions and the rear overhang.

const GROUND_SIZE := 800.0
const TILE_METRES := 10.0
const STRIP_FRONT := -320.0
const STRIP_BACK := 60.0
const ROAD_WIDTH := 7.5
const LINE := Color(0.92, 0.92, 0.88)
const CONE := Color(0.95, 0.42, 0.08)
const BLOCK_COLOURS: Array[Color] = [
	Color(0.62, 0.55, 0.48), Color(0.5, 0.56, 0.62), Color(0.68, 0.62, 0.5), Color(0.55, 0.48, 0.5),
]


func _ready() -> void:
	_build_ground()
	var props := LowPolyBuilder.new()
	_add_road(props)
	_add_slalom(props)
	_add_bus_bay(props)
	_add_blocks(props)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = props.build(LowPolyBuilder.vertex_colour_material())
	add_child(mesh_instance)


func _build_ground() -> void:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	image.fill(Color(0.3, 0.36, 0.28))
	for i in size:
		var line := Color(0.34, 0.41, 0.32)
		for offset: int in [0, 1]:
			image.set_pixel(i, offset, line)
			image.set_pixel(offset, i, line)
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.uv1_scale = Vector3.ONE * (GROUND_SIZE / TILE_METRES)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 1.0
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * GROUND_SIZE
	plane.material = material
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _add_road(b: LowPolyBuilder) -> void:
	var length := STRIP_BACK - STRIP_FRONT
	var mid := (STRIP_BACK + STRIP_FRONT) / 2.0
	b.box(Vector3(0.0, 0.01, mid), Vector3(ROAD_WIDTH, 0.02, length), Color(0.2, 0.2, 0.22))
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * (ROAD_WIDTH / 2.0 - 0.2), 0.03, mid), Vector3(0.15, 0.02, length), LINE)
	var z := STRIP_BACK
	while z > STRIP_FRONT:
		b.box(Vector3(0.0, 0.03, z), Vector3(0.15, 0.02, 3.0), LINE)
		z -= 8.0


func _add_slalom(b: LowPolyBuilder) -> void:
	for i in 6:
		var z := -70.0 - i * 26.0
		b.box(Vector3(0.0, 0.4, z), Vector3(0.45, 0.8, 0.45), CONE)


func _add_bus_bay(b: LowPolyBuilder) -> void:
	# A 16 m bay on the right of the road, to practise pulling in and stopping.
	var left_x := ROAD_WIDTH / 2.0
	var depth := 3.2
	var front_z := -45.0
	var back_z := -29.0
	var mid_z := (front_z + back_z) / 2.0
	var length := back_z - front_z
	b.box(Vector3(left_x + depth / 2.0, 0.01, mid_z), Vector3(depth, 0.02, length), Color(0.24, 0.24, 0.27))
	b.box(Vector3(left_x + depth, 0.05, mid_z), Vector3(0.2, 0.06, length), Color(0.95, 0.8, 0.2))
	for z: float in [front_z, back_z]:
		b.box(Vector3(left_x + depth / 2.0, 0.05, z), Vector3(depth, 0.06, 0.2), Color(0.95, 0.8, 0.2))
	b.box(Vector3(left_x + depth + 1.0, 1.5, front_z + 1.0), Vector3(0.12, 3.0, 0.12), Color(0.2, 0.2, 0.25))
	b.box(Vector3(left_x + depth + 1.0, 3.0, front_z + 1.0), Vector3(0.1, 0.5, 0.7), Color(0.1, 0.4, 0.8))


func _add_blocks(b: LowPolyBuilder) -> void:
	var placements: Array[Array] = [
		[Vector3(-16.0, 4.0, -30.0), Vector3(14.0, 8.0, 18.0)],
		[Vector3(-16.0, 6.0, -80.0), Vector3(14.0, 12.0, 26.0)],
		[Vector3(18.0, 5.0, -90.0), Vector3(16.0, 10.0, 22.0)],
		[Vector3(-18.0, 3.5, -150.0), Vector3(16.0, 7.0, 34.0)],
		[Vector3(20.0, 7.0, -170.0), Vector3(18.0, 14.0, 24.0)],
		[Vector3(0.0, 1.0, -345.0), Vector3(40.0, 2.0, 2.0)],
		[Vector3(35.0, 1.0, -20.0), Vector3(2.0, 2.0, 60.0)],
	]
	for i in placements.size():
		var centre: Vector3 = placements[i][0]
		var size: Vector3 = placements[i][1]
		b.box(centre, size, BLOCK_COLOURS[i % BLOCK_COLOURS.size()])
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.position = centre
		body.add_child(shape)
		add_child(body)
