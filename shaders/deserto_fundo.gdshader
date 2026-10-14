shader_type canvas_item;

// Fundo do Deserto Sagrado: a imagem fixa ganha vida só onde a máscara diz.
//   R = feixes de energia (pulsos saem do cristal e correm até os obeliscos)
//   G = cristal e pontas dos obeliscos (brilho que sobe e cintila)
//   B = disco do sol/lua (respira devagar)
// Por cima de tudo, bem leve: raios girando em volta do sol/lua, ar quente
// tremendo no horizonte, a imagem "respirando" (zoom lento) e uma onda de
// luz que sai do cristal a cada batida da música (grave/batida/onda vêm do
// script, de Maquina.energia_musica()).

uniform sampler2D mascara : filter_linear, repeat_disable;
uniform vec3 cor_energia = vec3(1.0, 0.72, 0.32);
uniform vec2 centro = vec2(0.5, 0.52);   // cristal, em UV da imagem
uniform vec2 sol = vec2(0.5, 0.19);      // disco do sol/lua, em UV da imagem
uniform float forca = 1.0;
uniform float grave = 0.0;               // 0..1, energia do grave da música
uniform float batida = 0.0;              // 0..1, salta em cada pancada
uniform float onda = 9.0;                // raio da onda da última batida (>0,62 = sem onda)
uniform float respiro = 1.0;             // zoom lento (0 = parado)
uniform float fase = 0.0;
// 0 = sem os raios do céu nem o brilho do disco (no jogo quem faz isso são
// as camadas do scripts/deserto_vivo.gd)
uniform float ceu = 1.0;
// energia do cristal (1 = inteiro; cai com os tiros; 0 = quebrado, feixes
// apagados). Vem do scripts/deserto_vivo.gd; no menu fica 1.
uniform float energia = 1.0;

// Pontas de ouro das pirâmides (só no jogo, scripts/deserto_vivo.gd). São
// pintadas aqui dentro, pixel a pixel na grade da foto: mesma resolução, mesma
// luz, sombra e névoa, e todo o brilho de cima (cristal, batida, onda) passa
// por elas igual passa pela pedra. São a própria pirâmide, só que em ouro, e
// o ouro reage ao jogo. Máscara (tools/gerar_egito.py): B = quinas,
// A = cobertura.
uniform sampler2D pontas : filter_linear, repeat_disable;
uniform vec4 pontas_caixa = vec4(0.0);    // caixa das pontas em UV da imagem (z = 0: sem pontas)
uniform float ouro_noite = 0.0;           // 0 = ouro ao sol, 1 = ouro claro, prateado, à lua
uniform float ouro_brilho = 0.0;          // humor do jogo: > 0 combo (mais vivo), < 0 erros (apagado)
uniform float ouro_varre = -1.0;          // 0..1: reflexo correndo pelas três pontas (acerto)
uniform vec3 ouro_toque = vec3(0.0, 0.0, -1.0);   // tiro no ouro: xy = ponto (UV da caixa), z = idade (s)

// No fragment o COLOR já vem multiplicado pela textura; a cor do nó
// (modulate, usado no cruzamento sol/lua) é guardada aqui no vertex.
varying vec4 cor_no;
varying vec2 uv_vivo;

void vertex() {
	cor_no = COLOR;
	// respiração: zoom lento em volta do centro, sempre acima de 1 (sem
	// borda); igual para a imagem toda, calculado só nos cantos
	float t = TIME + fase;
	float z = 1.0 + respiro * (0.030 + 0.014 * sin(t * 0.17) + 0.008 * batida);
	uv_vivo = (UV - 0.5) / z + 0.5 + respiro * vec2(0.006 * sin(t * 0.11), 0.004 * cos(t * 0.09));
}

vec3 ouro(vec3 pedra, vec4 msk, vec2 up) {
	float cob = msk.a;
	float quina = clamp(msk.b / max(cob, 0.004), 0.0, 1.0);
	// o claro e o escuro são os da pedra; só o tom vira ouro
	float l = dot(pedra, vec3(0.30, 0.59, 0.11));
	vec3 tom = mix(vec3(1.26, 0.98, 0.50), vec3(1.0, 0.96, 0.86), ouro_noite);
	vec3 col = mix(pedra, tom * l * 1.06, 0.62);
	float aceso = smoothstep(0.30, 0.80, l);
	vec3 luz = mix(vec3(1.0, 0.92, 0.66), vec3(0.80, 0.88, 1.0), ouro_noite);
	col += luz * quina * (0.05 + 0.09 * batida + 0.04 * grave + 0.14 * max(ouro_brilho, 0.0)) * (0.4 + aceso);
	// reflexo correndo de pirâmide em pirâmide (a cada acerto)
	if (ouro_varre >= 0.0) {
		float x = up.x - (ouro_varre * 1.4 - 0.2) + (up.y - 0.5) * 0.3;
		col += luz * exp(-x * x * 500.0) * (0.22 + 0.5 * aceso) * (1.0 - ouro_varre);
	}
	// combo deixa o ouro mais quente e vivo; erros o apagam
	col *= 1.0 + 0.22 * ouro_brilho;
	// o ouro "toca": clarão no ponto e um anel de reflexo que corre pelo metal
	if (ouro_toque.z >= 0.0 && ouro_toque.z < 0.7) {
		float dd = length((up - ouro_toque.xy) * vec2(1.0, 0.23));
		float idade = ouro_toque.z;
		float ka = (dd - idade * 0.22) / 0.012;   // x*x: pow() com base negativa é indefinido no GLSL ES (NaN na Mali)
		float anel = exp(-ka * ka) * (1.0 - idade / 0.7);
		float clarao = exp(-dd * dd * 2600.0) * max(0.0, 1.0 - idade * 3.0);
		col += luz * (anel * 1.2 + clarao * 2.2);
	}
	return mix(pedra, col, cob);
}

