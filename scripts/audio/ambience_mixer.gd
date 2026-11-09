class_name AmbienceMixer
extends RefCounted
## Decides how loud each street sound is from where the bus is and what is around
## it. The layers come from the pack's "ambience" list. Pure logic: AudioDirector
## feeds it the inputs and plays what it says.
##
## A layer loops, or with "every": [min, max] plays once now and then. Its "rule"
## sets its gain from 0 to 1:
## - always: full all the time.
## - sea: full within "near" metres of the sand, silent beyond "far".
## - stalls: the same, measured to the nearest market stall.
## - vendors: the same, measured to the nearest stall or bus stop, where street
##   vendors stand.
## - calm: full when the bus stands, quieter as it speeds up.
## - rain: follows the rain input, 0 to 1. The weather sets it.
## Optional keys: "volume_db" sets its level. "dry": true fades it out as rain sets
## in. "radio_ducks": true silences it while the radio is on, so two songs never
## play at once. "radio_ducks_db" (0 or less) lowers it by that much while the
## radio plays and the player is in the cockpit, so the radio is heard over it.
## "muffled": true plays it through the muffled "distant" bus.

const RULES: Array[String] = ["always", "sea", "stalls", "vendors", "calm", "rain"]
## Rules that need "near" and "far".
const DISTANCE_RULES: Array[String] = ["sea", "stalls", "vendors"]
const FLAGS: Array[String] = ["dry", "radio_ducks", "muffled"]
const SILENT_DB := -80.0
## Below this gain a loop is paused and a one-shot is skipped.
const AUDIBLE := 0.02
## The calm rule: at this speed in m/s a layer is down to CALM_FLOOR.
const CALM_SPEED := 14.0
const CALM_FLOOR := 0.35

## Metres from the bus to where the sand starts. INF when there is no coast.
var sea_distance: float = INF
## Metres to the nearest market stall.
var stall_distance: float = INF
## Metres to the nearest bus stop.
var stop_distance: float = INF
## Bus speed in m/s.
var speed: float = 0.0
## 0 is dry, 1 is a downpour. The hook for the weather.
var rain: float = 0.0
var radio_on: bool = false
## Share of a layer's radio dip that still applies from outside the bus.
const OUTSIDE_DUCK_SHARE := 0.5
## False from the follow cameras, where the radio is quieter and nothing dips.
var in_cockpit: bool = true

var layers: Array = []
var _since: Dictionary = {}
var _wait: Dictionary = {}
var _random := RandomNumberGenerator.new()


func _init(layer_list: Array = [], seed_value: int = 0) -> void:
	layers = layer_list
	_random.seed = seed_value
	for layer: Dictionary in layers:
		if is_one_shot(layer):
			_since[layer["id"]] = 0.0
			_wait[layer["id"]] = _next_wait(layer)


static func is_one_shot(layer: Dictionary) -> bool:
	return layer.has("every")


## 1 at or inside near, 0 at or beyond far, easing in between.
static func proximity(distance: float, near: float, far: float) -> float:
	if distance <= near:
		return 1.0
	if distance >= far:
		return 0.0
	return 1.0 - smoothstep(near, far, distance)


## The sea is east of the coast line, as GroundSurface lays it out.
static func distance_to_sea(x: float, coast_x: float) -> float:
	if coast_x == GroundSurface.NO_COAST:
		return INF
	return maxf(coast_x - x, 0.0)


## How loud a layer is now, from 0 to 1.
func gain(layer: Dictionary) -> float:
	var level := 1.0
	match str(layer.get("rule", "always")):
		"sea":
			level = proximity(sea_distance, float(layer["near"]), float(layer["far"]))
		"stalls":
			level = proximity(stall_distance, float(layer["near"]), float(layer["far"]))
		"vendors":
			level = proximity(minf(stall_distance, stop_distance), float(layer["near"]), float(layer["far"]))
		"calm":
			level = lerpf(1.0, CALM_FLOOR, clampf(speed / CALM_SPEED, 0.0, 1.0))
		"rain":
			level = clampf(rain, 0.0, 1.0)
	if layer.get("dry", false):
		level *= 1.0 - clampf(rain, 0.0, 1.0)
	if radio_on and layer.get("radio_ducks", false):
		level = 0.0
	# The street dips under the radio from every view; from outside the bus the
	# radio is a little quieter, so the street dips half as far.
	if radio_on:
		level *= db_to_linear(float(layer.get("radio_ducks_db", 0.0)) * (1.0 if in_cockpit else OUTSIDE_DUCK_SHARE))
	return level


## The player volume for a layer: its own volume_db plus its gain.
func volume_db(layer: Dictionary) -> float:
	var level := gain(layer)
	if level < AUDIBLE:
		return SILENT_DB
	return float(layer.get("volume_db", 0.0)) + linear_to_db(level)


func is_audible(layer: Dictionary) -> bool:
	return gain(layer) >= AUDIBLE


## Seconds since a one-shot layer last played.
func since(layer_id: String) -> float:
	return float(_since.get(layer_id, 0.0))


## Moves time on and returns the one-shot layers to play now. One that is due but
## cannot be heard here waits for its next turn.
func update(dt: float) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	for layer: Dictionary in layers:
		if not is_one_shot(layer):
			continue
		var id: String = layer["id"]
		_since[id] = float(_since[id]) + dt
		if _since[id] < _wait[id]:
			continue
		_since[id] = 0.0
		_wait[id] = _next_wait(layer)
		if is_audible(layer):
			due.append(layer)
	return due


func _next_wait(layer: Dictionary) -> float:
	var every: Array = layer["every"]
	return _random.randf_range(float(every[0]), float(every[1]))


## Everything wrong with a pack's ambience list. Files are checked by CountryPack.
static func check(layer_list: Array) -> Array[String]:
	var problems: Array[String] = []
	var ids := {}
	for layer: Variant in layer_list:
		if not layer is Dictionary or not (layer as Dictionary).has("id") or not (layer as Dictionary).has("file"):
			problems.append("Ambience layers need an id and a file")
			continue
		var id: String = str(layer["id"])
		if ids.has(id):
			problems.append("Ambience has %s twice" % id)
		ids[id] = true
		var rule := str(layer.get("rule", "always"))
		if not RULES.has(rule):
			problems.append("Ambience %s has an unknown rule %s" % [id, rule])
		elif DISTANCE_RULES.has(rule):
			if not (layer.has("near") and layer.has("far")) or not _is_number(layer["near"]) \
					or not _is_number(layer["far"]) or float(layer["near"]) >= float(layer["far"]):
				problems.append("Ambience %s needs near closer than far" % id)
		for flag: String in FLAGS:
			if layer.has(flag) and not layer[flag] is bool:
				problems.append("Ambience %s needs %s as true or false" % [id, flag])
		if layer.has("volume_db") and not _is_number(layer["volume_db"]):
			problems.append("Ambience %s needs volume_db as a number" % id)
		if layer.has("radio_ducks_db") and (not _is_number(layer["radio_ducks_db"]) or float(layer["radio_ducks_db"]) > 0.0):
			problems.append("Ambience %s needs radio_ducks_db as 0 or less" % id)
		if layer.has("every"):
			var every: Variant = layer["every"]
			if not every is Array or (every as Array).size() != 2 \
					or float(every[0]) <= 0.0 or float(every[0]) > float(every[1]):
				problems.append("Ambience %s needs every as [shortest, longest] seconds" % id)
	return problems


static func _is_number(value: Variant) -> bool:
	return value is int or value is float
