class_name HeadParts
extends RefCounted
## Faces, hair and hats for the low-poly people, shared by drivers and passengers,
## so a style looks the same on both. Every part is placed from the centre of the
## head, and faces look along -Z.

const SIZE := Vector3(0.21, 0.26, 0.23)
## The front of the face, as a z offset from the centre of the head.
const FACE := -0.118
const HAIR_STYLES: Array[String] = [
	"bald", "short", "fade", "bob", "bun", "ponytail", "plait", "plaits", "afro", "curly", "long", "braids", "hijab",
]
const HATS: Array[String] = ["", "cap", "vueltiao", "headwrap", "hard_hat", "sun_hat"]
const BEARDS: Array[String] = ["", "moustache", "thin_moustache", "goatee", "full"]

const DARK := Color(0.06, 0.06, 0.08)
const GOLD := Color(0.95, 0.75, 0.25)
const LENS := Color(0.75, 0.82, 0.9)
const GREY := Color(0.8, 0.8, 0.79)
## A sombrero vueltiao is woven from pale cane with black bands.
const STRAW := Color(0.93, 0.88, 0.72)
const STRAW_BLACK := Color(0.1, 0.08, 0.07)


## The head and its eyes.
static func add_face(b: LowPolyBuilder, head: Vector3, skin: Color) -> void:
	b.box(head, SIZE, skin)
	for side: float in [-0.055, 0.055]:
		b.box(head + Vector3(side, 0.03, FACE - 0.002), Vector3(0.035, 0.03, 0.01), DARK)


## beads colours the tips of braids and the ties of a ponytail or plaits, and a
## fade blends from the hair into skin at the sides.
static func add_hair(b: LowPolyBuilder, head: Vector3, style: String, colour: Color, beads: Color, skin := Color(0.5, 0.35, 0.25)) -> void:
	var top := head + Vector3(0.0, 0.145, 0.01)
	var back := head + Vector3(0.0, 0.03, 0.115)
	match style:
		"short":
			b.box(top, Vector3(0.23, 0.07, 0.25), colour)
			b.box(back, Vector3(0.23, 0.2, 0.05), colour)
		"fade":
			b.box(head + Vector3(0.0, 0.14, 0.005), Vector3(0.22, 0.05, 0.24), colour)
			var faded := colour.lerp(skin, 0.45)
			for side: float in [-1.0, 1.0]:
				b.box(head + Vector3(side * 0.107, 0.07, 0.02), Vector3(0.008, 0.09, 0.19), faded)
			b.box(head + Vector3(0.0, 0.06, 0.117), Vector3(0.2, 0.11, 0.008), faded)
		"bob":
			b.box(top, Vector3(0.24, 0.08, 0.26), colour)
			b.box(back + Vector3(0.0, -0.03, 0.0), Vector3(0.25, 0.3, 0.06), colour)
			for side: float in [-1.0, 1.0]:
				b.box(head + Vector3(side * 0.125, -0.01, 0.03), Vector3(0.05, 0.3, 0.2), colour)
		"bun":
			b.box(top, Vector3(0.23, 0.07, 0.25), colour)
			b.box(back, Vector3(0.23, 0.2, 0.05), colour)
			b.box(head + Vector3(0.0, 0.2, 0.08), Vector3(0.13, 0.12, 0.13), colour)
		"ponytail":
			b.box(top, Vector3(0.23, 0.07, 0.25), colour)
			b.box(back, Vector3(0.23, 0.2, 0.05), colour)
			b.box(head + Vector3(0.0, -0.07, 0.16), Vector3(0.07, 0.26, 0.06), colour)
			b.box(head + Vector3(0.0, 0.07, 0.15), Vector3(0.08, 0.04, 0.07), beads)
		"plait":
			b.box(top, Vector3(0.23, 0.07, 0.25), colour)
			b.box(back, Vector3(0.23, 0.22, 0.05), colour)
			b.box(head + Vector3(0.0, -0.27, 0.15), Vector3(0.08, 0.42, 0.06), colour)
		"plaits":
			b.box(top, Vector3(0.23, 0.07, 0.25), colour)
			b.box(back, Vector3(0.23, 0.2, 0.05), colour)
			for side: float in [-1.0, 1.0]:
				b.box(head + Vector3(side * 0.118, -0.09, 0.05), Vector3(0.05, 0.28, 0.05), colour)
				b.box(head + Vector3(side * 0.118, -0.24, 0.05), Vector3(0.055, 0.03, 0.055), beads)
		"afro":
			# Rounded by a smaller step on top, and down only as far as the temples.
			b.box(head + Vector3(0.0, 0.15, 0.015), Vector3(0.27, 0.13, 0.27), colour)
			b.box(head + Vector3(0.0, 0.232, 0.025), Vector3(0.21, 0.04, 0.21), colour)
			b.box(head + Vector3(0.0, 0.03, 0.12), Vector3(0.25, 0.2, 0.08), colour)
			for side: float in [-1.0, 1.0]:
				b.box(head + Vector3(side * 0.118, 0.05, 0.03), Vector3(0.03, 0.1, 0.18), colour)
		"curly":
			b.box(head + Vector3(0.0, 0.15, 0.02), Vector3(0.3, 0.13, 0.3), colour)
			b.box(head + Vector3(0.0, -0.02, 0.12), Vector3(0.3, 0.32, 0.1), colour)
			for side: float in [-1.0, 1.0]:
				b.box(head + Vector3(side * 0.135, -0.03, 0.02), Vector3(0.07, 0.28, 0.22), colour)
				b.box(head + Vector3(side * 0.17, 0.08, 0.0), Vector3(0.05, 0.08, 0.1), colour)
			b.box(head + Vector3(-0.08, 0.225, -0.03), Vector3(0.09, 0.05, 0.09), colour)
			b.box(head + Vector3(0.07, 0.23, 0.05), Vector3(0.09, 0.05, 0.09), colour)
		"long":
			b.box(top, Vector3(0.235, 0.075, 0.255), colour)
			b.box(head + Vector3(0.0, -0.1, 0.145), Vector3(0.25, 0.5, 0.06), colour)
			for side: float in [-1.0, 1.0]:
				b.box(head + Vector3(side * 0.123, -0.06, 0.02), Vector3(0.04, 0.38, 0.19), colour)
		"braids":
			_add_braids(b, head, colour, beads)
		"hijab":
			b.box(head + Vector3(0.0, 0.14, 0.01), Vector3(0.26, 0.05, 0.27), colour)
			b.box(head + Vector3(0.0, 0.0, 0.125), Vector3(0.26, 0.32, 0.05), colour)
			for side: float in [-1.0, 1.0]:
				b.box(head + Vector3(side * 0.12, 0.0, 0.01), Vector3(0.035, 0.32, 0.24), colour)
			b.box(head + Vector3(0.0, -0.17, 0.0), Vector3(0.28, 0.13, 0.27), colour)


