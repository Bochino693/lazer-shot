shader_type canvas_item;
render_mode blend_add;

// Luz em volta do sol e da lua (scripts/deserto_vivo.gd), atrás do disco.
// Sol: dois leques de raios girando em sentidos opostos, coroa que pulsa com
// o grave e chamas lentas na borda. Lua: halo frio, anel de gelo girando e
// feixes de luar suaves que passeiam devagar.
// Só aritmética (sem textura): um quadrado em volta do disco.

uniform bool lua = false;
uniform vec3 cor = vec3(1.0, 0.78, 0.36);
uniform float raio_disco = 0.33;   // raio do disco em fração do meio-lado
uniform float grave = 0.0;
uniform float batida = 0.0;
uniform float pisco = 0.0;          // clarão da troca sol/lua (0..1)

varying vec4 cor_no;

void vertex() {
	cor_no = COLOR;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float t = TIME;
	float rd = raio_disco;
	float fora = max(r - rd, 0.0);
	float a = atan(p.y, p.x);
	float luz = 0.0;
	if (r < 1.0) {
		float queda = smoothstep(1.0, rd, r);
		queda *= queda;
		// ondas de luz correndo para fora pelos raios
		float corre = 0.6 + 0.4 * sin(fora * 26.0 - t * 4.2);
		if (!lua) {
			// dois leques girando em sentidos opostos (bem visível: ~14 e ~9 graus/s)
			float a1 = a + t * 0.24;
			float a2 = a - t * 0.16;
			float r1 = 0.5 + 0.5 * sin(a1 * 9.0 + 1.3 * sin(a1 * 3.0 + t * 0.7));
			float r2 = 0.5 + 0.5 * sin(a2 * 14.0 + 1.7);
			r1 = r1 * r1 * r1; r1 *= r1;
			r2 = r2 * r2 * r2; r2 *= r2; r2 *= r2;
			// raios que crescem e encolhem
			float alcance = 0.82 + 0.18 * sin(t * 1.9 + a1 * 5.0);
			float q = smoothstep(alcance, rd, r);
			q *= q;
			float raios = (r1 * 0.8 + r2 * 0.55) * q * corre * (0.8 + 0.5 * grave);
			float coroa = exp(-fora * 7.0) * (0.55 + 0.2 * sin(t * 2.3) + 0.45 * grave + 0.35 * batida);
			float chama = exp(-fora * 20.0) * (0.5 + 0.5 * sin(a * 23.0 + t * 3.4 + sin(a * 7.0 - t * 2.2) * 2.0));
			// anel de luz que sai do sol de tempos em tempos
			float anel_r = rd + fract(t * 0.35) * (1.0 - rd);
			float ka = (r - anel_r) / 0.025;   // x*x: pow() com base negativa é indefinido no GLSL ES (NaN na Mali)
			float anel = exp(-ka * ka) * (1.0 - fract(t * 0.35)) * 0.35;
			luz = raios * 0.7 + coroa * 0.55 + chama * 0.35 + anel;
		} else {
			float halo = exp(-fora * 6.0) * (0.42 + 0.12 * sin(t * 1.3) + 0.25 * grave);
			float d_anel = (r - rd * 1.62) / 0.045;
			float anel = exp(-d_anel * d_anel) * (0.16 + 0.12 * sin(a * 3.0 + t * 1.1));
			float a1 = a - t * 0.15;
			float f = 0.5 + 0.5 * sin(a1 * 6.0 + sin(a1 * 2.0 + t * 0.5) * 1.4);
			f = f * f * f; f *= f; f *= f;
			float feixes = f * queda * corre * 0.55;
			float anel_r = rd + fract(t * 0.22) * (1.0 - rd);
			float ko = (r - anel_r) / 0.03;
			float onda = exp(-ko * ko) * (1.0 - fract(t * 0.22)) * 0.22;
			luz = halo * 0.55 + anel + feixes + onda;
		}
		luz += pisco * exp(-fora * 3.0) * 1.4;
		luz *= smoothstep(1.0, 0.85, r);
	}
	COLOR = vec4(cor * luz * cor_no.a, 1.0);
}
