// Falling rain drawn on an open cylinder around the camera. Streaks are worked
// out from the position alone, with no texture, and the cylinder follows the
// camera, so a downpour costs one or two transparent draws.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float radius = 6.0;
uniform float spacing = 0.22; // Metres between streak columns.
uniform float fall_speed = 11.0;
uniform float wind = 0.18; // Sideways drift per metre of fall.
uniform float width = 0.05; // Share of a column a streak covers.
uniform float opacity = 0.5;
uniform vec3 tint : source_color = vec3(0.8, 0.84, 0.9);

varying vec3 local_position;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float around = atan(local_position.z, local_position.x) * radius;
	float x = (around + local_position.y * wind) / spacing;
	float column = floor(x);
	float r1 = hash(column);
	if (r1 > amount * 0.85 + 0.08) {
		discard;
	}
	float r2 = hash(column + 17.0);
	float line = 1.0 - smoothstep(0.0, width, abs(fract(x) - (0.2 + 0.6 * r2)));
	float fall = local_position.y + TIME * fall_speed * (0.85 + 0.3 * r1) + r2 * 40.0;
	float phase = fract(fall / 3.1);
	float streak = smoothstep(0.0, 0.06, phase) * (1.0 - smoothstep(0.16, 0.26, phase));
	ALBEDO = tint;
	ALPHA = line * streak * opacity * (0.45 + 0.55 * amount);
}
