class_name PassengerFigure
extends RefCounted
## Builds a passenger from a PassengerLook: one body mesh with the head, clothes and
## anything carried, and one arm and one leg that both sides share. Feet stand on
## the origin and faces look along -Z. Limbs hang from HIP and SHOULDER, mirrored.

const HIP := Vector3(0.1, 0.86, 0.0)
const SHOULDER := Vector3(0.27, 1.46, 0.0)
const HEAD := Vector3(0.0, 1.73, 0.0)
const FRONT := -0.12 ## The front of the chest.
const BACK := 0.12
## In front of the shoulder yoke, so a collar or neckline is not hidden inside it.
const NECK := -0.13
## A long skirt is one panel to the ankles, and only the feet step out under it.
const SKIRT_SWING := 0.3
## A mochila has room for this many woven bands.
const MAX_STRIPES := 5

const SILVER := Color(0.82, 0.84, 0.86)
const CANE := Color(0.32, 0.2, 0.12)
const WHITE := Color(0.95, 0.95, 0.93)
const PAGES := Color(0.93, 0.91, 0.84)
const PRODUCE: Array[Color] = [Color(0.35, 0.65, 0.2), Color(0.98, 0.72, 0.15), Color(0.85, 0.2, 0.15)]


static func build_body(look: PassengerLook, material: Material) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	b.box(Vector3(0.0, 1.26, 0.0), Vector3(0.42, 0.56, 0.23), look.top)
	b.box(Vector3(0.0, 1.5, 0.0), Vector3(0.47, 0.1, 0.25), look.top)
	# The waist sits just inside the shirt, so the two never fight over one face.
	b.box(Vector3(0.0, 0.925, 0.0), Vector3(0.38, 0.17, 0.22), look.lower)
	b.box(Vector3(0.0, 1.58, 0.0), Vector3(0.1, 0.1, 0.1), look.skin)
	_add_top(b, look)
	match look.lower_style:
		"skirt":
			b.box(Vector3(0.0, 0.78, 0.0), Vector3(0.42, 0.38, 0.28), look.lower)
		"long_skirt":
			b.box(Vector3(0.0, 0.53, 0.0), Vector3(0.44, 0.82, 0.3), look.lower)
			b.box(Vector3(0.0, 0.15, 0.0), Vector3(0.445, 0.06, 0.305), look.trim)
	_add_head(b, look)
	_add_carry(b, look)
	if look.cane:
		b.box(Vector3(-0.36, 0.5, -0.1), Vector3(0.04, 1.0, 0.04), CANE)
	return b.build(material)


static func _add_head(b: LowPolyBuilder, look: PassengerLook) -> void:
	HeadParts.add_face(b, HEAD, look.skin)
	# A headwrap covers the hair completely.
	if look.hat != "headwrap":
		HeadParts.add_hair(b, HEAD, look.hair_style, look.hair, HeadParts.GOLD, look.skin)
	HeadParts.add_beard(b, HEAD, look.beard, look.hair)
	if look.earrings:
		HeadParts.add_earrings(b, HEAD)
	if look.glasses:
		HeadParts.add_glasses(b, HEAD)
	HeadParts.add_hat(b, HEAD, look.hat, look.hat_colour, look.trim)


