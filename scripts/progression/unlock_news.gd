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
