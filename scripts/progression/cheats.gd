class_name Cheats
extends RefCounted
## Hidden helpers for testing. Seven quick taps on a menu title reveal them. They
## only exist in test builds, so a store release never offers them.

const TAPS_TO_REVEAL := 7
## Longest pause between taps, in seconds, before the count starts again.
const TAP_WINDOW := 1.2

var _taps: int = 0
var _last_tap: float = -INF


static func available() -> bool:
	return OS.is_debug_build()


static func add_coins(profile: PlayerProfile, amount: int) -> void:
	profile.coins += amount


static func add_levels(profile: PlayerProfile, levels: int) -> void:
	profile.xp = DriverLevel.xp_for_level(DriverLevel.level_for(profile.xp) + levels)


## Owns every route, bus and livery, and leaves the current choices alone.
static func unlock_everything(profile: PlayerProfile, catalog: Catalog) -> void:
	for kind: String in [Catalog.ROUTES, Catalog.BUSES, Catalog.LIVERIES]:
		var owned: Array = profile.owned[kind]
		for item: Dictionary in catalog.items(kind):
			if not owned.has(item["id"]):
				owned.append(item["id"])


## Counts a tap. True on the tap that reveals the cheats.
func tap(now: float) -> bool:
	_taps = _taps + 1 if now - _last_tap <= TAP_WINDOW else 1
	_last_tap = now
	if _taps < TAPS_TO_REVEAL:
		return false
	_taps = 0
	return true
