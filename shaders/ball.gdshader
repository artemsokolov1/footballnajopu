// Классический чёрно-белый мяч: области вокруг вершин икосаэдра (пятиугольники)
// и додекаэдра (шестиугольники) + тонкие швы между ними.
shader_type spatial;

uniform vec3 white_color : source_color = vec3(0.92, 0.91, 0.88);
uniform vec3 black_color : source_color = vec3(0.06, 0.06, 0.07);
uniform vec3 seam_color : source_color = vec3(0.35, 0.34, 0.32);
uniform float seam_width = 0.012;

const vec3 PENT[12] = vec3[12](vec3(0.00000, 0.52573, 0.85065), vec3(0.52573, 0.85065, 0.00000), vec3(0.85065, 0.00000, 0.52573), vec3(0.00000, 0.52573, -0.85065), vec3(0.52573, -0.85065, 0.00000), vec3(-0.85065, 0.00000, 0.52573), vec3(0.00000, -0.52573, 0.85065), vec3(-0.52573, 0.85065, 0.00000), vec3(0.85065, 0.00000, -0.52573), vec3(0.00000, -0.52573, -0.85065), vec3(-0.52573, -0.85065, 0.00000), vec3(-0.85065, 0.00000, -0.52573));
const vec3 HEX[20] = vec3[20](vec3(0.57735, 0.57735, 0.57735), vec3(0.57735, 0.57735, -0.57735), vec3(0.57735, -0.57735, 0.57735), vec3(0.57735, -0.57735, -0.57735), vec3(-0.57735, 0.57735, 0.57735), vec3(-0.57735, 0.57735, -0.57735), vec3(-0.57735, -0.57735, 0.57735), vec3(-0.57735, -0.57735, -0.57735), vec3(0.35682, 0.00000, 0.93417), vec3(0.93417, 0.35682, 0.00000), vec3(0.00000, 0.93417, 0.35682), vec3(0.35682, 0.00000, -0.93417), vec3(-0.93417, 0.35682, 0.00000), vec3(0.00000, 0.93417, -0.35682), vec3(-0.35682, 0.00000, 0.93417), vec3(0.93417, -0.35682, 0.00000), vec3(0.00000, -0.93417, 0.35682), vec3(-0.35682, 0.00000, -0.93417), vec3(-0.93417, -0.35682, 0.00000), vec3(0.00000, -0.93417, -0.35682));

varying vec3 local_normal;

void vertex() {
	local_normal = NORMAL;
}

void fragment() {
	vec3 n = normalize(local_normal);
	float best = -2.0;
	float second = -2.0;
	bool best_is_pent = false;
	for (int i = 0; i < 12; i++) {
		float d = dot(n, PENT[i]);
		if (d > best) { second = best; best = d; best_is_pent = true; }
		else if (d > second) { second = d; }
	}
	for (int i = 0; i < 20; i++) {
		float d = dot(n, HEX[i]);
		if (d > best) { second = best; best = d; best_is_pent = false; }
		else if (d > second) { second = d; }
	}
	vec3 col = best_is_pent ? black_color : white_color;
	float edge = best - second;
	float aa = fwidth(edge);
	col = mix(seam_color, col, smoothstep(seam_width - aa, seam_width + aa, edge));
	ALBEDO = col;
	ROUGHNESS = 0.45;
	SPECULAR = 0.4;
}
