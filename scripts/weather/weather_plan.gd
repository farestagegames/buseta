class_name WeatherPlan
extends RefCounted
## Whether a shift gets a downpour, and when. Made once from the shift's seed, so
## the same seed always brings the same weather. Pure logic.
##
## An aguacero has three parts: a quick build-up (the sky darkens, wind, first
## drops), the downpour itself, and a short clearing as the sun comes back.

enum Phase { DRY, BUILDING, RAINING, CLEARING, OVER }

## Tests and tools can force the weather.
const PLANNED := -1
const FORCE_DRY := 0
const FORCE_RAIN := 1
## Seed offset, so the weather does not follow the same numbers as the hailers.
const SEED_SALT := 7919

var rains: bool = false
var start: float = INF ## Seconds into the shift when the build-up begins.
var build: float = 20.0
var length: float = 150.0 ## Of the downpour itself, after the build-up.
var clear: float = 25.0
var strength: float = 1.0
var gust_seed: float = 0.0


## shift_seconds is the timetable's length, so the rain lands mid-shift.
static func make(seed_value: int, time: TimeOfDay, settings: RainSettings, shift_seconds: float, force: int = PLANNED) -> WeatherPlan:
	var random := RandomNumberGenerator.new()
	random.seed = hash(seed_value + SEED_SALT)
	var plan := WeatherPlan.new()
	# Every number is drawn, rain or not, so the timing never depends on the chance.
	var roll := random.randf()
	var share := random.randf_range(settings.start_share.x, settings.start_share.y)
	plan.build = random.randf_range(settings.build_seconds.x, settings.build_seconds.y)
	plan.length = random.randf_range(settings.rain_seconds.x, settings.rain_seconds.y)
	plan.clear = random.randf_range(settings.clear_seconds.x, settings.clear_seconds.y)
	plan.strength = random.randf_range(settings.strength.x, settings.strength.y)
	plan.gust_seed = random.randf_range(0.0, 100.0)
	plan.rains = roll < time.rain_chance if force == PLANNED else force == FORCE_RAIN
	if plan.rains:
		plan.start = maxf(shift_seconds, 60.0) * share
	return plan


## Seconds from the start of the build-up to the end of the clearing.
func duration() -> float:
	return build + length + clear


func end() -> float:
	return start + duration()


func phase_at(t: float) -> Phase:
	if not rains or t < start:
		return Phase.DRY
	if t < start + build:
		return Phase.BUILDING
	if t < start + build + length:
		return Phase.RAINING
	if t < end():
		return Phase.CLEARING
	return Phase.OVER


## How hard it rains, 0 dry to 1 a full downpour. A tropical shower comes on in
## a rush after a few first drops, gusts while it lasts and eases off quickly.
func rain_at(t: float) -> float:
	match phase_at(t):
		Phase.BUILDING:
			var share := (t - start) / build
			return _peak(0.0) * share * share * share
		Phase.RAINING:
			return _peak(t - start - build)
		Phase.CLEARING:
			var share := 1.0 - (t - start - build - length) / clear
			return _peak(length) * share * share
	return 0.0


func _peak(into_rain: float) -> float:
	return clampf(strength * (0.88 + 0.12 * _gust(into_rain)), 0.0, 1.0)


## How dark the clouds are, 0 to 1. They gather before the rain arrives and
## break up as it eases, so the sky leads the rain both ways.
func cloud_at(t: float) -> float:
	match phase_at(t):
		Phase.BUILDING:
			return strength * smoothstep(0.0, 1.0, (t - start) / build)
		Phase.RAINING:
			return strength
		Phase.CLEARING:
			return strength * (1.0 - smoothstep(0.0, 1.0, (t - start - build - length) / clear))
	return 0.0


## Starts the downpour now, for the hidden cheat and the screenshot tools.
## With skip_build the rain is already at full strength.
func start_now(t: float, skip_build: bool = false) -> void:
	rains = true
	start = t - (build if skip_build else 0.0)


## Slow swells between 0 and 1, the same every time for this plan.
func _gust(seconds: float) -> float:
	var swell := sin(seconds * 0.21 + gust_seed) * 0.6 + sin(seconds * 0.53 + gust_seed * 1.7) * 0.4
	return swell * 0.5 + 0.5