## Rows braided close along the top, then braids to the shoulders with beaded tips.
static func _add_braids(b: LowPolyBuilder, head: Vector3, colour: Color, beads: Color) -> void:
	b.box(head + Vector3(0.0, 0.145, 0.01), Vector3(0.23, 0.065, 0.25), colour)
	b.box(head + Vector3(0.0, 0.03, 0.115), Vector3(0.23, 0.2, 0.05), colour)
	for x: float in [-0.075, -0.025, 0.025, 0.075]:
		b.box(head + Vector3(x, 0.18, 0.01), Vector3(0.014, 0.01, 0.25), colour.lightened(0.2))
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.02, 0.05]:
			b.box(head + Vector3(side * 0.122, -0.01, z), Vector3(0.035, 0.28, 0.035), colour)
			b.box(head + Vector3(side * 0.122, -0.165, z), Vector3(0.045, 0.04, 0.045), beads)
	for x: float in [-0.07, 0.0, 0.07]:
		b.box(head + Vector3(x, -0.1, 0.145), Vector3(0.035, 0.44, 0.035), colour)
		b.box(head + Vector3(x, -0.335, 0.145), Vector3(0.045, 0.04, 0.045), beads)


## Grey at the temples, where hair greys first.
static func add_temples(b: LowPolyBuilder, head: Vector3, grey: Color) -> void:
	for side: float in [-1.0, 1.0]:
		b.box(head + Vector3(side * 0.108, 0.05, 0.03), Vector3(0.012, 0.07, 0.1), grey)


static func add_beard(b: LowPolyBuilder, head: Vector3, style: String, colour: Color) -> void:
	match style:
		"moustache":
			b.box(head + Vector3(0.0, -0.045, FACE), Vector3(0.12, 0.03, 0.012), colour)
		"thin_moustache":
			b.box(head + Vector3(0.0, -0.043, FACE), Vector3(0.1, 0.013, 0.012), colour)
		"goatee":
			# A narrow strip on the chin, with skin between it and the moustache.
			b.box(head + Vector3(0.0, -0.043, FACE), Vector3(0.1, 0.013, 0.012), colour)
			b.box(head + Vector3(0.0, -0.112, FACE), Vector3(0.045, 0.035, 0.012), colour)
		"full":
			b.box(head + Vector3(0.0, -0.08, FACE + 0.002), Vector3(0.215, 0.11, 0.016), colour)
			b.box(head + Vector3(0.0, -0.13, 0.0), Vector3(0.215, 0.05, 0.23), colour)


static func add_glasses(b: LowPolyBuilder, head: Vector3) -> void:
	for side: float in [-0.055, 0.055]:
		b.box(head + Vector3(side, 0.03, FACE - 0.006), Vector3(0.075, 0.055, 0.004), LENS)
	b.box(head + Vector3(0.0, 0.04, FACE - 0.008), Vector3(0.05, 0.012, 0.006), DARK)


static func add_earrings(b: LowPolyBuilder, head: Vector3) -> void:
	for side: float in [-1.0, 1.0]:
		b.box(head + Vector3(side * 0.11, -0.045, 0.0), Vector3(0.018, 0.045, 0.018), GOLD)


