class_name BusTelemetry
extends RefCounted
## Snapshot of bus state published once per physics tick. One instance is
## reused, so listeners must read it immediately rather than keep it.

var speed: float = 0.0
var gear: int = 1
var rpm: float = 0.0
var is_reverse: bool = false
var steer_angle: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0
var longitudinal_accel: float = 0.0
var lateral_accel: float = 0.0
var body_roll: float = 0.0
var body_pitch: float = 0.0
var door_open_amount: float = 0.0
var doors_closed: bool = true
var indicator_side: int = 0
var indicator_lamp_on: bool = false
