class_name PassengerLook
extends RefCounted
## One person in the crowd, as described in a pack's passengers file. Pure data
## with safe defaults, so a damaged entry still gives a whole person.

const TOP_STYLES: Array[String] = ["shirt", "guayabera", "scrubs", "vest", "apron", "pinafore", "dress"]
const SLEEVES: Array[String] = ["long", "short", "none"]
const LOWER_STYLES: Array[String] = ["trousers", "shorts", "skirt", "long_skirt"]
const CARRIES: Array[String] = [
	"", "backpack", "mochila", "basket", "handbag", "briefcase", "baby", "bucket", "books", "cool_box",
]
const SIZES := Vector2(0.5, 1.15)
const PACES := Vector2(0.5, 1.3)
## Anyone smaller than this is a child, and anyone slower an older person.
const CHILD_SIZE := 0.8
const OLDER_PACE := 0.85

var id: String = "passenger"
var size: float = 1.0 ## Height compared with an adult, so children are smaller.
var pace: float = 1.0 ## Walking speed compared with an adult, so older people are slower.
var skin := Color(0.62, 0.44, 0.31)
var hair := Color(0.08, 0.06, 0.05)
var hair_style: String = "short"
var beard: String = ""
var top := Color(0.2, 0.4, 0.75)
var top_style: String = "shirt"
var sleeves: String = "short"
var trim := Color(0.15, 0.3, 0.55) ## An outfit's second colour: a vest, apron, pleats, a hem or a hat band.
var lower := Color(0.16, 0.2, 0.32)
var lower_style: String = "trousers"
var socks := Color(0.62, 0.44, 0.31) ## Bare legs show skin unless socks are set.
var shoes := Color(0.08, 0.08, 0.09)
var hat: String = ""
var hat_colour := Color(0.85, 0.2, 0.2)
var carry: String = ""
var carry_colour := Color(0.2, 0.2, 0.22)
var stripes: Array[Color] = [] ## Bands woven into a mochila, at most PassengerFigure.MAX_STRIPES.
var glasses: bool = false
var earrings: bool = false
var cane: bool = false


## Reads one entry. Anything missing, unknown or of the wrong type keeps its default.
static func from_data(entry: Variant) -> PassengerLook:
	var look := PassengerLook.new()
	if not entry is Dictionary:
		return look
	var data: Dictionary = entry
	if data.get("id") is String:
		look.id = data["id"]
	look.size = _number(data.get("size"), look.size, SIZES)
	look.pace = _number(data.get("pace"), look.pace, PACES)
	look.skin = _colour(data.get("skin"), look.skin)
	look.hair = _colour(data.get("hair"), look.hair)
	look.hair_style = _choice(data.get("hair_style"), HeadParts.HAIR_STYLES, look.hair_style)
	look.beard = _choice(data.get("beard"), HeadParts.BEARDS, look.beard)
	look.top = _colour(data.get("top"), look.top)
	look.top_style = _choice(data.get("top_style"), TOP_STYLES, look.top_style)
	look.sleeves = _choice(data.get("sleeves"), SLEEVES, look.sleeves)
	look.trim = _colour(data.get("trim"), look.top.darkened(0.2))
	look.lower = _colour(data.get("lower"), look.lower)
	look.lower_style = _choice(data.get("lower_style"), LOWER_STYLES, look.lower_style)
	look.socks = _colour(data.get("socks"), look.skin)
	look.shoes = _colour(data.get("shoes"), look.shoes)
	look.hat = _choice(data.get("hat"), HeadParts.HATS, look.hat)
	look.hat_colour = _colour(data.get("hat_colour"), look.hat_colour)
	look.carry = _choice(data.get("carry"), CARRIES, look.carry)
	look.carry_colour = _colour(data.get("carry_colour"), look.carry_colour)
	var bands: Variant = data.get("stripes")
	if bands is Array:
		for band: Variant in bands:
			if is_colour(band) and look.stripes.size() < PassengerFigure.MAX_STRIPES:
				look.stripes.append(_colour(band, look.carry_colour))
	look.glasses = _flag(data.get("glasses"))
	look.earrings = _flag(data.get("earrings"))
	look.cane = _flag(data.get("cane"))
	return look


func is_child() -> bool:
	return size < CHILD_SIZE


func is_older() -> bool:
	return pace < OLDER_PACE


## What shows on top of the head from a distance: the hat if there is one.
func crown_colour() -> Color:
	match hat:
		"":
			return hair
		"vueltiao":
			return HeadParts.STRAW
	return hat_colour


## Three numbers from 0 to 1. A colour written as 0 to 255 does not count.
static func is_colour(value: Variant) -> bool:
	if not value is Array or (value as Array).size() < 3:
		return false
	for i in 3:
		if not (value[i] is float or value[i] is int) or float(value[i]) < 0.0 or float(value[i]) > 1.0:
			return false
	return true


static func _colour(value: Variant, fallback: Color) -> Color:
	return Color(float(value[0]), float(value[1]), float(value[2])) if is_colour(value) else fallback


## Only a real true counts, as comparing other types with a bool is an error.
static func _flag(value: Variant) -> bool:
	return value is bool and value


static func _choice(value: Variant, allowed: Array[String], fallback: String) -> String:
	return value if value is String and allowed.has(value) else fallback


static func _number(value: Variant, fallback: float, limits: Vector2) -> float:
	if not (value is float or value is int):
		return fallback
	return clampf(float(value), limits.x, limits.y)
