extends Node
## Global signal bus. Modules talk through these signals rather than holding
## references to each other, so any module can be replaced or tested alone.

# --- Requests from UI or keyboard to the vehicle and camera ---
signal door_toggle_requested
signal indicator_toggle_requested(side: int) ## BusIndicators.TurnSide value
signal horn_changed(is_pressed: bool)
signal gear_toggle_requested
signal camera_cycle_requested
signal reset_requested
signal bus_relocate_requested(position: Vector2, heading: float)
signal shift_restart_requested

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

# --- World and route, published for HUD, passengers and later for scoring ---
signal map_ready(network: RoadNetwork, route: RouteRunner)
signal route_status_updated(status: Dictionary)
signal stop_served(stop_index: int, stop_name: String, left_behind: int)
signal stop_missed(stop_index: int, stop_name: String)
signal shift_completed(summary: Dictionary)
signal stop_session_started(stop_index: int, alighting: int, boarding: int)
signal passenger_alighted(stop_index: int)
signal passenger_boarded(stop_index: int)
signal onboard_changed(count: int)
signal bus_jolted(strength: float)
signal obstacle_hit(kind: String, speed_loss: float)

# --- Traffic and scoring ---
signal stop_arrived(stop_index: int, accuracy: float, seconds_late: float)
signal indicator_missed
signal red_light_run
signal signal_ahead(state: int, distance: float) ## TrafficLightPlan.Light, or -1.
signal penalty_shown(text: String)
signal score_updated(total: int)
signal shift_report_ready(report: Dictionary)
signal shift_rewards_ready(report: Dictionary)
