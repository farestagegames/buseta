class_name UnlockNews
extends RefCounted
## What a finished shift unlocked, for the "unlocked" cards the menu shows next:
## routes opened by finishing another route, and every bus, paint, decoration,
## driver, horn or route whose level the shift's XP reached. Pure logic.

## The order the cards come in.
const KINDS := [Catalog.ROUTES, Catalog.BUSES, Catalog.LIVERIES, Catalog.DECORATIONS, Catalog.DRIVERS]
const HORNS := "horns"

## One line under each kind's name, for items without their own description.
const BLURBS := {
	Catalog.ROUTES: "A new route to drive",
	Catalog.BUSES: "A new bus in the Garage",
	Catalog.LIVERIES: "A new paint for your bus in the Garage",
	Catalog.DECORATIONS: "A new cab decoration in the Garage",
	Catalog.DRIVERS: "A new driver for your crew",
	HORNS: "A new horn in the Garage",
}


## The cards for a shift: [param unlocked_routes] are the routes finishing it
## opened; items with a "level" above [param level_before] and up to
## [param level_after] join them. Each card is {kind, id, name, description,
## level}, level 0 for a route opened by finishing another. No item twice.
static func between(catalog: Catalog, horns: Array, level_before: int, level_after: int, unlocked_routes: Array) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var seen := {}
	for item: Dictionary in unlocked_routes:
		_add(cards, seen, Catalog.ROUTES, item, 0)
	if level_after > level_before:
		for kind: String in KINDS:
			for item: Dictionary in catalog.items(kind):
				if reached(item, level_before, level_after):
					_add(cards, seen, kind, item, int(item["level"]))
		for item: Dictionary in horns:
			if reached(item, level_before, level_after):
				_add(cards, seen, HORNS, item, int(item["level"]))
	return cards


## True when the item's level is above [param before] and no higher than [param after].
static func reached(item: Dictionary, before: int, after: int) -> bool:
	var level := int(item.get("level", 1))
	return level > before and level <= after


## The cards from a shift's rewards, as [ProgressionSystem] fills them in.
static func from_rewards(catalog: Catalog, horns: Array, rewards: Dictionary) -> Array[Dictionary]:
	var before := DriverLevel.level_for(int(rewards.get("xp_before", 0)))
	var after := DriverLevel.level_for(int(rewards.get("xp_after", rewards.get("xp_before", 0))))
	return between(catalog, horns, before, after, rewards.get("unlocked_routes", []))


static func _add(cards: Array[Dictionary], seen: Dictionary, kind: String, item: Dictionary, level: int) -> void:
	var key := "%s/%s" % [kind, item.get("id", "")]
	if seen.has(key):
		return
	seen[key] = true
	var description := str(item.get("description", ""))
	if description == "":
		description = BLURBS[kind]
	cards.append({"kind": kind, "id": str(item.get("id", "")), "name": str(item.get("name", "")),
		"description": description, "level": level})


## Cards for custom drivers between two levels: a new slot, a name tag and one
## card naming the parts the levels unlocked. Nothing before the first slot opens.
static func custom_between(parts: DriverParts, level_before: int, level_after: int) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	if parts.is_empty() or level_after <= level_before or level_after < parts.first_slot_level():
		return cards
	for level: int in parts.slot_levels():
		if level > level_before and level <= level_after:
			cards.append({"kind": "custom_slot", "id": "slot_%d" % level, "name": "A custom driver slot",
				"description": "Make your own driver from the Crew tray", "level": level})
	for level: int in parts.name_tag_levels_between(level_before, level_after):
		cards.append({"kind": "custom_name_tag", "id": "name_tag_%d" % level, "name": "Name tag",
			"description": "Rename one of your drivers", "level": level})
	var names: Array[String] = []
	for p: Dictionary in parts.parts():
		if int(p.get("cost", 0)) == 0 and reached(p, maxi(level_before, parts.first_slot_level()), level_after) and int(p.get("level", 0)) > 0:
			names.append(str(p["name"]))
	if not names.is_empty():
		cards.append({"kind": "custom_parts", "id": "parts_%d" % level_after, "name": "New driver parts",
			"description": ", ".join(names), "level": level_after, "names": names})
	return cards
