class_name WeatherClock
extends RefCounted
## The weather as a shift goes on: follows the plan and tracks how wet the road
## is, which lags behind the rain. Everything that reacts to the weather reads it
## from here, so the effects all agree. Pure logic.

enum Change { NONE, DOWNPOUR_STARTED, RAIN_STOPPED }

## A road soaks through in a few seconds of heavy rain.
const SOAK_SECONDS := 6.0
## Rain this hard or harder counts as driving in the downpour.
const DOWNPOUR_RAIN := 0.35
## Cars and buses switch their lights on under clouds this dark.
const HEADLIGHT_CLOUD := 0.4

var plan: WeatherPlan
var settings: RainSettings
var time: TimeOfDay
var clock: float = 0.0
var rain: float = 0.0
var cloud: float = 0.0
var wetness: float = 0.0
var phase: WeatherPlan.Phase = WeatherPlan.Phase.DRY
var peak_rain: float = 0.0 ## The hardest it has rained this shift.


func _init(weather_plan: WeatherPlan, rain_settings: RainSettings, time_of_day: TimeOfDay) -> void:
	plan = weather_plan
	settings = rain_settings
	time = time_of_day


## Moves the weather on by dt seconds and says if the downpour began or ended.
func advance(dt: float) -> Change:
	clock += dt
	rain = plan.rain_at(clock)
	cloud = plan.cloud_at(clock)
	peak_rain = maxf(peak_rain, rain)
	if rain > wetness:
		wetness += (rain - wetness) * (1.0 - exp(-dt / SOAK_SECONDS))
	else:
		wetness = maxf(wetness - dt / maxf(settings.dry_seconds, 0.1), rain)
	var before := phase
	phase = plan.phase_at(clock)
	if phase == before:
		return Change.NONE
	if phase == WeatherPlan.Phase.RAINING:
		return Change.DOWNPOUR_STARTED
	if before == WeatherPlan.Phase.RAINING:
		return Change.RAIN_STOPPED
	return Change.NONE


func is_downpour() -> bool:
	return rain >= DOWNPOUR_RAIN


## Tyre grip as a share of a dry road.
func grip() -> float:
	return lerpf(1.0, settings.wet_grip, wetness)


## Traffic's speed as a share of its usual speed.
func traffic_speed() -> float:
	return lerpf(1.0, settings.traffic_speed, wetness)


## Times traffic's usual following gap.
func traffic_gap() -> float:
	return lerpf(1.0, settings.traffic_gap, wetness)


## Share of walkers still out. People hurry for cover as soon as it pours.
func pedestrians() -> float:
	return lerpf(1.0, settings.pedestrians, clampf(rain * 1.6, 0.0, 1.0))


## Share of walkers under an umbrella.
func umbrellas() -> float:
	return settings.umbrellas if rain > 0.04 else 0.0


## Seconds the timetable allows per second driven, on a wet road.
func slack_rate() -> float:
	return settings.schedule_slack * wetness


## Street lamps, stalls and shelters: lit at night, and partly under storm clouds.
func lights() -> float:
	return maxf(time.lights, cloud * settings.lights)


func headlights() -> bool:
	return time.is_dark() or cloud >= HEADLIGHT_CLOUD
