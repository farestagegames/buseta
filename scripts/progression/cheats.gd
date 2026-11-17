class_name Cheats
extends RefCounted
## Hidden helpers for testing. Seven quick taps on a menu title reveal them. They
## are on in debug builds, and in release builds while the test switch
## `buseta/testing/cheats_in_release` is on (true for now, so Play testers can try
## everything without grinding).

const TAPS_TO_REVEAL := 7
## Longest pause between taps, in seconds, before the count starts again.
const TAP_WINDOW := 1.2

## The project setting that turns the cheats on in release builds too. Flip it to
## false in project.godot before a public release.
const RELEASE_SETTING := "buseta/testing/cheats_in_release"

var _taps: int = 0
var _last_tap: float = -INF


static func available() -> bool:
	return available_in(OS.is_debug_build())


## The same check with the debug flag supplied, so a test can try a release build.
static func available_in(debug: bool) -> bool:
	return debug or ProjectSettings.get_setting(RELEASE_SETTING, false)


## A negative amount takes money away, down to none.
static func add_coins(profile: PlayerProfile, amount: int) -> void:
	profile.coins = maxi(profile.coins + amount, 0)


## A negative count takes levels away, down to the start of level 1. Either way the
## driver lands at the start of the new level's XP bar. Things already bought stay.
static func add_levels(profile: PlayerProfile, levels: int) -> void:
	profile.xp = DriverLevel.xp_for_level(maxi(DriverLevel.level_for(profile.xp) + levels, 1))


## Sets the driver straight to a level, at the start of that level's XP bar.
static func set_level(profile: PlayerProfile, level: int) -> void:
	profile.xp = DriverLevel.xp_for_level(maxi(level, 1))


## The highest driver level anything asks for: catalog items, horns and times of
## day. Reaching it unlocks every time of day, Alto Cafeto and the arcade.
static func top_level(catalog: Catalog, horns: Array, times: Array[TimeOfDay]) -> int:
	var top := 1
	for kind: String in Catalog.KINDS:
		for item: Dictionary in catalog.items(kind):
			top = maxi(top, int(item.get("level", 1)))
	for horn: Dictionary in horns:
		top = maxi(top, int(horn.get("level", 1)))
	for time: TimeOfDay in times:
		top = maxi(top, time.level)
	return top


## Owns everything in the catalog and every horn, and leaves the current choices
## alone. Routes with a `requires` are owned outright, so their requirement is met.
static func unlock_everything(profile: PlayerProfile, catalog: Catalog, pack_horns: Array = []) -> void:
	for kind: String in profile.owned:
		var owned: Array = profile.owned[kind]
		for item: Dictionary in catalog.items(kind):
			if not owned.has(item["id"]):
				owned.append(item["id"])
	for horn: Dictionary in pack_horns:
		if not profile.horns_owned.has(horn["id"]):
			profile.horns_owned.append(horn["id"])


## Takes back everything bought or unlocked, as on a new save: only the catalog's
## free items and the pack's free horns stay owned, finished routes are forgotten
## and choices fall back to what is still owned. Coins, XP and stats stay, so the
## level cheats can set them apart.
static func reset_unlocks(profile: PlayerProfile, catalog: Catalog, pack_horns: Array = []) -> void:
	var fresh := PlayerProfile.new()
	profile.owned = fresh.owned
	profile.horns_owned.clear()
	profile.completed_routes.clear()
	var route := catalog.default_route()
	if route != "" and not profile.owns(Catalog.ROUTES, route):
		(profile.owned[Catalog.ROUTES] as Array).append(route)
	profile.grant_free_items(catalog)
	profile.settle_horns(pack_horns)
	if profile.horn != "" and not profile.owns_horn(profile.horn):
		profile.horn = ""
	for kind: String in profile.selected:
		if not profile.owns(kind, str(profile.selected[kind])):
			profile.selected[kind] = PlayerProfile.DEFAULTS.get(kind, "")
	profile.repair_choices(catalog)


## Counts a tap. True on the tap that reveals the cheats.
func tap(now: float) -> bool:
	_taps = _taps + 1 if now - _last_tap <= TAP_WINDOW else 1
	_last_tap = now
	if _taps < TAPS_TO_REVEAL:
		return false
	_taps = 0
	return true
