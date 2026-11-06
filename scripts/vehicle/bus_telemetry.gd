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
var position: Vector3 = Vector3.ZERO ## Rear axle, in world space.
var heading: float = 0.0
var door_position: Vector3 = Vector3.ZERO ## Doorway at pavement level.
var body_height: float = 0.0 ## Height of the sprung body at the rear axle.
var ground_pitch: float = 0.0 ## Sprung body pitch from the road, radians.
var ground_roll: float = 0.0 ## Sprung body roll from the road, radians.
## Ground height under each wheel: front left, front right, rear left, rear right.
var wheel_heights: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
