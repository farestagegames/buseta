class_name DriverParts
extends RefCounted
## Everything a custom driver can wear, read from the pack's driver_parts.json:
## ordinary parts (free, by level, for coins, or a colour for three stars on a
## route), one special item per route, the slot levels and the name tag rules.
## Pure data and rules, so it can be tested without the game.

## The editor's tabs, in order.
const TABS: Array[String] = ["cara", "pelo", "camisa", "sombrero", "extras"]
## A cloth colour can go on any of these.
const CLOTH_FIELDS: Array[String] = ["uniform", "trim", "accent"]
## Where each special item is worn, and what the look goes back to without it.
const SPECIAL_DEFAULTS := {"hat": "", "outfit": "polo", "eyewear": "", "neck": "", "shoulder": "", "hands": ""}

var data: Dictionary = {}
var _parts := {}
var _specials := {}


func _init(parts_data: Dictionary = {}) -> void:
	data = parts_data
	for entry: Variant in data.get("parts", []):
		if entry is Dictionary and entry.has("id"):
			_parts[str(entry["id"])] = entry
	for item: Variant in data.get("specials", []):
		if item is Dictionary and item.has("id"):
			_specials[str(item["id"])] = item


## The current country's parts, or none if its pack has no custom drivers.
static func for_pack(pack: CountryPack) -> DriverParts:
	var content: Dictionary = pack.data.get("content", {})
	if not content.has("driver_parts"):
		return DriverParts.new()
	return DriverParts.new(MapLoader.read_json(pack.content_path("driver_parts")))


func is_empty() -> bool:
	return _parts.is_empty()


## The level each slot opens at, lowest first. Empty when the pack has none.
func slot_levels() -> Array[int]:
	var levels: Array[int] = []
	for value: Variant in data.get("slot_levels", []):
		if value is float or value is int:
			levels.append(int(value))
	levels.sort()
	return levels


## The level custom drivers open at, or 0 if the pack has none.
func first_slot_level() -> int:
	var levels := slot_levels()
	return levels[0] if not levels.is_empty() else 0


func slots_open(level: int) -> int:
	var open := 0
	for needed: int in slot_levels():
		if level >= needed:
			open += 1
	return open


func name_tag_cost() -> int:
	return int((data.get("name_tag", {}) as Dictionary).get("cost", 500))


## How many name tags levels up to [param level] have given: one at first_level
## and one every few levels after.
func name_tags_by_level(level: int) -> int:
	var rule: Dictionary = data.get("name_tag", {})
	var first := int(rule.get("first_level", 15))
	var every := maxi(int(rule.get("every", 5)), 1)
	return 0 if level < first else (level - first) / every + 1


## The levels that give a name tag above [param before] and up to [param after].
func name_tag_levels_between(before: int, after: int) -> Array[int]:
	var levels: Array[int] = []
	for level in range(before + 1, after + 1):
		if name_tags_by_level(level) > name_tags_by_level(level - 1):
			levels.append(level)
	return levels


func part(id: String) -> Dictionary:
	return _parts.get(id, {})


func parts() -> Array:
	return _parts.values()


## Every ordinary part that sets [param field], in the file's order. Cloth colours
## have the field "cloth".
func parts_for(field: String) -> Array:
	return _parts.values().filter(func(p: Dictionary) -> bool: return p.get("field") == field)


func parts_in_tab(tab: String) -> Array:
	return _parts.values().filter(func(p: Dictionary) -> bool: return p.get("tab") == tab)


func special(id: String) -> Dictionary:
	return _specials.get(id, {})


func specials() -> Array:
	return _specials.values()


func special_for_route(route_id: String) -> Dictionary:
	for item: Dictionary in _specials.values():
		if item.get("route") == route_id:
			return item
	return {}


## The colour three stars on a route gives, or nothing.
func star_part_for_route(route_id: String) -> Dictionary:
	for p: Dictionary in _parts.values():
		if p.get("stars_route") == route_id:
			return p
	return {}


## Free parts are worn by a new driver and need nothing to unlock.
func is_free(p: Dictionary) -> bool:
	return int(p.get("level", 0)) == 0 and int(p.get("cost", 0)) == 0 and str(p.get("stars_route", "")) == ""


## Whether an ordinary part can be worn: free, its level reached, bought, or its
## route finished with three stars.
func is_unlocked(p: Dictionary, level: int, bought: Array, starred: Array) -> bool:
	if p.is_empty():
		return false
	if str(p.get("stars_route", "")) != "":
		return starred.has(p["stars_route"])
	if int(p.get("cost", 0)) > 0:
		return bought.has(p["id"])
	return level >= int(p.get("level", 0))


## How a locked part is got: {"kind": "level"|"cost"|"stars", "value": ...}.
func how_to_get(p: Dictionary) -> Dictionary:
	if str(p.get("stars_route", "")) != "":
		return {"kind": "stars", "value": str(p["stars_route"])}
	if int(p.get("cost", 0)) > 0:
		return {"kind": "cost", "value": int(p["cost"])}
	return {"kind": "level", "value": int(p.get("level", 0))}


## The first free value for each field, so a new driver starts dressed.
func starter_look() -> Dictionary:
	var look := {"outfit": "polo", "hat": "", "beard": ""}
	for p: Dictionary in _parts.values():
		if not is_free(p):
			continue
		var field: String = p["field"]
		if field == "cloth":
			for cloth: String in CLOTH_FIELDS:
				if not look.has(cloth):
					look[cloth] = p["value"]
					break
		elif not look.has(field) and not p["value"] is bool:
			look[field] = p["value"]
	return look


## Problems with the file: unknown fields, styles or routes, bad colours.
func check(route_ids: Array) -> Array[String]:
	var problems: Array[String] = []
	var known := {"hair_style": DriverLook.HAIR_STYLES, "beard": DriverLook.BEARDS, "hat": DriverLook.HATS,
		"outfit": DriverLook.OUTFITS, "eyewear": DriverLook.EYEWEAR, "neck": DriverLook.NECK,
		"shoulder": DriverLook.SHOULDER, "hands": DriverLook.HANDS}
	for p: Dictionary in _parts.values():
		var field := str(p.get("field", ""))
		if not TABS.has(str(p.get("tab", ""))) and p.get("tab") != "colour":
			problems.append("Part %s has an unknown tab" % p["id"])
		if field in ["skin", "hair", "cloth"]:
			if not PassengerLook.is_colour(p.get("value")):
				problems.append("Part %s has a bad colour" % p["id"])
		elif field in ["glasses", "greying", "earrings", "towel"]:
			if not p.get("value") is bool:
				problems.append("Part %s needs true" % p["id"])
		elif known.has(field):
			if not (known[field] as Array).has(p.get("value")):
				problems.append("Part %s has an unknown %s" % [p["id"], field])
		else:
			problems.append("Part %s has an unknown field %s" % [p["id"], field])
		if p.has("stars_route") and not route_ids.has(p["stars_route"]):
			problems.append("Part %s names an unknown route" % p["id"])
	for item: Dictionary in _specials.values():
		var field := str(item.get("field", ""))
		if not SPECIAL_DEFAULTS.has(field) or not (known[field] as Array).has(item.get("value")):
			problems.append("Special %s has an unknown field or value" % item["id"])
		if not route_ids.has(item.get("route")):
			problems.append("Special %s names an unknown route" % item["id"])
	return problems