void fragment() {
	float t = TIME + fase;
	vec2 uv = uv_vivo;

	// ar quente tremendo na faixa do horizonte
	if (uv.y > 0.50 && uv.y < 0.98) {
		float calor = smoothstep(0.50, 0.66, uv.y) * smoothstep(0.98, 0.78, uv.y);
		uv.x += sin(uv.y * 170.0 + t * 4.2) * 0.0011 * calor;
	}

	vec4 base = texture(TEXTURE, uv);
	vec3 m = texture(mascara, uv).rgb;
	float lum = dot(base.rgb, vec3(0.3, 0.59, 0.11));
	// cristal quebrando: os feixes pintados na imagem viram cinza apagado
	if (energia < 0.999 && m.r + m.g > 0.01) {
		float apaga = (1.0 - energia) * clamp(m.r * 1.6 + m.g * 0.5, 0.0, 1.0);
		base.rgb = mix(base.rgb, vec3(lum * 0.50, lum * 0.46, lum * 0.44), apaga * 0.85);
	}

	if (pontas_caixa.z > 0.0) {
		vec2 up = (uv - pontas_caixa.xy) / pontas_caixa.zw;
		if (up.x > 0.0 && up.x < 1.0 && up.y > 0.0 && up.y < 1.0) {
			vec4 msk = texture(pontas, up);
			if (msk.a > 0.004) {
				base.rgb = ouro(base.rgb, msk, up);
			}
		}
	}

	// distância ao cristal com a proporção da imagem (2:3)
	float d = length((uv - centro) * vec2(1.0, 1.5));
	vec3 soma = vec3(0.0);

	if (m.r + m.g + m.b > 0.004) {
		// pulsos correm mais rápido e mais fortes com o grave
		float pulso = 0.5 + 0.5 * sin(d * 52.0 - t * (6.5 + 4.0 * grave));
		pulso = pulso * pulso * pulso * pulso;
		pulso = pulso * pulso;
		float laser = m.r * (0.22 + (1.15 + 0.9 * grave) * pulso + 0.08 * sin(t * 11.0) + 0.6 * batida) * energia;

		float faixa = 0.5 + 0.5 * sin(uv.y * 64.0 + t * 3.2);
		faixa = faixa * faixa;
		float cintila = 0.5 + 0.5 * sin(t * 7.3 + uv.x * 90.0);
		float cristal = m.g * (0.10 + 0.42 * faixa + 0.14 * cintila + 0.45 * batida + 0.2 * grave) * energia;

		float disco = m.b * (0.07 + 0.07 * sin(t * 1.35) + 0.25 * grave) * ceu;

		soma += cor_energia * laser * 0.85 + base.rgb * (cristal + disco) + cor_energia * cristal * 0.18;
	}

	// raios girando em volta do sol/lua (só no céu)
	if (ceu > 0.0 && uv.y < 0.62) {
		vec2 ps = (uv - sol) * vec2(1.0, 1.5);
		float rs = length(ps);
		float ang = atan(ps.y, ps.x);
		float raio = 0.5 + 0.5 * sin(ang * 12.0 + t * 0.30) * sin(ang * 7.0 - t * 0.21);
		raio = raio * raio * raio;
		float alto = smoothstep(0.62, 0.30, uv.y);
		soma += cor_energia * raio * alto * smoothstep(0.80, 0.08, rs) * (0.07 + 0.10 * grave) * (0.4 + lum) * ceu;
	}

	// onda de luz que sai do cristal na batida
	if (onda < 0.625 && energia > 0.05) {
		float anel = smoothstep(0.045, 0.0, abs(d - onda)) * clamp(1.0 - onda * 1.6, 0.0, 1.0);
		soma += (cor_energia * anel * (0.10 + 0.45 * (m.r + m.g)) + base.rgb * anel * 0.18) * energia;
	}

	vec3 rgb = base.rgb * (1.0 + 0.06 * batida) + soma * forca;
	COLOR = vec4(rgb, base.a) * cor_no;
}
