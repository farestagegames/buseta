extends Node
## Player-adjustable settings. Profile saves them through to_dict.

signal changed
## Only the radio dial. Kept apart from changed, so a tap on RADIO mid-drive does
## not write the save file or wake every settings listener.
signal radio_station_changed

var steering_mode: SteeringMapper.Mode = SteeringMapper.Mode.WHEEL:
	set(value):
		steering_mode = value
		changed.emit()

var sensitivity: float = 1.0:
	set(value):
		sensitivity = clampf(value, SteeringMapper.MIN_SENSITIVITY, SteeringMapper.MAX_SENSITIVITY)
		changed.emit()

var invert_tilt: bool = false:
	set(value):
		invert_tilt = value
		changed.emit()

## 0 is silent, 1 is full.
var sound_volume: float = 0.7:
	set(value):
		sound_volume = clampf(value, 0.0, 1.0)
		changed.emit()

## The radio's own volume, under the sound volume. 0 is silent, 1 is full.
var radio_volume: float = 0.8:
	set(value):
		radio_volume = clampf(value, 0.0, 1.0)
		changed.emit()

## The station the radio was left on, kept between shifts. "" is off.
var radio_station: String = "":
	set(value):
		radio_station = value
		radio_station_changed.emit()

## GraphicsQuality.Level, or AUTO to match the phone.
var graphics_quality: int = GraphicsQuality.AUTO:
	set(value):
		graphics_quality = clampi(value, GraphicsQuality.AUTO, GraphicsQuality.Level.HIGH)
		changed.emit()

var show_performance: bool = false:
	set(value):
		show_performance = value
		changed.emit()

## The on-screen indicator buttons. Off by default to keep the screen clear; the
## bus then signals route turns by itself.
var show_indicator_buttons: bool = false:
	set(value):
		show_indicator_buttons = value
		changed.emit()


## A language code from Country.pack.languages(). Empty follows the phone's language.
var language: String = "":
	set(value):
		language = value
		changed.emit()


func to_dict() -> Dictionary:
	return {
		"steering_mode": int(steering_mode), "sensitivity": sensitivity, "invert_tilt": invert_tilt,
		"sound_volume": sound_volume, "graphics_level": graphics_quality, "language": language,
		"show_performance": show_performance, "radio_volume": radio_volume, "radio_station": radio_station,
		"show_indicator_buttons": show_indicator_buttons,
	}


## Restores saved values, ignoring anything missing or out of range.
func apply_saved(saved: Dictionary) -> void:
	set_block_signals(true)
	var mode := int(saved.get("steering_mode", steering_mode))
	if mode >= 0 and mode < SteeringMapper.Mode.size():
		steering_mode = mode as SteeringMapper.Mode
	sensitivity = float(saved.get("sensitivity", sensitivity))
	invert_tilt = bool(saved.get("invert_tilt", invert_tilt))
	sound_volume = float(saved.get("sound_volume", sound_volume))
	graphics_quality = int(saved.get("graphics_level", graphics_quality))
	show_performance = bool(saved.get("show_performance", show_performance))
	language = str(saved.get("language", language))
	radio_volume = float(saved.get("radio_volume", radio_volume))
	radio_station = str(saved.get("radio_station", radio_station))
	show_indicator_buttons = bool(saved.get("show_indicator_buttons", show_indicator_buttons))
	set_block_signals(false)
	changed.emit()