static func _add_top(b: LowPolyBuilder, look: PassengerLook) -> void:
	match look.top_style:
		"guayabera":
			b.box(Vector3(0.0, 1.49, NECK), Vector3(0.08, 0.07, 0.008), look.skin)
			for side: float in [-1.0, 1.0]:
				for x: float in [0.06, 0.16]:
					b.box(Vector3(side * x, 1.24, FRONT - 0.002), Vector3(0.014, 0.46, 0.008), look.trim)
				b.box(Vector3(side * 0.11, 1.34, FRONT - 0.003), Vector3(0.07, 0.07, 0.008), look.trim)
				b.box(Vector3(side * 0.11, 1.09, FRONT - 0.003), Vector3(0.08, 0.08, 0.008), look.trim)
		"scrubs":
			b.box(Vector3(0.0, 1.48, NECK), Vector3(0.1, 0.08, 0.008), look.skin)
			b.box(Vector3(-0.1, 1.35, FRONT - 0.002), Vector3(0.09, 0.07, 0.008), look.trim)
		"vest":
			for z: float in [FRONT - 0.005, BACK + 0.005]:
				b.box(Vector3(0.0, 1.24, z), Vector3(0.44, 0.48, 0.02), look.trim)
				for y: float in [1.12, 1.3]:
					b.box(Vector3(0.0, y, z + signf(z) * 0.011), Vector3(0.44, 0.035, 0.006), SILVER)
		"apron":
			b.box(Vector3(0.0, 1.04, FRONT - 0.005), Vector3(0.36, 0.66, 0.02), look.trim)
			b.box(Vector3(0.0, 0.94, FRONT - 0.016), Vector3(0.22, 0.1, 0.006), look.trim.darkened(0.2))
		"pinafore":
			b.box(Vector3(0.0, 1.22, FRONT - 0.005), Vector3(0.3, 0.32, 0.02), look.trim)
			for side: float in [-1.0, 1.0]:
				b.box(Vector3(side * 0.12, 1.5, 0.0), Vector3(0.07, 0.11, 0.27), look.trim)
		"dress":
			b.box(Vector3(0.0, 1.47, NECK), Vector3(0.22, 0.05, 0.008), look.trim)


## Things carried in the hand sit on the left (-x), away from the right arm that
## pays and waves. Faces look along -Z, so +x is the person's right.
static func _add_carry(b: LowPolyBuilder, look: PassengerLook) -> void:
	var colour := look.carry_colour
	match look.carry:
		"backpack":
			b.box(Vector3(0.0, 1.27, 0.18), Vector3(0.32, 0.42, 0.13), colour)
			b.box(Vector3(0.0, 1.42, 0.25), Vector3(0.3, 0.1, 0.02), colour.darkened(0.25))
			for side: float in [-1.0, 1.0]:
				b.box(Vector3(side * 0.12, 1.36, FRONT - 0.004), Vector3(0.04, 0.26, 0.01), colour.darkened(0.25))
		"mochila":
			# A squat round bag: a narrower base and top round off its corners.
			b.box(Vector3(-0.36, 1.0, 0.0), Vector3(0.11, 0.22, 0.28), colour)
			b.box(Vector3(-0.36, 0.875, 0.0), Vector3(0.1, 0.03, 0.22), colour)
			var count := mini(look.stripes.size(), MAX_STRIPES)
			for i in count:
				var y := 0.91 + (float(i) + 0.5) * 0.18 / float(count)
				b.box(Vector3(-0.36, y, 0.0), Vector3(0.114, 0.022, 0.284), look.stripes[i])
			b.box(Vector3(-0.36, 1.125, 0.0), Vector3(0.1, 0.03, 0.24), colour.darkened(0.45))
			for z: float in [-0.08, 0.08]:
				b.box(Vector3(-0.36, 1.15, z), Vector3(0.012, 0.03, 0.012), colour.darkened(0.45))
			for z: float in [FRONT - 0.004, BACK + 0.004]:
				b.box(Vector3(-0.2, 1.36, z), Vector3(0.035, 0.36, 0.012), colour)
		"basket":
			b.box(Vector3(-0.38, 0.92, 0.0), Vector3(0.26, 0.2, 0.34), colour)
			for y: float in [0.87, 0.95]:
				b.box(Vector3(-0.38, y, 0.0), Vector3(0.265, 0.025, 0.345), colour.darkened(0.25))
			for i in PRODUCE.size():
				b.box(Vector3(-0.34 - float(i % 2) * 0.08, 1.05, -0.09 + float(i) * 0.09), Vector3(0.09, 0.08, 0.09), PRODUCE[i])
			for z: float in [-0.15, 0.15]:
				b.box(Vector3(-0.38, 1.1, z), Vector3(0.02, 0.18, 0.02), colour.darkened(0.25))
			b.box(Vector3(-0.38, 1.19, 0.0), Vector3(0.02, 0.02, 0.32), colour.darkened(0.25))
		"handbag":
			b.box(Vector3(-0.34, 1.05, 0.0), Vector3(0.08, 0.16, 0.22), colour)
			b.box(Vector3(-0.34, 1.17, 0.0), Vector3(0.02, 0.08, 0.12), colour.darkened(0.3))
		"briefcase":
			b.box(Vector3(-0.34, 0.86, 0.0), Vector3(0.08, 0.28, 0.38), colour)
			b.box(Vector3(-0.34, 1.02, 0.0), Vector3(0.02, 0.04, 0.12), colour.darkened(0.3))
		"baby":
			b.box(Vector3(0.0, 1.2, FRONT - 0.07), Vector3(0.3, 0.28, 0.14), colour)
			b.box(Vector3(0.0, 1.39, FRONT - 0.08), Vector3(0.13, 0.13, 0.13), look.skin)
			b.box(Vector3(0.0, 1.45, FRONT - 0.075), Vector3(0.135, 0.04, 0.135), look.hair)
			b.box(Vector3(0.15, 1.42, FRONT - 0.01), Vector3(0.05, 0.22, 0.02), colour)
		"bucket":
			b.box(Vector3(-0.38, 0.88, 0.0), Vector3(0.22, 0.24, 0.22), colour)
			b.box(Vector3(-0.38, 1.0, 0.0), Vector3(0.24, 0.03, 0.24), colour.darkened(0.2))
			b.box(Vector3(-0.38, 1.08, 0.0), Vector3(0.02, 0.02, 0.2), colour.darkened(0.3))
		"books":
			b.box(Vector3(-0.35, 1.0, 0.0), Vector3(0.07, 0.28, 0.22), colour)
			b.box(Vector3(-0.35, 1.0, -0.112), Vector3(0.06, 0.26, 0.005), PAGES)
		"cool_box":
			b.box(Vector3(-0.36, 1.0, 0.0), Vector3(0.22, 0.34, 0.5), colour)
			b.box(Vector3(-0.36, 1.2, 0.0), Vector3(0.24, 0.06, 0.52), WHITE)


