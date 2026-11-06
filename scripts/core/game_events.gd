extends Node
## Global signal bus. Modules talk through these signals rather than holding
## references to each other, so any module can be replaced or tested alone.

# --- Requests from UI or keyboard to the vehicle and camera ---
signal door_toggle_requested
signal indicator_toggle_requested(side: int) ## BusIndicators.Side value
signal horn_changed(is_pressed: bool)
signal gear_toggle_requested
signal camera_cycle_requested
signal reset_requested

# --- Raw control surfaces, consumed by DriverInputRouter ---
signal ui_wheel_changed(normalised: float) ## -1 full left, 1 full right
signal ui_steer_buttons_changed(left: bool, right: bool)
signal ui_pedals_changed(throttle: float, brake: float)

# --- Resolved driver intent, consumed by BusController ---
signal drive_input_changed(steer: float, throttle: float, brake: float)

# --- Vehicle state, published for HUD, camera and later for scoring ---
signal bus_telemetry_updated(telemetry: BusTelemetry)
signal bus_collided(impact_speed: float)
signal camera_view_changed(view_name: String)
