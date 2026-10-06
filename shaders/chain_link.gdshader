// Сетка-рабица: ромбы проволоки, прозрачные промежутки.
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform vec3 wire_color : source_color = vec3(0.55, 0.56, 0.55);
uniform float cell = 0.14;
uniform float wire = 0.012;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = vec2(world_pos.x + world_pos.z, world_pos.y) / cell;
	vec2 d = vec2(p.x + p.y, p.x - p.y);
	vec2 f = abs(fract(d) - 0.5);
	float dist = (0.5 - max(f.x, f.y)) * cell;
	float aa = fwidth(dist) * 1.5;
	float line = 1.0 - smoothstep(wire - aa, wire + aa, dist);
	// Вдали проволока тоньше пикселя — оставляем среднее покрытие, чтобы не рябило.
	float coverage = clamp(wire * 4.0 / cell, 0.0, 1.0);
	float far = smoothstep(0.3, 1.0, fwidth(p.x) * 4.0);
	ALPHA = mix(line, coverage, far) * 0.95;
	ALBEDO = wire_color;
	METALLIC = 0.6;
	ROUGHNESS = 0.5;
}
