// Head and tail lamps of the traffic, drawn with every car or motorbike in one
// batch. Lamps ahead of the middle are white and those behind red, so one
// material serves both and ignores the car's own paint colour.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform float on : hint_range(0.0, 1.0) = 0.0;
uniform vec3 head_off : source_color = vec3(0.72, 0.72, 0.68);
uniform vec3 head_on : source_color = vec3(1.0, 0.96, 0.82);
uniform vec3 tail_off : source_color = vec3(0.4, 0.06, 0.05);
uniform vec3 tail_on : source_color = vec3(1.0, 0.12, 0.08);

varying float front;

void vertex() {
	front = step(VERTEX.z, 0.0);
}

void fragment() {
	vec3 head = mix(head_off, head_on, on);
	vec3 tail = mix(tail_off, tail_on, on);
	ALBEDO = mix(tail, head, step(0.5, front));
}
