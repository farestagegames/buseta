class_name DriverLevel
extends RefCounted
## XP to level conversion. Each level asks for a little more than the last.

const FIRST_LEVEL_XP := 150
const STEP_XP := 75


static func xp_for_level(level: int) -> int:
	var steps := level - 1
	return steps * FIRST_LEVEL_XP + STEP_XP * steps * (steps - 1) / 2


static func level_for(xp: int) -> int:
	var level := 1
	while xp >= xp_for_level(level + 1):
		level += 1
	return level


## Progress through the current level, from 0 to 1.
static func progress(xp: int) -> float:
	var level := level_for(xp)
	var start := xp_for_level(level)
	return float(xp - start) / float(xp_for_level(level + 1) - start)


static func xp_from_shift(score: int, stars: int) -> int:
	return score + stars * 10
