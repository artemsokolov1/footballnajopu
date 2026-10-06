// Земля вокруг коробки: вытоптанная трава с проплешинами.
shader_type spatial;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 grass_color : source_color = vec3(0.27, 0.36, 0.14);
uniform vec3 dry_color : source_color = vec3(0.45, 0.42, 0.22);
uniform vec3 dirt_color : source_color = vec3(0.36, 0.29, 0.21);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = fbm(p * 0.15);
	float detail = value_noise(p * 6.0);
	vec3 col = mix(grass_color, dry_color, smoothstep(0.4, 0.7, n));
	col = mix(col, dirt_color, smoothstep(0.55, 0.62, fbm(p * 0.3 + 4.0)));
	col *= 0.85 + 0.3 * detail;
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
