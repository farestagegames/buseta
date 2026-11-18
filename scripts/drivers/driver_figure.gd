class_name DriverFigure
extends RefCounted
## Builds a driver out of boxes from a DriverLook. The head is measured from its
## centre and the torso from the middle of the chest. Faces look along -Z.

const TOWEL := Color(0.96, 0.96, 0.94)
## Special items.
const SHIRT_WHITE := Color(0.96, 0.96, 0.95)
const SHIRT_RED := Color(0.82, 0.1, 0.14)
const VEST := Color(0.78, 1.0, 0.1)
const SILVER := Color(0.82, 0.84, 0.88)
const LEATHER := Color(0.5, 0.3, 0.14)
const LEATHER_DARK := Color(0.3, 0.17, 0.08)
const BEAD_BROWN := Color(0.42, 0.24, 0.1)
const NECKERCHIEF := Color(0.8, 0.1, 0.12)
const GLOVE := Color(0.08, 0.08, 0.09)
const GLOVE_STRIPE := Color(1.0, 0.5, 0.08)
const TORSO_SIZE := Vector3(0.42, 0.62, 0.26)
## From the middle of the chest up to the centre of the head.
const HEAD_ABOVE_CHEST := 0.48
## Sleeves stop above the elbow, so this much of the arm is shirt.
const SHORT_SLEEVE := 0.3


static func add_torso(b: LowPolyBuilder, look: DriverLook, chest: Vector3) -> void:
	var striped := look.outfit == "rojiblanca"
	b.box(chest, TORSO_SIZE, SHIRT_WHITE if striped else look.uniform)
	b.box(chest + Vector3(0.0, 0.27, 0.0), Vector3(0.47, 0.1, 0.27), SHIRT_RED if striped else look.uniform)
	var front := -TORSO_SIZE.z / 2.0 - 0.005
	match look.outfit:
		"guayabera":
			_add_guayabera(b, look, chest, front)
		"rojiblanca":
			_add_rojiblanca(b, look, chest, front)
		"chaleco":
			_add_polo(b, look, chest, front)
			_add_vest(b, chest)
		"floral":
			_add_floral(b, look, chest, front)
		"ruana":
			_add_ruana(b, look, chest, front)
		_:
			_add_polo(b, look, chest, front)
	if look.towel:
		_add_towel(b, chest)
	match look.neck:
		"gold_chain":
			_add_gold_chain(b, chest, front)
		"rosary":
			_add_rosary(b, chest, front)
		"panuelo":
			_add_neckerchief(b, chest, front)
	if look.shoulder == "carriel":
		_add_carriel(b, chest, front)


## Vertical red and white stripes down the front and back, with a plain red collar.
## No crest or badge.
static func _add_rojiblanca(b: LowPolyBuilder, look: DriverLook, chest: Vector3, front: float) -> void:
	for i in 5:
		var x := -0.168 + float(i) * 0.084
		b.box(chest + Vector3(x, 0.0, front + 0.005), Vector3(0.042, 0.62, 0.012), SHIRT_RED)
		b.box(chest + Vector3(x, 0.0, -front - 0.005), Vector3(0.042, 0.62, 0.012), SHIRT_RED)
	b.box(chest + Vector3(0.0, 0.26, front - 0.002), Vector3(0.07, 0.07, 0.012), look.skin)
	b.box(chest + Vector3(0.0, 0.325, 0.01), Vector3(0.18, 0.012, 0.16), SHIRT_RED.darkened(0.2))


## A fluorescent reflective vest over the shirt: two front panels, a back panel,
## straps over the shoulders and silver bands.
static func _add_vest(b: LowPolyBuilder, chest: Vector3) -> void:
	var z := TORSO_SIZE.z / 2.0 + 0.006
	for side: float in [-1.0, 1.0]:
		b.box(chest + Vector3(side * 0.105, -0.03, -z), Vector3(0.15, 0.5, 0.014), VEST)
		b.box(chest + Vector3(side * 0.11, 0.275, 0.0), Vector3(0.13, 0.105, 0.275), VEST)
		for y: float in [0.0, -0.15]:
			b.box(chest + Vector3(side * 0.105, y, -z - 0.004), Vector3(0.15, 0.04, 0.006), SILVER)
	b.box(chest + Vector3(0.0, -0.03, z), Vector3(0.41, 0.5, 0.014), VEST)
	for y: float in [0.0, -0.15]:
		b.box(chest + Vector3(0.0, y, z + 0.004), Vector3(0.41, 0.04, 0.006), SILVER)


