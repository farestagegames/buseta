class_name DriverFigure
extends RefCounted
## Builds a driver out of boxes from a DriverLook. The head is measured from its
## centre and the torso from the middle of the chest. Faces look along -Z.

const TOWEL := Color(0.96, 0.96, 0.94)
const TORSO_SIZE := Vector3(0.42, 0.62, 0.26)
## From the middle of the chest up to the centre of the head.
const HEAD_ABOVE_CHEST := 0.48
## Sleeves stop above the elbow, so this much of the arm is shirt.
const SHORT_SLEEVE := 0.3


static func add_torso(b: LowPolyBuilder, look: DriverLook, chest: Vector3) -> void:
	b.box(chest, TORSO_SIZE, look.uniform)
	b.box(chest + Vector3(0.0, 0.27, 0.0), Vector3(0.47, 0.1, 0.27), look.uniform)
	var front := -TORSO_SIZE.z / 2.0 - 0.005
	if look.outfit == "guayabera":
		_add_guayabera(b, look, chest, front)
	else:
		_add_polo(b, look, chest, front)
	if look.towel:
		_add_towel(b, chest)


## A collar in the trim colour, open at the neck, and a short placket with buttons.
static func _add_polo(b: LowPolyBuilder, look: DriverLook, chest: Vector3, front: float) -> void:
	b.box(chest + Vector3(0.0, 0.26, front), Vector3(0.06, 0.07, 0.01), look.skin)
	b.box(chest + Vector3(0.0, 0.325, 0.01), Vector3(0.18, 0.012, 0.16), look.trim)
	for side: float in [-1.0, 1.0]:
		b.box(chest + Vector3(side * 0.045, 0.28, front - 0.002), Vector3(0.035, 0.07, 0.012), look.trim)
	b.box(chest + Vector3(0.0, 0.16, front - 0.002), Vector3(0.035, 0.12, 0.008), look.uniform.darkened(0.12))
	for y: float in [0.19, 0.13]:
		b.box(chest + Vector3(0.0, y, front - 0.005), Vector3(0.012, 0.012, 0.006), look.trim)


## Folded over the left shoulder, hanging a little down the front and the back.
static func _add_towel(b: LowPolyBuilder, chest: Vector3) -> void:
	var shoulder := chest + Vector3(-0.15, 0.32, 0.0)
	b.box(shoulder, Vector3(0.12, 0.02, 0.29), TOWEL)
	for z: float in [-0.14, 0.14]:
		b.box(shoulder + Vector3(0.0, -0.1, z), Vector3(0.12, 0.2, 0.015), TOWEL)
	b.box(shoulder + Vector3(0.0, -0.19, -0.149), Vector3(0.12, 0.02, 0.006), TOWEL.darkened(0.2))


## An open collar, pleats down both sides of the buttons and four pockets.
static func _add_guayabera(b: LowPolyBuilder, look: DriverLook, chest: Vector3, front: float) -> void:
	b.box(chest + Vector3(0.0, 0.25, front), Vector3(0.1, 0.09, 0.01), look.skin)
	for side: float in [-1.0, 1.0]:
		b.box(chest + Vector3(side * 0.075, 0.27, front - 0.002), Vector3(0.06, 0.04, 0.012), look.uniform.lightened(0.3))
		for x: float in [0.06, 0.17]:
			b.box(chest + Vector3(side * x, -0.02, front - 0.003), Vector3(0.014, 0.52, 0.008), look.trim)
		b.box(chest + Vector3(side * 0.115, 0.08, front - 0.004), Vector3(0.075, 0.07, 0.008), look.trim)
		b.box(chest + Vector3(side * 0.115, -0.2, front - 0.004), Vector3(0.085, 0.08, 0.008), look.trim)
	b.box(chest + Vector3(0.0, -0.03, front - 0.003), Vector3(0.018, 0.5, 0.008), look.uniform.darkened(0.08))


static func add_head(b: LowPolyBuilder, look: DriverLook, head: Vector3) -> void:
	b.box(head + Vector3(0.0, -0.17, 0.0), Vector3(0.1, 0.12, 0.1), look.skin)
	HeadParts.add_face(b, head, look.skin)
	# A headwrap covers the hair completely, as in the portrait.
	if look.hat != "headwrap":
		HeadParts.add_hair(b, head, look.hair_style, look.hair, look.accent, look.skin)
	if look.greying:
		HeadParts.add_temples(b, head, look.temple_colour())
	HeadParts.add_beard(b, head, look.beard, look.beard_colour())
	if look.earrings:
		HeadParts.add_earrings(b, head)
	if look.glasses:
		HeadParts.add_glasses(b, head)
	HeadParts.add_hat(b, head, look.hat, look.hat_colour(), look.trim)


## A head and shoulders for the menus, with the chest at the origin.
static func build_bust(look: DriverLook) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	add_torso(b, look, Vector3.ZERO)
	add_head(b, look, Vector3(0.0, HEAD_ABOVE_CHEST, 0.0))
	return b.build(LowPolyBuilder.vertex_colour_material())


## A face for the interior mirror, looking back at the driver. Only the part inside
## window is kept, if one is given.
static func build_head(look: DriverLook, window := AABB()) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	b.clip = window
	add_head(b, look, Vector3.ZERO)
	return b.build(LowPolyBuilder.vertex_colour_material())


## An arm one metre long, from the elbow at the origin along -Z. It is scaled to
## fit the reach. Every outfit has short sleeves, so the forearm shows.
static func build_sleeve(look: DriverLook) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	b.box(Vector3(0.0, 0.0, -SHORT_SLEEVE / 2.0), Vector3(0.11, 0.11, SHORT_SLEEVE), look.uniform)
	b.box(Vector3(0.0, 0.0, -0.5 - SHORT_SLEEVE / 2.0), Vector3(0.085, 0.085, 1.0 - SHORT_SLEEVE), look.skin)
	return b.build(LowPolyBuilder.vertex_colour_material())


static func build_hand(look: DriverLook) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	b.box(Vector3.ZERO, Vector3(0.1, 0.08, 0.13), look.skin)
	return b.build(LowPolyBuilder.vertex_colour_material())
