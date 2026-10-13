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
		if (!lua) {
			float r1 = 0.5 + 0.5 * sin(a * 9.0 + t * 0.32 + 1.3 * sin(a * 3.0 - t * 0.21));
			float r2 = 0.5 + 0.5 * sin(a * 15.0 - t * 0.24 + 1.7);
			r1 = r1 * r1 * r1; r1 *= r1;
			r2 = r2 * r2 * r2; r2 *= r2; r2 *= r2;
			float raios = (r1 * 0.75 + r2 * 0.55) * queda * (0.75 + 0.5 * grave);
			float coroa = exp(-fora * 7.5) * (0.55 + 0.18 * sin(t * 1.4) + 0.45 * grave + 0.35 * batida);
			float chama = exp(-fora * 22.0) * (0.5 + 0.5 * sin(a * 23.0 + t * 2.1 + sin(a * 7.0 - t * 1.3) * 2.0));
			luz = raios * 0.65 + coroa * 0.55 + chama * 0.35;
		} else {
			float halo = exp(-fora * 6.0) * (0.42 + 0.10 * sin(t * 0.9) + 0.25 * grave);
			float d_anel = (r - rd * 1.62) / 0.045;
			float anel = exp(-d_anel * d_anel) * (0.16 + 0.10 * sin(a * 3.0 + t * 0.35));
			float f = 0.5 + 0.5 * sin(a * 6.0 + t * 0.10 + sin(a * 2.0 + t * 0.07) * 1.4);
			f = f * f * f; f *= f; f *= f;
			float feixes = f * queda * 0.45;
			luz = halo * 0.55 + anel + feixes;
		}
		luz += pisco * exp(-fora * 3.0) * 1.4;
		luz *= smoothstep(1.0, 0.85, r);
	}
	COLOR = vec4(cor * luz * cor_no.a, 1.0);
}