## colour is the cloth, shell or crown, and band is a second colour: a hat band or
## a headwrap's second fabric. A vueltiao always has its own cane colours.
static func add_hat(b: LowPolyBuilder, head: Vector3, hat: String, colour: Color, band: Color) -> void:
	match hat:
		"cap":
			# A baseball cap, with its peak sticking out in front.
			b.box(head + Vector3(0.0, 0.15, 0.01), Vector3(0.25, 0.08, 0.27), colour)
			b.box(head + Vector3(0.0, 0.2, 0.015), Vector3(0.2, 0.025, 0.22), colour)
			b.box(head + Vector3(0.0, 0.218, 0.015), Vector3(0.03, 0.012, 0.03), colour.darkened(0.3))
			b.box(head + Vector3(0.0, 0.118, -0.18), Vector3(0.21, 0.018, 0.12), colour.darkened(0.2))
		"vueltiao":
			_add_vueltiao(b, head)
		"headwrap":
			# A turbante: snug over the forehead, rising up and back in a rounded
			# crown, with a fold of the second fabric and a knot at one side.
			b.box(head + Vector3(0.0, 0.12, 0.015), Vector3(0.25, 0.09, 0.27), colour)
			b.box(head + Vector3(0.0, 0.02, 0.12), Vector3(0.24, 0.17, 0.06), colour)
			b.box(head + Vector3(0.0, 0.185, 0.06), Vector3(0.29, 0.08, 0.26), colour.lightened(0.06))
			b.box(head + Vector3(0.0, 0.24, 0.08), Vector3(0.22, 0.04, 0.2), colour)
			b.box(head + Vector3(0.0, 0.16, 0.16), Vector3(0.24, 0.13, 0.08), colour)
			for step in 2:
				b.box(head + Vector3(-0.07 + float(step) * 0.04, 0.13 + float(step) * 0.02, -0.123), Vector3(0.05, 0.02, 0.006), band)
				b.box(head + Vector3(-0.01 + float(step) * 0.04, 0.19 + float(step) * 0.02, -0.073), Vector3(0.05, 0.02, 0.006), band)
			b.box(head + Vector3(0.085, 0.16, -0.125), Vector3(0.07, 0.065, 0.04), band)
			b.box(head + Vector3(0.1, 0.2, -0.11), Vector3(0.045, 0.04, 0.035), colour.lightened(0.12))
		"hard_hat":
			b.box(head + Vector3(0.0, 0.17, 0.01), Vector3(0.26, 0.12, 0.28), colour)
			b.box(head + Vector3(0.0, 0.115, 0.0), Vector3(0.3, 0.02, 0.33), colour)
			b.box(head + Vector3(0.0, 0.235, 0.01), Vector3(0.05, 0.025, 0.28), colour.lightened(0.15))
		"sun_hat":
			b.box(head + Vector3(0.0, 0.125, 0.01), Vector3(0.4, 0.02, 0.4), colour)
			b.box(head + Vector3(0.0, 0.18, 0.01), Vector3(0.24, 0.1, 0.26), colour)
			b.box(head + Vector3(0.0, 0.15, 0.01), Vector3(0.245, 0.025, 0.265), band)


## Eight-sided, as the brim and crown are round: a wide brim with woven rings and
## a crown with black bands.
static func _add_vueltiao(b: LowPolyBuilder, head: Vector3) -> void:
	var centre := head + Vector3(0.0, 0.0, 0.01)
	_add_octagon(b, centre + Vector3(0.0, 0.125, 0.0), 0.5, 0.02, STRAW)
	_add_ring(b, centre + Vector3(0.0, 0.1365, 0.0), 0.44, 0.025, STRAW_BLACK)
	_add_ring(b, centre + Vector3(0.0, 0.1365, 0.0), 0.34, 0.018, STRAW_BLACK)
	_add_octagon(b, centre + Vector3(0.0, 0.19, 0.0), 0.26, 0.11, STRAW)
	for y: float in [0.165, 0.215]:
		_add_octagon(b, centre + Vector3(0.0, y, 0.0), 0.265, 0.018, STRAW_BLACK)
	_add_octagon(b, centre + Vector3(0.0, 0.252, 0.0), 0.22, 0.015, STRAW)


## A flat eight-sided slab, width across its flats: two boxes, one turned 45 degrees.
static func _add_octagon(b: LowPolyBuilder, centre: Vector3, width: float, height: float, colour: Color) -> void:
	var size := Vector3(width, height, width)
	b.box(centre, size, colour)
	b.turned_box(centre, size, PI / 4.0, colour)


## An eight-sided outline lying flat, such as a band woven into a brim.
static func _add_ring(b: LowPolyBuilder, centre: Vector3, width: float, line: float, colour: Color) -> void:
	var corner := 1.0 / cos(PI / 8.0)
	for i in 8:
		var from := PI / 8.0 + float(i) * PI / 4.0
		var to := from + PI / 4.0
		var out_a := Vector3(cos(from), 0.0, sin(from)) * corner
		var out_b := Vector3(cos(to), 0.0, sin(to)) * corner
		var outer := width / 2.0 + line / 2.0
		var inner := width / 2.0 - line / 2.0
		b.quad(centre + out_a * outer, centre + out_a * inner, centre + out_b * inner, centre + out_b * outer, colour)
