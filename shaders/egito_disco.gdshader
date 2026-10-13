shader_type canvas_item;

// Sol (Olho de Rá) e lua (Olho de Hórus) em 2x (scripts/deserto_vivo.gd).
// A máscara diz onde está cada parte: R = traços do olho, G = pupila,
// B = disco, A = branco do olho. No sol o plasma ferve em volta do olho;
// nos dois, uma luz corre pelos traços do olho, a pupila cintila quando a
// luz passa, a borda respira com o grave e o disco "pisca" (clarão rápido)
// de tempos em tempos e na troca sol/lua.

uniform sampler2D mascara : filter_linear, repeat_disable;
uniform bool lua = false;
uniform vec3 cor_luz = vec3(1.0, 0.92, 0.62);
uniform float grave = 0.0;
uniform float batida = 0.0;
uniform float pisco = 0.0;

varying vec4 cor_no;

void vertex() {
	cor_no = COLOR;
}

void fragment() {
	vec4 m = texture(mascara, UV);
	float t = TIME;
	float olho = clamp(m.r + m.g + m.a, 0.0, 1.0);
	vec2 uv = UV;
	if (!lua) {
		// plasma fervendo (só a superfície, o olho fica firme)
		float k = m.b * (1.0 - olho) * 0.0032;
		uv += k * vec2(sin(UV.y * 41.0 + t * 1.7) + sin((UV.x + UV.y) * 23.0 - t * 1.1),
				cos(UV.x * 37.0 - t * 1.4) + sin((UV.x - UV.y) * 29.0 + t * 0.9));
	}
	vec4 tex = texture(TEXTURE, uv);
	tex.a = texture(TEXTURE, UV).a;

	// luz que corre pelo olho (diagonal, uma passada a cada ~7 s)
	float s = fract(t * 0.14) * 1.9 - 0.45;
	float d = (UV.x * 0.85 + UV.y * 0.35) - s;
	float faixa = exp(-d * d * 260.0);
	float brilho_olho = m.r * (0.10 + 0.16 * grave + 0.22 * batida + 1.1 * faixa);
	float pupila = m.g * faixa * 1.4;

	// borda do disco respirando
	vec2 c = UV - 0.5;
	float rr = length(c);
	float borda = m.b * smoothstep(0.30, 0.37, rr) * (0.18 + 0.12 * sin(t * 1.3) + 0.3 * grave);

	vec3 col = tex.rgb;
	col += cor_luz * (brilho_olho + pupila);
	col += cor_luz * borda * (lua ? 0.6 : 0.8);
	col += cor_luz * pisco * m.b * (0.9 - 0.65 * olho);
	if (!lua) {
		// manchas de luz girando devagar na superfície
		float ang = atan(c.y, c.x);
		float onda = 0.5 + 0.5 * sin(ang * 5.0 + t * 0.45 + rr * 30.0);
		col += cor_luz * m.b * (1.0 - olho) * onda * onda * 0.08;
	}
	COLOR = vec4(col, tex.a) * cor_no;
}
