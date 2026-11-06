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

## Off until Phase 5 adds the quality levels, but saved so the choice carries over.
var graphics_quality: int = 1:
	set(value):
		graphics_quality = clampi(value, 0, 2)
		changed.emit()


func to_dict() -> Dictionary:
	return {
		"steering_mode": int(steering_mode), "sensitivity": sensitivity, "invert_tilt": invert_tilt,
		"sound_volume": sound_volume, "graphics_quality": graphics_quality,
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
	graphics_quality = int(saved.get("graphics_quality", graphics_quality))
	set_block_signals(false)
	changed.emit()
