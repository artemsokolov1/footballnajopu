// Потёртый асфальт с трещинами, заплатками и выцветшей разметкой.
// Всё рисуется только цветом — геометрия пола остаётся идеально ровной.
shader_type spatial;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 asphalt_color : source_color = vec3(0.25, 0.255, 0.265);
uniform vec3 patch_color : source_color = vec3(0.19, 0.195, 0.205);
uniform vec3 crack_color : source_color = vec3(0.06, 0.06, 0.06);
uniform vec3 paint_color : source_color = vec3(0.86, 0.84, 0.76);
uniform vec2 field_half_size = vec2(8.0, 14.0);
uniform float line_width = 0.1;
uniform float center_circle_radius = 2.5;
uniform vec2 box_size = vec2(8.0, 3.5);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float sd_box(vec2 p, vec2 b) {
	vec2 q = abs(p) - b;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

float line_mask(float dist, float aa) {
	return 1.0 - smoothstep(line_width * 0.5 - aa, line_width * 0.5 + aa, abs(dist));
}

void fragment() {
	vec2 p = world_pos.xz;

	// Зерно и пятна.
	float grain = hash12(floor(p * 60.0)) * 0.5 + value_noise(p * 25.0) * 0.5;
	float stains = fbm(p * 0.35);
	vec3 col = asphalt_color * (0.86 + 0.22 * grain) * (0.85 + 0.3 * stains);

	// Заплатки более тёмного асфальта.
	float patch_n = fbm(p * 0.12 + vec2(3.0, 7.0));
	float patch_mask = smoothstep(0.62, 0.64, patch_n);
	col = mix(col, patch_color * (0.9 + 0.2 * grain), patch_mask);

	// Трещины: границы ячеек Вороного с искажением, только в некоторых местах.
	vec2 warped = p * 0.55 + vec2(fbm(p * 1.3), fbm(p * 1.3 + 5.2)) * 0.6;
	float edge = voronoi_edge(warped);
	float crack_zone = smoothstep(0.56, 0.64, fbm(p * 0.18 + vec2(11.0, 2.0)));
	float crack_w = 0.006 + 0.014 * value_noise(p * 3.0);
	float aa = fwidth(edge);
	float crack = (1.0 - smoothstep(crack_w - aa, crack_w + aa, edge)) * crack_zone;
	col = mix(col, crack_color, crack * 0.75);

	// Разметка поля.
	float paint_aa = fwidth(p.x) + fwidth(p.y);
	float d_outline = sd_box(p, field_half_size);
	float paint = line_mask(d_outline, paint_aa);
	float inside = step(d_outline, 0.0);
	paint = max(paint, line_mask(p.y, paint_aa) * inside);
	paint = max(paint, line_mask(length(p) - center_circle_radius, paint_aa));
	paint = max(paint, 1.0 - smoothstep(0.14 - paint_aa, 0.14 + paint_aa, length(p)));
	for (int s = -1; s <= 1; s += 2) {
		vec2 box_center = vec2(0.0, float(s) * (field_half_size.y - box_size.y * 0.5));
		float d_box = sd_box(p - box_center, box_size * 0.5);
		paint = max(paint, line_mask(d_box, paint_aa) * inside);
	}
	float wear = smoothstep(0.25, 0.65, fbm(p * 2.5 + vec2(4.0, 1.0)));
	paint *= mix(0.35, 0.9, wear) * (1.0 - crack);
	col = mix(col, paint_color, paint);

	ALBEDO = col;
	ROUGHNESS = mix(0.93, 0.8, paint);
	SPECULAR = 0.3;
}
