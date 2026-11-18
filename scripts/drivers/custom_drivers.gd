class_name CustomDrivers
extends RefCounted
## The player's own drivers and what they have to dress them in. Looks only: a
## custom driver changes nothing about driving, score or XP. Pure logic, saved
## inside the player profile; loading tolerates missing or damaged data.
##
## Each driver is a look in the same shape as a catalog driver entry, plus its
## "name", so DriverLook.from_item reads both. Special items are counted: each
## copy is worn by one driver at a time.

const MAX_NAME := 16
const FIELDS_WITH_SPECIALS: Array[String] = ["hat", "outfit", "eyewear", "neck", "shoulder", "hands"]

## One entry per slot: an empty Dictionary for an empty slot, otherwise a look.
var drivers: Array[Dictionary] = []
## Ordinary parts bought with coins.
var bought: Array[String] = []
## Special item id to copies owned.
var specials: Dictionary = {}
var name_tags: int = 0
## Name tags already given by levels, so each level gives one once.
var level_tags: int = 0
## Routes whose special item has been given, and routes whose three-star colour has.
var paid_routes: Array[String] = []
var paid_stars: Array[String] = []
## The editor has been opened once, which pays out routes finished before it.
var editor_seen: bool = false
## The slot of the custom driver at the wheel, or -1 for a hired driver.
var chosen: int = -1


func driver(slot: int) -> Dictionary:
	return drivers[slot] if slot >= 0 and slot < drivers.size() else {}


func has_driver(slot: int) -> bool:
	return not driver(slot).is_empty()


## The chosen custom driver's look, or nothing when a hired driver drives.
func chosen_driver() -> Dictionary:
	return driver(chosen)


## A slot can be used once its level is reached.
func slot_open(slot: int, parts: DriverParts, level: int) -> bool:
	return slot >= 0 and slot < parts.slots_open(level)


static func clean_name(text: String) -> String:
	return text.strip_edges().left(MAX_NAME).strip_edges()


## Makes a new driver in an open, empty slot, dressed in the free starter look.
## The name is typed once; changing it later needs a name tag.
func create(slot: int, driver_name: String, parts: DriverParts, level: int) -> bool:
	var cleaned := clean_name(driver_name)
	if cleaned == "" or not slot_open(slot, parts, level) or has_driver(slot):
		return false
	while drivers.size() <= slot:
		drivers.append({})
	var look := parts.starter_look()
	look["name"] = cleaned
	drivers[slot] = look
	return true


## Renames a driver, using up a name tag.
func rename(slot: int, driver_name: String) -> bool:
	var cleaned := clean_name(driver_name)
	if cleaned == "" or name_tags <= 0 or not has_driver(slot) or cleaned == drivers[slot]["name"]:
		return false
	name_tags -= 1
	drivers[slot]["name"] = cleaned
	return true


## Puts an unlocked ordinary part on a driver. A cloth colour needs the field it
## goes on: "uniform", "trim" or "accent". A true/false extra switches on and off.
func wear_part(slot: int, part_id: String, parts: DriverParts, level: int, cloth_field: String = "uniform") -> bool:
	var p := parts.part(part_id)
	if not has_driver(slot) or not parts.is_unlocked(p, level, bought, paid_stars):
		return false
	var field: String = p["field"]
	if field == "cloth":
		if not DriverParts.CLOTH_FIELDS.has(cloth_field):
			return false
		field = cloth_field
	if p["value"] is bool:
		drivers[slot][field] = not bool(drivers[slot].get(field, false))
	else:
		drivers[slot][field] = p["value"]
	return true


## Whether the driver has this ordinary part on now.
func wears_part(slot: int, part_id: String, parts: DriverParts, cloth_field: String = "uniform") -> bool:
	var p := parts.part(part_id)
	if not has_driver(slot) or p.is_empty():
		return false
	var field: String = cloth_field if p["field"] == "cloth" else p["field"]
	var value: Variant = drivers[slot].get(field, false if p["value"] is bool else "")
	if p["value"] is Array:
		return value is Array and _same_colour(value, p["value"])
	return value == p["value"]


func copies(special_id: String) -> int:
	return int(specials.get(special_id, 0))


## The slots wearing a special item now.
func wearers(special_id: String, parts: DriverParts) -> Array[int]:
	var item := parts.special(special_id)
	var slots: Array[int] = []
	if item.is_empty():
		return slots
	for slot in drivers.size():
		if has_driver(slot) and drivers[slot].get(item["field"]) == item["value"]:
			slots.append(slot)
	return slots


## Puts a special item on a driver. When every copy is in use, it comes off the
## first other driver wearing one. Returns that driver's slot, -1 if no one lost
## it, or -2 if it could not be worn.
func wear_special(slot: int, special_id: String, parts: DriverParts) -> int:
	var item := parts.special(special_id)
	if item.is_empty() or not has_driver(slot) or copies(special_id) <= 0:
		return -2
	var taken_from := -1
	var others := wearers(special_id, parts).filter(func(s: int) -> bool: return s != slot)
	if not wearers(special_id, parts).has(slot) and others.size() >= copies(special_id):
		taken_from = others[0]
		take_off(taken_from, item["field"])
	drivers[slot][item["field"]] = item["value"]
	return taken_from


