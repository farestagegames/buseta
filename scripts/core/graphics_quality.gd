class_name GraphicsQuality
extends RefCounted
## The low, medium and high settings as data. Pure logic, so what each level does
## and how a phone is matched to a level can be tested.

enum Level { LOW, MEDIUM, HIGH }

const AUTO := -1
const GIGABYTE := 1024 * 1024 * 1024

const PROFILES := {
	Level.LOW: {
		"shadows": false, "shadow_size": 1024, "shadow_distance": 0.0, "soft_shadows": 0,
		"render_scale": 0.75, "msaa": Viewport.MSAA_DISABLED, "view_distance": 380.0,
		"fog_density": 0.007, "traffic_cars": 8,
	},
	Level.MEDIUM: {
		"shadows": true, "shadow_size": 2048, "shadow_distance": 42.0, "soft_shadows": 1,
		"render_scale": 0.9, "msaa": Viewport.MSAA_DISABLED, "view_distance": 560.0,
		"fog_density": 0.0042, "traffic_cars": 11,
	},
	Level.HIGH: {
		"shadows": true, "shadow_size": 4096, "shadow_distance": 55.0, "soft_shadows": 2,
		"render_scale": 1.0, "msaa": Viewport.MSAA_2X, "view_distance": 900.0,
		"fog_density": 0.0022, "traffic_cars": 14,
	},
}


## Matches a level to a phone by its memory.
static func level_for_memory(memory_bytes: int) -> Level:
	if memory_bytes <= 0:
		return Level.MEDIUM
	if memory_bytes < 4 * GIGABYTE + GIGABYTE / 2:
		return Level.LOW
	if memory_bytes < 7 * GIGABYTE:
		return Level.MEDIUM
	return Level.HIGH


static func resolve(setting: int, memory_bytes: int) -> Level:
	if setting == AUTO:
		return level_for_memory(memory_bytes)
	return clampi(setting, Level.LOW, Level.HIGH) as Level


static func current_profile() -> Dictionary:
	var memory: int = OS.get_memory_info().get("physical", 0)
	return PROFILES[resolve(GameSettings.graphics_quality, memory)]