## A short-sleeved shirt with big flower blocks in the trim colour and white.
static func _add_floral(b: LowPolyBuilder, look: DriverLook, chest: Vector3, front: float) -> void:
	b.box(chest + Vector3(0.0, 0.25, front), Vector3(0.1, 0.09, 0.01), look.skin)
	for side: float in [-1.0, 1.0]:
		b.box(chest + Vector3(side * 0.075, 0.27, front - 0.002), Vector3(0.06, 0.04, 0.012), look.uniform.lightened(0.3))
	var spots: Array[Vector3] = [Vector3(-0.12, 0.1, 1.0), Vector3(0.11, 0.15, 0.8), Vector3(0.0, -0.06, 1.1),
		Vector3(-0.12, -0.2, 0.9), Vector3(0.12, -0.17, 1.0)]
	for spot: Vector3 in spots:
		var size := 0.085 * spot.z
		for back: bool in [false, true]:
			var z := (TORSO_SIZE.z / 2.0 + 0.003) * (1.0 if back else -1.0)
			var out := 1.0 if back else -1.0
			b.box(chest + Vector3(spot.x, spot.y, z), Vector3(size, size, 0.008), look.trim)
			b.box(chest + Vector3(spot.x, spot.y, z + out * 0.004), Vector3(size * 0.4, size * 0.4, 0.008), Color.WHITE)


## A square wool poncho over the shoulders, hanging over the chest and back, with
## stripes and a hem in the trim colour. The short sleeves still show beneath.
static func _add_ruana(b: LowPolyBuilder, look: DriverLook, chest: Vector3, front: float) -> void:
	var z := TORSO_SIZE.z / 2.0 + 0.012
	for side: float in [-1.0, 1.0]:
		b.box(chest + Vector3(side * 0.15, 0.285, 0.0), Vector3(0.2, 0.04, 0.3), look.uniform)
	for out: float in [-1.0, 1.0]:
		b.box(chest + Vector3(0.0, -0.04, out * z), Vector3(0.46, 0.5, 0.03), look.uniform)
		for y: float in [0.1, 0.0]:
			b.box(chest + Vector3(0.0, y, out * (z + 0.002)), Vector3(0.46, 0.035, 0.034), look.trim)
		b.box(chest + Vector3(0.0, -0.29, out * (z + 0.002)), Vector3(0.46, 0.03, 0.034), look.trim)
	b.box(chest + Vector3(0.0, 0.26, front), Vector3(0.07, 0.07, 0.01), look.skin)


## A thin gold chain with a pendant, over the open collar.
static func _add_gold_chain(b: LowPolyBuilder, chest: Vector3, front: float) -> void:
	var z := front - 0.006
	b.box(chest + Vector3(0.0, 0.3, z), Vector3(0.12, 0.012, 0.008), HeadParts.GOLD)
	for side: float in [-1.0, 1.0]:
		b.box(chest + Vector3(side * 0.055, 0.265, z), Vector3(0.012, 0.07, 0.008), HeadParts.GOLD)
		b.box(chest + Vector3(side * 0.03, 0.215, z), Vector3(0.012, 0.04, 0.008), HeadParts.GOLD)
	b.box(chest + Vector3(0.0, 0.185, z - 0.002), Vector3(0.03, 0.035, 0.012), HeadParts.GOLD)


