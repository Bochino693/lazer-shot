shader_type canvas_item;

// Sol (Olho de Rá) e lua (Olho de Hórus) em 2x (scripts/deserto_vivo.gd).
// O disco vem limpo; o olho é desenhado aqui para estar vivo:
//   - a pupila dourada passeia pela abertura do olho (uniform "olhar");
//   - a pálpebra desce e sobe ao piscar ("piscar" 0 aberto .. 1 fechado);
//   - os traços têm relevo e pegam a textura e a luz do próprio disco,
//     como se fossem gravados nele (sem cara de desenho colado por cima).
// Mapa do olho: R = traços, G = altura na abertura (0 em cima .. 1 embaixo),
// B = abertura, A = relevo dos traços.
// Em volta: no sol o plasma ferve e manchas de luz giram; a borda respira com
// a música e o disco dá um clarão ("pisco") de tempos em tempos.

uniform sampler2D olho : filter_linear, repeat_disable;
uniform bool lua = false;
uniform vec3 cor_luz = vec3(1.0, 0.92, 0.62);
uniform float raio_uv = 0.36;
uniform vec2 iris_c = vec2(0.5, 0.41);
uniform float iris_r = 0.054;
uniform vec2 olhar = vec2(0.0);
uniform float piscar = 0.0;
uniform float grave = 0.0;
uniform float batida = 0.0;
uniform float pisco = 0.0;

uniform vec3 traco_sombra = vec3(0.42, 0.18, 0.02);
uniform vec3 traco_luz = vec3(1.0, 0.80, 0.32);
uniform vec3 cor_branco = vec3(1.0, 0.97, 0.84);
uniform vec3 iris_centro = vec3(1.0, 0.90, 0.35);
uniform vec3 iris_borda = vec3(0.86, 0.44, 0.02);
uniform vec3 cor_palpebra = vec3(0.96, 0.62, 0.14);

varying vec4 cor_no;

void vertex() {
	cor_no = COLOR;
}

void fragment() {
	vec4 o = texture(olho, UV);
	float t = TIME;
	vec2 c = UV - 0.5;
	float rr = length(c);
	float disco = smoothstep(raio_uv, raio_uv - 0.01, rr);
	float olho_area = clamp(o.r + o.b, 0.0, 1.0);

	vec2 uv = UV;
	if (!lua) {
		// plasma fervendo (fora do olho, que fica firme)
		float k = disco * (1.0 - olho_area) * 0.0035;
		uv += k * vec2(sin(UV.y * 41.0 + t * 1.9) + sin((UV.x + UV.y) * 23.0 - t * 1.3),
				cos(UV.x * 37.0 - t * 1.6) + sin((UV.x - UV.y) * 29.0 + t * 1.1));
	}
	vec4 tex = texture(TEXTURE, uv);
	tex.a = texture(TEXTURE, UV).a;
	vec3 col = tex.rgb;
	float lum = dot(col, vec3(0.3, 0.59, 0.11));

	if (!lua) {
		// manchas de luz girando na superfície
		float ang = atan(c.y, c.x);
		float onda = 0.5 + 0.5 * sin(ang * 5.0 - t * 1.1 + rr * 34.0);
		col += cor_luz * disco * (1.0 - olho_area) * onda * onda * 0.10;
	}

	// ── olho: abertura (branco + íris) e pálpebra
	if (o.b > 0.003) {
		vec3 branco = mix(col, cor_branco, 0.6);
		vec2 d = (UV - (iris_c + olhar)) / iris_r;
		float ri = length(d);
		float iris = smoothstep(1.0, 0.9, ri);
		vec3 ci = mix(iris_centro, iris_borda, smoothstep(0.15, 1.0, ri));
		float estria = 0.5 + 0.5 * sin(atan(d.y, d.x) * 23.0 + ri * 7.0);
		ci *= 0.82 + 0.3 * estria * smoothstep(0.38, 0.9, ri);
		ci += cor_luz * 0.25 * (batida + 0.3 * grave);              // brilho divino com a música
		float pupila = smoothstep(0.47, 0.40, ri);
		ci = mix(ci, vec3(0.07, 0.035, 0.0), pupila);
		float reflexo = smoothstep(0.24, 0.12, length(d - vec2(-0.36, -0.40)));
		ci = mix(ci, vec3(1.0, 1.0, 0.95), reflexo * 0.9);
		// sombra da pálpebra de cima sobre o olho aberto
		float sombra_alto = smoothstep(0.35, 0.0, o.g) * 0.25;
		vec3 aberto = mix(branco, ci, iris) * (1.0 - sombra_alto);
		// pálpebra descendo
		float limite = piscar * 1.05 - 0.03;
		float tampa = 1.0 - smoothstep(limite - 0.02, limite + 0.02, o.g);
		vec3 pele = cor_palpebra * (0.72 + 0.4 * o.g) * (0.85 + 0.3 * lum);
		float aresta = smoothstep(0.07, 0.0, abs(o.g - limite)) * step(0.04, piscar);
		vec3 abertura = mix(aberto, pele, tampa);
		abertura = mix(abertura, traco_sombra, aresta * 0.85);
		col = mix(col, abertura, o.b);
	}

	// ── traços com relevo, gravados no disco (contorno escuro na borda do
	// traço para ficar bem definido, luz no lado de cima do relevo)
	if (o.r > 0.003) {
		vec3 traco = mix(traco_sombra, traco_luz, clamp(o.a * 1.25 - 0.1, 0.0, 1.0));
		traco = mix(traco, traco * (0.6 + lum * 0.7), 0.35);         // pega a textura do disco
		float contorno = smoothstep(0.15, 0.5, o.r) * (1.0 - smoothstep(0.55, 0.9, o.r));
		traco = mix(traco, traco_sombra * 0.6, contorno * 0.7);
		col = mix(col, traco, smoothstep(0.05, 0.5, o.r));
	}

	// luz que corre pelos traços (uma passada a cada ~5 s)
	float s = fract(t * 0.2) * 1.9 - 0.45;
	float dl = (UV.x * 0.85 + UV.y * 0.35) - s;
	float faixa = exp(-dl * dl * 260.0);
	col += cor_luz * o.r * (0.06 + 0.14 * grave + 0.18 * batida + 0.9 * faixa);

	// borda respirando e o clarão
	float borda = disco * smoothstep(raio_uv - 0.07, raio_uv, rr) * (0.18 + 0.12 * sin(t * 1.6) + 0.3 * grave);
	col += cor_luz * borda * (lua ? 0.6 : 0.8);
	col += cor_luz * pisco * disco * (0.9 - 0.6 * olho_area);
	COLOR = vec4(col, tex.a) * cor_no;
}