## Back to the plain look for that place: no hat, a polo, nothing on the neck.
func take_off(slot: int, field: String) -> void:
	if has_driver(slot) and DriverParts.SPECIAL_DEFAULTS.has(field):
		drivers[slot][field] = DriverParts.SPECIAL_DEFAULTS[field]


func add_special(special_id: String, count: int = 1) -> void:
	specials[special_id] = copies(special_id) + count


## Gives the route's special item and, for three stars, its colour, each once.
## Returns the unlock cards for what was new.
func pay_route(route_id: String, stars: int, parts: DriverParts) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var item := parts.special_for_route(route_id)
	if not item.is_empty() and not paid_routes.has(route_id):
		paid_routes.append(route_id)
		add_special(item["id"])
		cards.append(card("special", item))
	var colour := parts.star_part_for_route(route_id)
	if stars >= 3 and not colour.is_empty() and not paid_stars.has(route_id):
		paid_stars.append(route_id)
		cards.append(card("part", colour))
	return cards


## Pays every route finished before custom drivers opened, the first time the
## editor opens. [param finished] lists the routes driven to the end.
func back_pay(finished: Array, best_stars: Dictionary, parts: DriverParts) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for route_id: Variant in finished:
		cards.append_array(pay_route(str(route_id), int(best_stars.get(route_id, 0)), parts))
	editor_seen = true
	return cards


## Tops up the name tags levels give, once each. Returns how many were new.
func settle_name_tags(parts: DriverParts, level: int) -> int:
	var owed := parts.name_tags_by_level(level) - level_tags
	if owed <= 0:
		return 0
	level_tags += owed
	name_tags += owed
	return owed


## A card for the "¡Desbloqueado!" queue, in UnlockNews's shape.
static func card(kind: String, item: Dictionary) -> Dictionary:
	var description := str(item.get("description", ""))
	if description == "":
		description = "A new colour for your drivers" if kind == "part" else "A new item for your drivers"
	return {"kind": "custom_" + kind, "id": str(item.get("id", "")), "name": str(item.get("name", "")),
		"description": description, "level": int(item.get("level", 0))}


## Takes off special items the player has fewer copies of than are worn, and
## forgets a chosen slot with no driver in it.
func repair(parts: DriverParts) -> void:
	for item: Dictionary in parts.specials():
		var worn := wearers(item["id"], parts)
		while worn.size() > copies(item["id"]):
			take_off(worn.pop_back(), item["field"])
	if not has_driver(chosen):
		chosen = -1


func to_dict() -> Dictionary:
	return {
		"drivers": drivers, "bought": bought, "specials": specials, "name_tags": name_tags,
		"level_tags": level_tags, "paid_routes": paid_routes, "paid_stars": paid_stars,
		"editor_seen": editor_seen, "chosen": chosen,
	}


static func from_dict(saved: Variant) -> CustomDrivers:
	var custom := CustomDrivers.new()
	if not saved is Dictionary:
		return custom
	var dict: Dictionary = saved
	var saved_drivers: Variant = dict.get("drivers")
	if saved_drivers is Array:
		for entry: Variant in saved_drivers:
			var look: Dictionary = (entry as Dictionary).duplicate(true) if entry is Dictionary else {}
			if not look.is_empty() and clean_name(str(look.get("name", ""))) == "":
				look = {}
			elif not look.is_empty():
				look["name"] = clean_name(str(look["name"]))
			custom.drivers.append(look)
	custom.bought = _strings(dict.get("bought"))
	custom.paid_routes = _strings(dict.get("paid_routes"))
	custom.paid_stars = _strings(dict.get("paid_stars"))
	var saved_specials: Variant = dict.get("specials")
	if saved_specials is Dictionary:
		for key: Variant in saved_specials:
			var count := _int(saved_specials[key])
			if key is String and count > 0:
				custom.specials[key] = count
	custom.name_tags = maxi(_int(dict.get("name_tags")), 0)
	custom.level_tags = maxi(_int(dict.get("level_tags")), 0)
	custom.editor_seen = dict.get("editor_seen") == true
	custom.chosen = _int(dict.get("chosen"), -1)
	if not custom.has_driver(custom.chosen):
		custom.chosen = -1
	return custom


static func _strings(value: Variant) -> Array[String]:
	var list: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			if entry is String and not list.has(entry):
				list.append(entry)
	return list


static func _int(value: Variant, fallback: int = 0) -> int:
	return int(value) if value is float or value is int else fallback


static func _same_colour(a: Array, b: Array) -> bool:
	if a.size() < 3 or b.size() < 3:
		return false
	for i in 3:
		if absf(float(a[i]) - float(b[i])) > 0.001:
			return false
	return true
