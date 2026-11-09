// Building walls: a tiling texture tinted by vertex colour, as before, plus
// windows that light up after dark. Which windows are lit is worked out from
// the window's place and the building's own share in the vertex alpha, so it
// costs no extra geometry and stays the same every shift.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 tile_metres = vec2(3.2, 3.2);
uniform float panes = 1.0; // Windows across one tile.
uniform vec4 window_box = vec4(0.29, 0.16, 0.71, 0.77); // Left, top, right, bottom of a pane, 0 to 1.
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
uniform float night : hint_range(0.0, 1.0) = 0.0; // How bright lit windows are.
uniform float lit_share : hint_range(0.0, 1.0) = 0.0; // Share of windows lit.
uniform vec3 warm_light : source_color = vec3(1.0, 0.78, 0.46);
uniform vec3 cool_light : source_color = vec3(0.72, 0.84, 1.0);

void fragment() {
	vec2 uv = UV / tile_metres;
	vec3 base = texture(albedo_texture, uv).rgb;
	ALBEDO = base * COLOR.rgb;
	ROUGHNESS = roughness_value;
	if (night > 0.0) {
		vec2 pane_uv = uv * vec2(panes, 1.0);
		vec2 cell = floor(pane_uv);
		vec2 inside = fract(pane_uv);
		float in_box = step(window_box.x, inside.x) * step(inside.x, window_box.z)
			* step(window_box.y, inside.y) * step(inside.y, window_box.w);
		float roll = fract(sin(dot(cell, vec2(12.9898, 78.233)) + COLOR.a * 91.7) * 43758.5453);
		float lit = step(roll, lit_share * (0.4 + 1.2 * COLOR.a));
		float colour_roll = fract(roll * 7.31);
		vec3 glow = mix(warm_light, cool_light, step(0.72, colour_roll));
		// Shutters and blinds let the light through in bands, as the texture shows.
		float through = 0.55 + 0.45 * (1.0 - clamp(dot(base, vec3(0.33)), 0.0, 1.0));
		EMISSION = glow * in_box * lit * night * through * 1.15;
	}
}
