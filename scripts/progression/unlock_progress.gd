class_name UnlockProgress
extends RefCounted
## Finds the next item the player can work towards, and what is missing to get it.
## Used on the main menu and exposed for the results screen.


## The cheapest reachable item not yet owned and not yet affordable (falling back to
## the cheapest affordable one when everything left is in reach): routes, buses, liveries, drivers,
## cab decorations and horns. Reachable means any route prerequisite is met and the
## item is not tied to a route the player cannot choose (route-only buses). Returns
## an empty dictionary if there is nothing left to unlock.
static func next(profile: PlayerProfile, catalog: Catalog, pack: CountryPack) -> Dictionary:
	var level := DriverLevel.level_for(profile.xp)
	var best: Dictionary = {}
	var candidates: Array[Dictionary] = []
	for kind: String in [Catalog.ROUTES, Catalog.BUSES, Catalog.LIVERIES, Catalog.DRIVERS, Catalog.DECORATIONS]:
		for item: Dictionary in catalog.items(kind):
			# Arcades open by level from their Home button; nothing to work towards.
			if item.get("route_only", false) or Catalog.is_arcade(item):
				continue
			if profile.owns(kind, item["id"]):
				continue
			if kind == Catalog.ROUTES and not catalog.requirement_met(item, profile):
				continue
			candidates.append(_candidate(profile, level, kind, item, str(item.get("name", item["id"]))))
	for item: Dictionary in pack.horns():
		var id := str(item.get("id", ""))
		if profile.owns_horn(id):
			continue
		candidates.append(_candidate(profile, level, "horn", item, str(item.get("name", id))))
	# Aim at the next thing still to earn. Something already affordable stays in the
	# shop, but would otherwise sit on the line for ever if the player never wants it.
	var ready: Dictionary = {}
	for candidate: Dictionary in candidates:
		if _is_ready(candidate):
			if ready.is_empty() or _closer(candidate, ready):
				ready = candidate
		elif best.is_empty() or _closer(candidate, best):
			best = candidate
	return best if not best.is_empty() else ready


static func _is_ready(candidate: Dictionary) -> bool:
	return int(candidate["coins_missing"]) == 0 and int(candidate["levels_missing"]) == 0


static func _candidate(profile: PlayerProfile, level: int, kind: String, item: Dictionary, name: String) -> Dictionary:
	var cost := int(item.get("cost", 0))
	var need_level := maxi(int(item.get("level", 1)), 1)
	return {
		"kind": kind,
		"id": str(item.get("id", "")),
		"name": name,
		"cost": cost,
		"level": need_level,
		"coins_missing": maxi(cost - profile.coins, 0),
		"levels_missing": maxi(need_level - level, 0),
		"item": item,
	}


## Cheaper to reach comes first: lower cost, then fewer coins missing, then level.
static func _closer(a: Dictionary, b: Dictionary) -> bool:
	if int(a["cost"]) != int(b["cost"]):
		return int(a["cost"]) < int(b["cost"])
	if int(a["coins_missing"]) != int(b["coins_missing"]):
		return int(a["coins_missing"]) < int(b["coins_missing"])
	if int(a["levels_missing"]) != int(b["levels_missing"]):
		return int(a["levels_missing"]) < int(b["levels_missing"])
	return str(a["name"]) < str(b["name"])
