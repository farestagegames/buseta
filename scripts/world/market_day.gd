class_name MarketDay
extends RefCounted
## Market day: on some shifts a town's map adds stalls and crates around its plaza
## and more people come out. Comes from the map's "market_day" block:
## {"chance": 0.5, "people": 1.4, "knockables": [...]}. Pure logic, seeded, so the
## same shift seed always brings the same market.

const SEED_OFFSET := 31


static func is_on(map_data: Dictionary, shift_seed: int) -> bool:
	var plan: Dictionary = map_data.get("market_day", {})
	if plan.is_empty():
		return false
	var random := RandomNumberGenerator.new()
	random.seed = shift_seed + SEED_OFFSET
	return random.randf() < float(plan.get("chance", 0.5))


## The map for this shift: a copy with the market's stalls added when it is on.
## The original is never changed.
static func apply(map_data: Dictionary, on: bool) -> Dictionary:
	if not on:
		return map_data
	var copy := map_data.duplicate(true)
	var knockables: Array = copy.get("knockables", [])
	knockables.append_array(copy["market_day"].get("knockables", []))
	copy["knockables"] = knockables
	return copy


## How many more people walk the streets on market day.
static func people(map_data: Dictionary, on: bool) -> float:
	return float(map_data.get("market_day", {}).get("people", 1.0)) if on else 1.0
