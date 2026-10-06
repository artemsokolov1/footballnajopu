// Панельный дом: швы между панелями, окна, часть окон светится тёплым светом.
shader_type spatial;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 wall_color : source_color = vec3(0.78, 0.74, 0.68);
uniform vec3 seam_color : source_color = vec3(0.5, 0.47, 0.44);
uniform vec3 glass_color : source_color = vec3(0.12, 0.15, 0.2);
uniform vec3 frame_color : source_color = vec3(0.88, 0.86, 0.82);
uniform vec3 lit_color : source_color = vec3(1.0, 0.72, 0.38);
uniform vec3 roof_color : source_color = vec3(0.25, 0.24, 0.24);
uniform float floor_height = 2.8;
uniform float module_width = 3.2;
uniform float plinth_height = 1.0;
uniform float lit_ratio = 0.22;
uniform float seed = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	if (n.y > 0.5) {
		ALBEDO = roof_color * (0.9 + 0.2 * value_noise(world_pos.xz * 2.0));
		ROUGHNESS = 0.9;
	} else {
		float h = abs(n.x) > 0.5 ? world_pos.z : world_pos.x;
		float face = abs(n.x) > 0.5 ? sign(n.x) * 3.0 : sign(n.z) * 7.0;
		float y = world_pos.y - plinth_height;
		vec2 grid = vec2(h / module_width, y / floor_height);
		vec2 cell_id = floor(grid);
		vec2 f = fract(grid);
		float panel_rand = hash12(cell_id + seed + face);
		vec3 col = wall_color * (0.93 + 0.1 * panel_rand) * (0.9 + 0.1 * value_noise(world_pos.xy * 0.7 + world_pos.zy));
		// Подтёки под окнами.
		col *= 1.0 - 0.08 * smoothstep(0.3, 0.0, f.y) * value_noise(vec2(h * 6.0, y));

		vec2 seam_px = fwidth(grid) * 1.2;
		float seam = max(1.0 - smoothstep(0.0, seam_px.x + 0.006, min(f.x, 1.0 - f.x)),
				1.0 - smoothstep(0.0, seam_px.y + 0.008, min(f.y, 1.0 - f.y)));
		col = mix(col, seam_color, seam * 0.8);

		float emission = 0.0;
		if (y > 0.0) {
			vec2 wmin = vec2(0.28, 0.32);
			vec2 wmax = vec2(0.72, 0.82);
			vec2 aa = fwidth(grid);
			float in_frame = smoothstep(wmin.x - 0.03 - aa.x, wmin.x - 0.03, f.x) * (1.0 - smoothstep(wmax.x + 0.03, wmax.x + 0.03 + aa.x, f.x))
					* smoothstep(wmin.y - 0.03 - aa.y, wmin.y - 0.03, f.y) * (1.0 - smoothstep(wmax.y + 0.03, wmax.y + 0.03 + aa.y, f.y));
			float in_glass = smoothstep(wmin.x - aa.x, wmin.x, f.x) * (1.0 - smoothstep(wmax.x, wmax.x + aa.x, f.x))
					* smoothstep(wmin.y - aa.y, wmin.y, f.y) * (1.0 - smoothstep(wmax.y, wmax.y + aa.y, f.y));
			// Вертикальная перемычка рамы.
			in_glass *= smoothstep(0.0, aa.x + 0.01, abs(f.x - 0.5) - 0.01);
			float win_rand = hash12(cell_id * 1.37 + seed * 3.1 + face);
			bool lit = win_rand < lit_ratio;
			vec3 glass = lit ? lit_color * (0.7 + 0.3 * hash12(cell_id + 9.0)) : glass_color * (0.8 + 0.5 * win_rand);
			col = mix(col, frame_color, in_frame);
			col = mix(col, glass, in_glass);
			emission = lit ? in_glass : 0.0;
		} else {
			col *= 0.7;
		}
		ALBEDO = col;
		ROUGHNESS = mix(0.9, 0.25, emission);
		EMISSION = lit_color * emission * 1.6;
	}
	SPECULAR = 0.3;
}
