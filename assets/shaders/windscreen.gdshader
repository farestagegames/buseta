// Raindrops on the windscreen, wiped away where the blades pass. The blades
// swing back and forth on a cosine, so how long ago a blade crossed each spot
// can be worked out exactly, and drops grow back over that time.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float wet : hint_range(0.0, 1.0) = 0.0; // How hard it is raining.
uniform float wiper_phase = 0.0; // Cycles of the blades, counted up.
uniform float wiper_period = 1.6; // Seconds for one sweep up and back.
uniform float sweep = 1.8; // Radians the blades swing through.
uniform vec2 pane_size = vec2(2.4, 1.6); // Metres.
uniform vec2 pivot_a = vec2(-0.25, 0.05); // Blade pivots, in metres from the bottom middle.
uniform vec2 pivot_b = vec2(0.85, 0.05);
uniform float blade = 0.8; // Blade length.
uniform float regrow = 0.3; // Share of drops back per second of full rain.

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Seconds since a blade on this pivot last crossed the spot, or a long time.
float since_wiped(vec2 spot, vec2 pivot) {
	vec2 arm = spot - pivot;
	if (length(arm) > blade || arm.y < -0.02) {
		return 1000.0;
	}
	// A blade at rotation r points along (-cos r, -sin r), resting at 0 and
	// swinging to -sweep.
	float r = atan(-arm.y, -arm.x);
	float share = clamp(-r / sweep, 0.0, 1.0);
	if (-r > sweep + 0.05) {
		return 1000.0;
	}
	float first = acos(1.0 - 2.0 * share) / 6.2831853;
	float now = fract(wiper_phase);
	float since = min(fract(now - first + 1.0), fract(now - (1.0 - first) + 1.0));
	return since * wiper_period;
}

void fragment() {
	vec2 spot = vec2((UV.x - 0.5) * pane_size.x, (1.0 - UV.y) * pane_size.y);
	float since = min(since_wiped(spot, pivot_a), since_wiped(spot, pivot_b));
	float grown = clamp(since * regrow * wet, 0.0, 1.0);
	vec2 grid = spot / 0.045;
	vec2 cell = floor(grid);
	float roll = hash(cell);
	vec2 centre = vec2(0.25 + 0.5 * hash(cell + 3.1), 0.25 + 0.5 * hash(cell + 7.7));
	float size = 0.12 + 0.22 * hash(cell + 1.3);
	float drop = 1.0 - smoothstep(size * 0.6, size, length(fract(grid) - centre));
	drop *= step(roll, grown * 0.75);
	float highlight = 1.0 - smoothstep(0.0, size * 0.5, length(fract(grid) - centre + vec2(size * 0.3, -size * 0.3)));
	ALBEDO = mix(vec3(0.55, 0.6, 0.66), vec3(0.95), highlight * drop);
	ALPHA = clamp(drop * 0.42 + wet * 0.05, 0.0, 0.6);
}
