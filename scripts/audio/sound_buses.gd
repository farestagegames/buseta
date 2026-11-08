class_name SoundBuses
extends RefCounted
## The game's audio buses, made in code so there is no bus layout file to keep in
## step. Radio has its own volume and a muffling filter for the outside views.
## Distant muffles music heard from a shop doorway.

const RADIO := "radio"
const DISTANT := "distant"
## The radio heard from outside the bus: high notes cut, as through the windows.
const RADIO_MUFFLE_HZ := 1800.0
const DISTANT_MUFFLE_HZ := 900.0


## Adds the buses once. Safe to call any number of times.
static func ensure() -> void:
	_add(RADIO, RADIO_MUFFLE_HZ, false)
	_add(DISTANT, DISTANT_MUFFLE_HZ, true)


static func _add(bus_name: String, cutoff: float, muffled: bool) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, AudioServer.get_bus_name(0))
	var filter := AudioEffectLowPassFilter.new()
	filter.cutoff_hz = cutoff
	AudioServer.add_bus_effect(index, filter)
	AudioServer.set_bus_effect_enabled(index, 0, muffled)


static func set_radio_volume(volume: float) -> void:
	var index := AudioServer.get_bus_index(RADIO)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, volume <= 0.0)


static func muffle_radio(muffled: bool) -> void:
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(RADIO), 0, muffled)


static func radio_muffled() -> bool:
	return AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index(RADIO), 0)
