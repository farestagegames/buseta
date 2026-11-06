extends Node
## Player-adjustable settings. Profile saves them through to_dict.

signal changed

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

## GraphicsQuality.Level, or AUTO to match the phone.
var graphics_quality: int = GraphicsQuality.AUTO:
	set(value):
		graphics_quality = clampi(value, GraphicsQuality.AUTO, GraphicsQuality.Level.HIGH)
		changed.emit()

var show_performance: bool = false:
	set(value):
		show_performance = value
		changed.emit()


## A language code from Lang.LANGUAGES. Empty follows the phone's language.
var language: String = "":
	set(value):
		language = value
		changed.emit()


func to_dict() -> Dictionary:
	return {
		"steering_mode": int(steering_mode), "sensitivity": sensitivity, "invert_tilt": invert_tilt,
		"sound_volume": sound_volume, "graphics_level": graphics_quality, "language": language,
		"show_performance": show_performance,
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
	set_block_signals(false)
	changed.emit()
