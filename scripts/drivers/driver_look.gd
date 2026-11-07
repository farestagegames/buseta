class_name DriverLook
extends RefCounted
## How one driver looks, read from the catalog. Pure data, so one look can build
## the 3D figure, the hands in the cockpit and the portraits in the menus.

const HAIR_STYLES: Array[String] = HeadParts.HAIR_STYLES
const BEARDS: Array[String] = HeadParts.BEARDS
## Hats a driver can wear at the wheel. A headwrap covers the hair.
const HATS: Array[String] = ["", "cap", "vueltiao", "headwrap"]
## A short-sleeved polo shirt, or a guayabera with its pleats and pockets. Buseta
## drivers on the coast drive in their own shirts, not a jacket and tie.
const OUTFITS: Array[String] = ["polo", "guayabera"]

var driver_name: String = "Driver"
var skin := Color(0.62, 0.44, 0.31)
var hair := Color(0.08, 0.06, 0.05)
var hair_style: String = "short"
var uniform := Color(0.15, 0.2, 0.35) ## The shirt, whatever the outfit.
var trim := Color(0.85, 0.7, 0.2)
var accent := Color(0.85, 0.7, 0.2) ## A cap, a headwrap or the beads on braids.
var beard: String = ""
var hat: String = ""
var outfit: String = "polo"
var glasses: bool = false
var greying: bool = false
var earrings: bool = false
var towel: bool = false ## A small towel over the shoulder, as many buseta drivers keep.


## Reads a catalog entry. Anything missing or unknown keeps its default.
static func from_item(item: Dictionary) -> DriverLook:
	var look := DriverLook.new()
	look.driver_name = str(item.get("name", look.driver_name))
	look.skin = _colour(item.get("skin"), look.skin)
	look.hair = _colour(item.get("hair"), look.hair)
	look.uniform = _colour(item.get("uniform"), look.uniform)
	look.trim = _colour(item.get("trim"), look.trim)
	look.accent = _colour(item.get("accent"), look.trim)
	look.hair_style = _choice(item.get("hair_style"), HAIR_STYLES, look.hair_style)
	look.beard = _choice(item.get("beard"), BEARDS, look.beard)
	# Older entries said "cap": true before there were other hats.
	look.hat = _choice(item.get("hat"), HATS, "cap" if _flag(item.get("cap")) else look.hat)
	look.outfit = _choice(item.get("outfit"), OUTFITS, look.outfit)
	look.glasses = _flag(item.get("glasses"))
	look.greying = _flag(item.get("greying"))
	look.earrings = _flag(item.get("earrings"))
	look.towel = _flag(item.get("towel"))
	return look


## Everything wrong with a catalog entry's looks, or nothing. Unlike from_item, which
## quietly keeps defaults, this names a misspelt style or a bad colour.
static func check(item: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var title := "Driver %s" % str(item.get("id", "?"))
	var choices := {"hair_style": HAIR_STYLES, "beard": BEARDS, "hat": HATS, "outfit": OUTFITS}
	for key: String in choices:
		if item.has(key) and not (item[key] is String and (choices[key] as Array).has(item[key])):
			problems.append("%s has an unknown %s: %s" % [title, key, str(item[key])])
	for key: String in ["skin", "hair", "uniform", "trim", "accent"]:
		if item.has(key) and not PassengerLook.is_colour(item[key]):
			problems.append("%s has a bad %s colour" % [title, key])
	for key: String in ["glasses", "greying", "earrings", "towel", "cap"]:
		if item.has(key) and not item[key] is bool:
			problems.append("%s needs true or false for %s" % [title, key])
	return problems


## A moustache or beard greys along with the hair.
func beard_colour() -> Color:
	return hair.lerp(HeadParts.GREY, 0.45) if greying else hair


func temple_colour() -> Color:
	return hair.lerp(HeadParts.GREY, 0.8)


## The cloth of a cap or a headwrap.
func hat_colour() -> Color:
	return accent


## Only a real true counts, as comparing other types with a bool is an error.
static func _flag(value: Variant) -> bool:
	return value is bool and value


static func _choice(value: Variant, allowed: Array[String], fallback: String) -> String:
	return value if value is String and allowed.has(value) else fallback


static func _colour(value: Variant, fallback: Color) -> Color:
	if not value is Array or (value as Array).size() < 3:
		return fallback
	for i in 3:
		if not (value[i] is float or value[i] is int):
			return fallback
	return Color(float(value[0]), float(value[1]), float(value[2]))