## Hangs from SHOULDER: a sleeve as long as the look's, then skin, then the hand.
static func build_arm(look: PassengerLook, material: Material) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	match look.sleeves:
		"long":
			b.box(Vector3(0.0, -0.22, 0.0), Vector3(0.1, 0.46, 0.11), look.top)
		"short":
			b.box(Vector3(0.0, -0.09, 0.0), Vector3(0.11, 0.2, 0.12), look.top)
			b.box(Vector3(0.0, -0.31, 0.0), Vector3(0.085, 0.26, 0.095), look.skin)
		_:
			b.box(Vector3(0.0, -0.22, 0.0), Vector3(0.085, 0.46, 0.095), look.skin)
	b.box(Vector3(0.0, -0.5, 0.0), Vector3(0.09, 0.12, 0.1), look.skin)
	return b.build(material)


## Hangs from HIP, down to the shoe. Under a long skirt only the shoe shows.
static func build_leg(look: PassengerLook, material: Material) -> ArrayMesh:
	var b := LowPolyBuilder.new()
	match look.lower_style:
		"shorts":
			b.box(Vector3(0.0, -0.17, 0.0), Vector3(0.165, 0.32, 0.185), look.lower)
			b.box(Vector3(0.0, -0.55, 0.0), Vector3(0.13, 0.44, 0.15), look.skin)
			_add_socks(b, look)
		"skirt":
			b.box(Vector3(0.0, -0.39, 0.0), Vector3(0.13, 0.74, 0.15), look.skin)
			_add_socks(b, look)
		"long_skirt":
			pass
		_:
			b.box(Vector3(0.0, -0.39, 0.0), Vector3(0.16, 0.74, 0.18), look.lower)
	b.box(Vector3(0.0, -0.8, -0.03), Vector3(0.16, 0.1, 0.26), look.shoes)
	return b.build(material)


## Knee socks, as on a school uniform. Without them the leg stays bare.
static func _add_socks(b: LowPolyBuilder, look: PassengerLook) -> void:
	if look.socks != look.skin:
		b.box(Vector3(0.0, -0.62, 0.0), Vector3(0.135, 0.3, 0.155), look.socks)


static func leg_swing(look: PassengerLook) -> float:
	return SKIRT_SWING if look.lower_style == "long_skirt" else 1.0
