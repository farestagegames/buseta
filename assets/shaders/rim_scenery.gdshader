// Vertex-coloured scenery with a gentle rim: faces turned away from the camera
// pick up a little of the sky's colour at their edges, so trees, props and roofs
// read as chunky toys. Upward faces are left alone so the ground and flat tops
// far away do not wash out. A few instructions per pixel, no extra pass.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 rim_colour : source_color = vec3(0.86, 0.93, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.32;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = (1.0 - facing) * (1.0 - facing);
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	rim *= 1.0 - clamp(up, 0.0, 1.0);
	ALBEDO = mix(COLOR.rgb, rim_colour, rim * rim_strength);
	ROUGHNESS = roughness_value;
}
