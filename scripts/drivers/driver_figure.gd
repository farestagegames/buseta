class_name DriverFigure
extends RefCounted
## Builds a driver out of boxes from a DriverLook. The head is measured from its
## centre and the torso from the middle of the chest. Faces look along -Z.

const DARK := Color(0.06, 0.06, 0.08)
const SHIRT := Color(0.9, 0.92, 0.95)
const TORSO_SIZE := Vector3(0.42, 0.62, 0.26)
const HEAD_SIZE := Vector3(0.21, 0.26, 0.23)
## From the middle of the chest up to the centre of the head.
const HEAD_ABOVE_CHEST := 0.48


static func add_torso(b: LowPolyBuilder, look: DriverLook, chest: Vector3) -> void:
	b.box(chest, TORSO_SIZE, look.uniform)
	b.box(chest + Vector3(0.0, 0.27, 0.0), Vector3(0.47, 0.1, 0.27), look.uniform)
	var front := -TORSO_SIZE.z / 2.0 - 0.005
	b.box(chest + Vector3(0.0, 0.2, front), Vector3(0.14, 0.2, 0.01), SHIRT)
	b.box(chest + Vector3(0.0, 0.14, front - 0.005), Vector3(0.045, 0.28, 0.01), look.trim)
	b.box(chest + Vector3(0.13, 0.13, front - 0.002), Vector3(0.08, 0.05, 0.01), look.trim)


static func add_head(b: LowPolyBuilder, look: DriverLook, head: Vector3) -> void:
	b.box(head + Vector3(0.0, -0.17, 0.0), Vector3(0.1, 0.12, 0.1), look.skin)
	b.box(head, HEAD_SIZE, look.skin)
	var face := -HEAD_SIZE.z / 2.0 - 0.003
	for side: float in [-0.055, 0.055]:
		b.box(head + Vector3(side, 0.03, face), Vector3(0.035, 0.03, 0.01), DARK)
	_add_hair(b, look, head)
	_add_beard(b, look, head, face)
	if look.glasses:
		for side: float in [-0.055, 0.055]:
			b.box(head + Vector3(side, 0.03, face - 0.006), Vector3(0.075, 0.055, 0.004), Color(0.75, 0.82, 0.9))
		b.box(head + Vector3(0.0, 0.04, face - 0.008), Vector3(0.05, 0.012, 0.006), DARK)
	if look.cap:
		b.box(head + Vector3(0.0, 0.15, 0.01), Vector3(0.25, 0.08, 0.27), look.uniform)
		b.box(head + Vector3(0.0, 0.115, 0.01), Vector3(0.255, 0.025, 0.275), look.trim)
		b.box(head + Vector3(0.0, 0.105, -0.17), Vector3(0.2, 0.02, 0.11), DARK)


static func _add_hair(b: LowPolyBuilder, look: DriverLook, head: Vector3) -> void:
	var colour := look.hair
	var top := head + Vector3(0.0, 0.145, 0.01)
	var back := head + Vector3(0.0, 0.03, 0.115)
	match look.hair_style:
		"short":
			b.box(top, Vector3(0.23, 0.07, 0.25), colour)
			b.box(back, Vector3(0.23, 0.2, 0.05), colour)
		"bob":
			b.box(top, Vector3(0.24, 0.08, 0.26), colour)
			b.box(back + Vector3(0.0, -0.03, 0.0), Vector3(0.25, 0.3, 0.06), colour)
			for side: float in [-1.0, 1.0]:
				b.box(head + Vector3(side * 0.125, -0.01, 0.03), Vector3(0.05, 0.3, 0.2), colour)
		"bun":
			b.box(top, Vector3(0.23, 0.07, 0.25), colour)
			b.box(back, Vector3(0.23, 0.2, 0.05), colour)
			b.box(head + Vector3(0.0, 0.2, 0.08), Vector3(0.13, 0.12, 0.13), colour)
		"plait":
			b.box(top, Vector3(0.23, 0.07, 0.25), colour)
			b.box(back, Vector3(0.23, 0.22, 0.05), colour)
			b.box(head + Vector3(0.0, -0.27, 0.15), Vector3(0.08, 0.42, 0.06), colour)
		"afro":
			b.box(head + Vector3(0.0, 0.16, 0.03), Vector3(0.34, 0.2, 0.34), colour)
			b.box(head + Vector3(0.0, 0.03, 0.14), Vector3(0.32, 0.22, 0.1), colour)
			for side: float in [-1.0, 1.0]:
				b.box(head + Vector3(side * 0.135, 0.05, 0.04), Vector3(0.07, 0.16, 0.2), colour)
		"hijab":
			b.box(head + Vector3(0.0, 0.14, 0.01), Vector3(0.26, 0.05, 0.27), colour)
			b.box(head + Vector3(0.0, 0.0, 0.125), Vector3(0.26, 0.32, 0.05), colour)
			for side: float in [-1.0, 1.0]:
				b.box(head + Vector3(side * 0.12, 0.0, 0.01), Vector3(0.035, 0.32, 0.24), colour)
			b.box(head + Vector3(0.0, -0.17, 0.0), Vector3(0.28, 0.13, 0.27), colour)


static func _add_beard(b: LowPolyBuilder, look: DriverLook, head: Vector3, face: float) -> void:
	match look.beard:
		"moustache":
			b.box(head + Vector3(0.0, -0.045, face), Vector3(0.12, 0.03, 0.012), look.hair)
		"full":
			b.box(head + Vector3(0.0, -0.08, face + 0.002), Vector3(0.215, 0.11, 0.016), look.hair)
			b.box(head + Vector3(0.0, -0.13, 0.0), Vector3(0.215, 0.05, 0.23), look.hair)


## A head and shoulders for the menus, with the chest at the origin.
static func build_bust(look: DriverLook) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	add_torso(b, look, Vector3.ZERO)
	add_head(b, look, Vector3(0.0, HEAD_ABOVE_CHEST, 0.0))
	return b.build(LowPolyBuilder.vertex_colour_material())


## A face for the interior mirror, looking back at the driver.
static func build_head(look: DriverLook) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	add_head(b, look, Vector3.ZERO)
	return b.build(LowPolyBuilder.vertex_colour_material())


## A sleeve one metre long, from the origin along -Z. It is scaled to fit the arm.
static func build_sleeve(look: DriverLook) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	b.box(Vector3(0.0, 0.0, -0.5), Vector3(0.1, 0.1, 1.0), look.uniform)
	return b.build(LowPolyBuilder.vertex_colour_material())


static func build_hand(look: DriverLook) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	b.box(Vector3.ZERO, Vector3(0.1, 0.08, 0.13), look.skin)
	return b.build(LowPolyBuilder.vertex_colour_material())