## Brown wooden beads hanging in a loop on the chest, with a small cross.
static func _add_rosary(b: LowPolyBuilder, chest: Vector3, front: float) -> void:
	var z := front - 0.01
	for i in 9:
		var t := float(i) / 8.0
		var x := lerpf(-0.07, 0.07, t)
		var y := 0.3 - 0.13 * sin(t * PI)
		b.box(chest + Vector3(x, y, z), Vector3(0.022, 0.022, 0.02), BEAD_BROWN)
	b.box(chest + Vector3(0.0, 0.14, z), Vector3(0.012, 0.07, 0.014), BEAD_BROWN.lightened(0.2))
	b.box(chest + Vector3(0.0, 0.135, z), Vector3(0.045, 0.012, 0.014), BEAD_BROWN.lightened(0.2))


## A red neckerchief knotted at the front.
static func _add_neckerchief(b: LowPolyBuilder, chest: Vector3, front: float) -> void:
	b.box(chest + Vector3(0.0, 0.32, 0.0), Vector3(0.14, 0.05, 0.14), NECKERCHIEF)
	b.box(chest + Vector3(0.0, 0.29, front - 0.002), Vector3(0.13, 0.04, 0.012), NECKERCHIEF)
	b.box(chest + Vector3(0.0, 0.255, front - 0.004), Vector3(0.07, 0.05, 0.012), NECKERCHIEF)
	b.box(chest + Vector3(0.0, 0.225, front - 0.006), Vector3(0.03, 0.04, 0.012), NECKERCHIEF.darkened(0.15))
	b.box(chest + Vector3(0.0, 0.29, front - 0.01), Vector3(0.035, 0.035, 0.014), NECKERCHIEF.darkened(0.15))


## A leather shoulder bag: a strap from the left shoulder across the chest and back
## to the hip, with the bag hanging at the right hip.
static func _add_carriel(b: LowPolyBuilder, chest: Vector3, front: float) -> void:
	for step in 7:
		var t := float(step) / 6.0
		var x := lerpf(-0.14, 0.12, t)
		var y := lerpf(0.27, -0.12, t)
		b.box(chest + Vector3(x, y, front - 0.001), Vector3(0.05, 0.09, 0.01), LEATHER_DARK)
		b.box(chest + Vector3(x, y, -front + 0.001), Vector3(0.05, 0.09, 0.01), LEATHER_DARK)
	var bag := chest + Vector3(0.11, -0.2, front - 0.04)
	b.box(bag, Vector3(0.15, 0.16, 0.07), LEATHER)
	b.box(bag + Vector3(0.0, 0.06, -0.003), Vector3(0.155, 0.06, 0.076), LEATHER_DARK)
	b.box(bag + Vector3(0.0, 0.03, -0.04), Vector3(0.025, 0.03, 0.008), HeadParts.GOLD)


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
	if look.eyewear != "":
		HeadParts.add_eyewear(b, head, look.eyewear)
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
	var shirt := SHIRT_RED if look.outfit == "rojiblanca" else look.uniform
	b.box(Vector3(0.0, 0.0, -SHORT_SLEEVE / 2.0), Vector3(0.11, 0.11, SHORT_SLEEVE), shirt)
	b.box(Vector3(0.0, 0.0, -0.5 - SHORT_SLEEVE / 2.0), Vector3(0.085, 0.085, 1.0 - SHORT_SLEEVE), look.skin)
	return b.build(LowPolyBuilder.vertex_colour_material())


static func build_hand(look: DriverLook) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	if look.hands == "gloves":
		# Black racing gloves with an orange stripe and a cuff at the wrist.
		b.box(Vector3.ZERO, Vector3(0.1, 0.08, 0.13), GLOVE)
		b.box(Vector3(0.0, 0.0, 0.02), Vector3(0.104, 0.084, 0.025), GLOVE_STRIPE)
		b.box(Vector3(0.0, 0.0, 0.09), Vector3(0.108, 0.09, 0.05), GLOVE)
		b.box(Vector3(0.0, 0.0, 0.11), Vector3(0.112, 0.094, 0.012), GLOVE_STRIPE)
		return b.build(LowPolyBuilder.vertex_colour_material())
	b.box(Vector3.ZERO, Vector3(0.1, 0.08, 0.13), look.skin)
	return b.build(LowPolyBuilder.vertex_colour_material())
