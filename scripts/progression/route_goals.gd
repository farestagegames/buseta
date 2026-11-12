class_name RouteGoals
extends RefCounted
## Three per-route goals. Each goal is a small data-driven rule evaluated against
## a finished shift report. Stars earned on a normal route equal the goals met.

const PERFECT_ACCURACY := 0.999


## Builds goal status entries for a report. Each entry has: id, value, met, text.
static func evaluate(goals: Array, report: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for goal: Variant in goals:
		if not goal is Dictionary:
			continue
		var entry: Dictionary = (goal as Dictionary).duplicate(true)
		entry["met"] = is_met(entry, report)
		entry["text"] = text_for(entry)
		out.append(entry)
	return out


static func stars_for(goals: Array, report: Dictionary) -> int:
	if goals.is_empty():
		return 0
	var met := 0
	for goal: Variant in goals:
		if goal is Dictionary and is_met(goal, report):
			met += 1
	return met


static func is_met(goal: Dictionary, report: Dictionary) -> bool:
	var counts: Dictionary = report.get("counts", {})
	var categories: Dictionary = report.get("categories", {})
	match str(goal.get("type", "")):
		"finish_under":
			return float(report.get("time", INF)) <= float(goal.get("value", 0.0))
		"no_fines":
			return int(counts.get("fines", 0)) == 0 and int(report.get("fined_coins", 0)) == 0
		"no_collisions":
			return int(counts.get("collisions", 0)) == 0
		"no_knocked":
			return int(counts.get("knocked", 0)) == 0
		"vendors":
			return int(counts.get("vendors", 0)) >= int(goal.get("value", 0))
		"perfect_stops":
			var served := int(report.get("served", 0))
			return served > 0 and int(report.get("perfect_stops", 0)) >= served
		"satisfaction":
			return float(categories.get("satisfaction", 0.0)) >= float(goal.get("value", 0.0))
		"passengers":
			return int(report.get("carried", 0)) >= int(goal.get("value", 0))
		"no_missed":
			return int(counts.get("missed_stops", 0)) == 0
		_:
			return false


## A short, translatable description shown in the route panel, HUD and report.
static func text_for(goal: Dictionary) -> String:
	match str(goal.get("type", "")):
		"finish_under":
			return TranslationServer.translate("Finish under %s") % _clock(int(goal.get("value", 0)))
		"no_fines":
			return TranslationServer.translate("No police fines")
		"no_collisions":
			return TranslationServer.translate("No collisions")
		"no_knocked":
			return TranslationServer.translate("Hit nothing")
		"vendors":
			var count := int(goal.get("value", 0))
			var key := "Pick up 1 vendor" if count == 1 else "Pick up %d vendors"
			return TranslationServer.translate(key) % count
		"perfect_stops":
			return TranslationServer.translate("Every stop perfect")
		"satisfaction":
			return TranslationServer.translate("Satisfaction %d%% or more") % int(goal.get("value", 0))
		"passengers":
			var count := int(goal.get("value", 0))
			var key := "Carry 1 passenger" if count == 1 else "Carry %d passengers"
			return TranslationServer.translate(key) % count
		"no_missed":
			return TranslationServer.translate("Miss no stops")
		_:
			return str(goal.get("text", ""))


static func _clock(seconds: int) -> String:
	@warning_ignore("integer_division")
	return "%d:%02d" % [seconds / 60, seconds % 60]


static func migrate_best_stars(old_stars: int) -> int:
	match clampi(old_stars, 0, 5):
		5:
			return 3
		4, 3:
			return 2
		2, 1:
			return 1
		_:
			return 0
