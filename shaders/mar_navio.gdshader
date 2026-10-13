shader_type canvas_item;

// Navio afundando (scripts/mar_vida.gd): enquanto cai, a água em volta mexe
// a imagem (ondulação) e a luz da superfície passa por ele em manchas
// (cáusticas). "agita" vai a 0 quando ele pousa.

uniform float agita = 1.0;

varying vec4 cor_no;

void vertex() {
	cor_no = COLOR;
}

void fragment() {
	float t = TIME;
	vec2 uv = UV + agita * 0.0045 * vec2(sin(UV.y * 38.0 + t * 3.1), cos(UV.x * 31.0 + t * 2.6));
	vec4 tex = texture(TEXTURE, uv);
	vec2 p = UV * vec2(9.0, 12.0);
	float c = sin(p.x + t * 1.3 + sin(p.y * 1.3 + t)) * sin(p.y * 1.1 - t * 1.1 + sin(p.x * 0.8));
	c = max(c, 0.0);
	c = c * c * c;
	vec3 col = tex.rgb + vec3(0.45, 0.85, 1.0) * c * 0.22 * (0.4 + 0.6 * agita);
	COLOR = vec4(col, tex.a) * cor_no;
}
