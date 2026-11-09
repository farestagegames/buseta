class_name Difficulty
extends RefCounted
## How hard a shift is: how much faults cost, what it pays, how often the police
## turn up and what they do, and how often someone dodges the fare. Pack data,
## under "difficulties", with "default_difficulty" naming the usual one.

const FALLBACK_ID := "normal"

var id: String = FALLBACK_ID
var name: String = "Normal"
## Every fault's points are multiplied by this.
var penalty_scale: float = 1.0
## The shift's coins are multiplied by this.
var coin_scale: float = 1.0
## Seconds between police patrols, lowest and highest. Empty means no police.
var police_every: Vector2 = Vector2.ZERO
## How long a patrol stays around once it has turned up.
var police_watch_seconds: float = 90.0
## Whether the last fine in the list ends the run.
var police_ends_run: bool = false
## Coins for the first, second and later fines. With police_ends_run, a fault
## after the last one ends the run; without, the last fine repeats.
var fines: Array[int] = []
## Chance that each boarding passenger slips on without paying.
var dodger_chance: float = 0.0


func has_police() -> bool:
	return police_every.y > 0.0


static func from_data(data: Dictionary) -> Difficulty:
	var difficulty := Difficulty.new()
	difficulty.id = str(data.get("id", FALLBACK_ID))
	difficulty.name = str(data.get("name", difficulty.id))
	difficulty.penalty_scale = float(data.get("penalty_scale", 1.0))
	difficulty.coin_scale = float(data.get("coin_scale", 1.0))
	var every: Variant = data.get("police_every", [])
	if every is Array and (every as Array).size() == 2:
		difficulty.police_every = Vector2(float(every[0]), float(every[1]))
	difficulty.police_watch_seconds = float(data.get("police_watch_seconds", 90.0))
	difficulty.police_ends_run = data.get("police_ends_run", false) == true
	for fine: Variant in data.get("fines", []):
		difficulty.fines.append(int(fine))
	difficulty.dodger_chance = float(data.get("dodger_chance", 0.0))
	return difficulty


## The pack's difficulties, or one plain normal with no police if it has none.
static func list_for(pack_data: Dictionary) -> Array[Difficulty]:
	var out: Array[Difficulty] = []
	var entries: Variant = pack_data.get("difficulties", [])
	if entries is Array:
		for entry: Variant in entries:
			if entry is Dictionary:
				out.append(from_data(entry))
	if out.is_empty():
		out.append(Difficulty.new())
	return out


static func pick(list: Array[Difficulty], wanted: String, default_id: String) -> Difficulty:
	for difficulty in list:
		if difficulty.id == wanted:
			return difficulty
	for difficulty in list:
		if difficulty.id == default_id:
			return difficulty
	return list[0]


## Problems with a pack's difficulties, for validation.
static func check(entries: Variant, default_id: Variant) -> Array[String]:
	var problems: Array[String] = []
	if entries == null:
		return problems
	if not entries is Array or (entries as Array).is_empty():
		problems.append("difficulties must be a non-empty list")
		return problems
	var ids := []
	for entry: Variant in entries:
		if not entry is Dictionary:
			problems.append("A difficulty is not an object")
			continue
		var data: Dictionary = entry
		var id := str(data.get("id", ""))
		if id == "" or ids.has(id):
			problems.append("Difficulty id missing or repeated: '%s'" % id)
		ids.append(id)
		for key: String in ["penalty_scale", "coin_scale"]:
			if data.has(key) and (not (data[key] is float or data[key] is int) or float(data[key]) <= 0.0):
				problems.append("Difficulty %s needs %s above zero" % [id, key])
		var every: Variant = data.get("police_every", [])
		if not every is Array or ((every as Array).size() != 0 and ((every as Array).size() != 2 or float(every[0]) <= 0.0 or float(every[1]) < float(every[0]))):
			problems.append("Difficulty %s needs police_every as [lowest, highest] seconds" % id)
		if (every as Array).size() == 2 and (data.get("fines", []) as Array).is_empty():
			problems.append("Difficulty %s has police but no fines" % id)
		var chance := float(data.get("dodger_chance", 0.0))
		if chance < 0.0 or chance > 0.5:
			problems.append("Difficulty %s needs dodger_chance from 0 to 0.5" % id)
	if not ids.has(default_id):
		problems.append("default_difficulty is not one of the difficulties")
	return problems
