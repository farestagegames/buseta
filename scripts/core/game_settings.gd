extends Node
## Player-adjustable settings. Held in memory for now; the save system in
## Phase 4 will persist them.

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
