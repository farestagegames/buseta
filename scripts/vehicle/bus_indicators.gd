class_name BusIndicators
extends RefCounted
## Indicator state with blink timing. Cancels itself once a turn is finished.

enum TurnSide { OFF = 0, LEFT = -1, RIGHT = 1 }

const BLINK_PERIOD := 0.7
## Heading change that counts as a completed turn.
const TURN_ANGLE := deg_to_rad(35.0)
const WHEEL_STRAIGHT := deg_to_rad(4.0)

var side: TurnSide = TurnSide.OFF
var lamp_on: bool = false

var _blink_time: float = 0.0
var _turned: float = 0.0


func toggle(requested: TurnSide) -> void:
	side = TurnSide.OFF if side == requested else requested
	_blink_time = 0.0
	_turned = 0.0


func update(yaw_change: float, steer_angle: float, dt: float) -> void:
	if side == TurnSide.OFF:
		lamp_on = false
		return
	# Only count turning in the signalled direction. Left turns raise heading.
	var turned_this_step := yaw_change * -float(side)
	_turned = maxf(_turned + turned_this_step, 0.0)
	if _turned >= TURN_ANGLE and absf(steer_angle) < WHEEL_STRAIGHT:
		toggle(side)
		lamp_on = false
		return
	_blink_time = fmod(_blink_time + dt, BLINK_PERIOD)
	lamp_on = _blink_time < BLINK_PERIOD / 2.0
