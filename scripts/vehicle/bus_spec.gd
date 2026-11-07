class_name BusSpec
extends Resource
## Data definition of one bus. New buses are new .tres files, not new code.

@export var display_name: String = "City 12"
@export var capacity: int = 40

@export_group("Dimensions (metres)")
@export var body_width: float = 2.55
@export var body_height: float = 3.0
@export var wheelbase: float = 6.0
@export var front_overhang: float = 2.7
@export var rear_overhang: float = 3.3
@export var wheel_radius: float = 0.5

@export_group("Steering")
@export var max_steer_degrees: float = 38.0
## How fast the road wheels can turn. This is what makes the bus feel heavy.
@export var steer_rate_degrees: float = 48.0
## Lateral grip limit in m/s². Steering is reduced with speed to respect it.
@export var max_lateral_accel: float = 3.0

@export_group("Drivetrain")
## Peak acceleration in first gear, in m/s².
@export var max_drive_accel: float = 1.6
@export var top_speed: float = 19.5
@export var top_speed_reverse: float = 3.5
## Road speed at which each gear runs out, in m/s. The last entry is top gear.
@export var gear_top_speeds: PackedFloat32Array = PackedFloat32Array([5.0, 9.0, 14.0, 20.0])
## Share of max_drive_accel available in each gear.
@export var gear_thrust: PackedFloat32Array = PackedFloat32Array([1.0, 0.8, 0.6, 0.45])
@export var shift_time: float = 0.3

@export_group("Braking and resistance (m/s²)")
@export var max_brake_decel: float = 4.0
@export var rolling_decel: float = 0.12
## Extra slowing from the engine when the accelerator is released.
@export var coast_decel: float = 0.25
## Drag: deceleration = drag_coefficient * speed².
@export var drag_coefficient: float = 0.001

@export_group("Pedal response (units per second)")
@export var throttle_rise_rate: float = 1.4
@export var throttle_fall_rate: float = 5.0
@export var brake_rise_rate: float = 3.5
@export var brake_fall_rate: float = 6.0

@export_group("Body movement")
@export var roll_degrees_per_accel: float = 1.1
@export var pitch_degrees_per_accel: float = 0.7
@export var suspension_stiffness: float = 26.0
@export var suspension_damping: float = 6.5

@export_group("Layout")
## 1 puts the passenger door on the right side, -1 on the left.
@export var door_side: int = 1
## Sideways position of the driver's seat, in metres from the centre line.
@export var driver_seat_x: float = -0.7
@export var door_open_time: float = 1.2
## Where the doorway starts, measured back from the nose.
@export var door_offset: float = 0.3
## Extra length ahead of the cab, for a bus with a bonnet.
@export var cab_offset: float = 0.0
@export_enum("city", "buseta", "chiva", "articulated") var body_style: String = "city"

@export_group("Articulation")
## From the rear axle back to the joint. Zero means a rigid bus.
@export var hitch_offset: float = 0.0
## From the joint back to the rear section's axle.
@export var trailer_wheelbase: float = 0.0
## From the rear section's axle back to the tail.
@export var trailer_overhang: float = 0.0

@export_group("Paint")
@export var body_colour: Color = Color(0.85, 0.16, 0.13)
@export var stripe_colour: Color = Color(0.96, 0.93, 0.84)
@export var accent_colour: Color = Color(0.98, 0.76, 0.2)
@export var roof_colour: Color = Color(0.85, 0.16, 0.13)
@export_enum("plain", "bands", "zigzag", "waves", "diamonds", "chevrons", "sunburst", "flowers") var pattern: String = "plain"


func overall_length() -> float:
	return front_overhang + wheelbase + rear_overhang


func is_articulated() -> bool:
	return trailer_wheelbase > 0.0


## Nose to tail, with any rear section.
func full_length() -> float:
	if not is_articulated():
		return overall_length()
	return front_overhang + wheelbase + hitch_offset + trailer_wheelbase + trailer_overhang


## Distance from the rear axle, which is the vehicle origin, to the middle of
## the body. Negative Z is forward.
func body_centre_z() -> float:
	return -(wheelbase + front_overhang - rear_overhang) / 2.0


## Doors go on the kerb side and the driver sits by the middle of the road.
func keep_to_side(side: int) -> void:
	door_side = side
	driver_seat_x = -absf(driver_seat_x) * float(side)
