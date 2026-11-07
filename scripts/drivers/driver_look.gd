class_name DriverLook
extends RefCounted
## How one driver looks, read from the catalog. Pure data, so one look can build
## the 3D figure, the hands in the cockpit and the portraits in the menus.

const HAIR_STYLES: Array[String] = ["bald", "short", "bob", "bun", "plait", "afro", "hijab"]
const BEARDS: Array[String] = ["", "moustache", "full"]

var driver_name: String = "Sam Reed"
var skin := Color(0.93, 0.77, 0.65)
var hair := Color(0.3, 0.2, 0.12)
var hair_style: String = "short"
var uniform := Color(0.15, 0.2, 0.35)
var trim := Color(0.85, 0.7, 0.2)
var beard: String = ""
var glasses: bool = false
var cap: bool = false


## Reads a catalog entry. Anything missing or unknown keeps its default.
static func from_item(item: Dictionary) -> DriverLook:
	var look := DriverLook.new()
	look.driver_name = str(item.get("name", look.driver_name))
	look.skin = _colour(item.get("skin"), look.skin)
	look.hair = _colour(item.get("hair"), look.hair)
	look.uniform = _colour(item.get("uniform"), look.uniform)
	look.trim = _colour(item.get("trim"), look.trim)
	var style: Variant = item.get("hair_style")
	if style is String and HAIR_STYLES.has(style):
		look.hair_style = style
	var beard_style: Variant = item.get("beard")
	if beard_style is String and BEARDS.has(beard_style):
		look.beard = beard_style
	look.glasses = item.get("glasses") == true
	look.cap = item.get("cap") == true
	return look


static func _colour(value: Variant, fallback: Color) -> Color:
	if value is Array and (value as Array).size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]))
	return fallback
