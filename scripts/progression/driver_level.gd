class_name DriverLevel
extends RefCounted
## XP to level conversion. Each level asks for a little more than the last:
## reaching a level takes LINEAR_XP * s + SQUARE_XP * s * s, with s levels above
## the first (level 2 at 120, 5 at 840, 10 at 3240).

const LINEAR_XP := 90
const SQUARE_XP := 30


static func xp_for_level(level: int) -> int:
	var steps := level - 1
	return LINEAR_XP * steps + SQUARE_XP * steps * steps


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
	return score + stars * 17
