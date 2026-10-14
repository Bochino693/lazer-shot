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
// no jogo a máscara é vazia (os feixes e cristais são peças): nem lê
uniform bool usa_mascara = true;
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
// Luz do cristal pintada no chão e nos degraus (sprites/egito_fundo_luz.png,
// só no jogo): pulsa um pouco com a música e some quando o cristal quebra; o
// lado de cada obelisco some também quando o cristal da ponta dele quebra.
uniform sampler2D luz_lancada : hint_default_black, filter_linear, repeat_disable;
uniform vec2 luz_lados = vec2(1.0);

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
// cada ponta de ouro é ligada a um cristal: x = pirâmide da esquerda (cristal
// do obelisco esquerdo), y = do meio (cristal do meio), z = da direita. 0 =
// cristal quebrado: a ponta para de brilhar e fica ouro velho, apagado.
uniform vec3 pontas_acesas = vec3(1.0);

// Câmera 3D (só no jogo, scripts/deserto_vivo.gd): no jogo este é só o
// fundo (céu, pirâmides e chão, com as coisas em pé tiradas e reconstruídas
// atrás: tools/gerar_camadas.py); colunas, estátuas, obeliscos e cristal são
// planos separados. O chão tem distância pela altura (perspectiva até o pé
// das pirâmides) e cada pixel anda olhar * (1 - 1/Z) px de tela quando a
// câmera anda com a mira: o céu com a mira, o chão perto contra, o plano dos
// brasões (Z = 1) parado. Contínuo, sem rasgar nada.
uniform vec2 olhar = vec2(0.0);           // quanto a câmera andou (px de tela)
uniform vec2 px_uv = vec2(0.0);           // 1 px de tela em UV da imagem
uniform float inv_z_longe = 0.1;          // 1/Z do céu e do horizonte
uniform float inv_z_perto = 1.4285714;    // 1/Z do chão bem perto
uniform float horizonte_uv = 0.4557;      // y (UV) do pé das pirâmides
uniform float chao1_uv = 0.8464;          // y (UV) do chão a Z = 1
// Nuvens vivas: agitadas quando o sol/a lua está feliz, calmas quando tenso
// (0 = paradas). fase_nuvens anda no script com a rapidez do humor.
uniform float nuvens = 0.0;
uniform float fase_nuvens = 0.0;

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
	// qual ponta é esta (pelo x na caixa) e se o cristal dela está aceso
	float wl = smoothstep(0.32, 0.22, up.x);
	float wr = smoothstep(0.68, 0.78, up.x);
	float acesa = dot(vec3(wl, 1.0 - wl - wr, wr), pontas_acesas);
	luz *= acesa;
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
	// apagada: ouro velho e escuro, sem brilho nenhum
	vec3 velho = mix(pedra * 0.7, vec3(0.42, 0.33, 0.20) * l * 1.1, 0.4);
	col = mix(velho, col, acesa);
	return mix(pedra, col, cob);
}

void fragment() {
	float t = TIME + fase;
	vec2 uv = uv_vivo;

	if (olhar.x != 0.0 || olhar.y != 0.0) {
		float inv_z = clamp((uv.y - horizonte_uv) / (chao1_uv - horizonte_uv), inv_z_longe, inv_z_perto);
		uv -= olhar * (1.0 - inv_z) * px_uv;
		uv = 1.0 - abs(1.0 - abs(uv));   // na borda, espelha (fica sob o placar)
	}

	// R da luz_lancada: luz do cristal no chão; G: o céu onde as nuvens
	// andam (fora das pirâmides, some no horizonte). Uma leitura só.
	vec2 luz_ceu = texture(luz_lancada, uv).rg;

	// nuvens: o céu (fora das pirâmides) ondula e corre; mais com o humor alegre
	if (nuvens > 0.001 && luz_ceu.g > 0.004) {
		float k_ceu = luz_ceu.g * nuvens;
		vec2 w = vec2(sin(uv.y * 23.0 + fase_nuvens * 1.3) + 0.6 * sin(uv.x * 17.0 - fase_nuvens * 0.9 + uv.y * 9.0),
			cos(uv.x * 19.0 + fase_nuvens * 1.1) + 0.6 * sin(uv.y * 13.0 + fase_nuvens * 0.7));
		uv += w * vec2(0.0042, 0.0026) * k_ceu;
		uv.x += sin(fase_nuvens * 0.21 + uv.y * 6.0) * 0.004 * k_ceu;
	}

	// ar quente tremendo na faixa do horizonte
	if (uv.y > 0.50 && uv.y < 0.98) {
		float calor = smoothstep(0.50, 0.66, uv.y) * smoothstep(0.98, 0.78, uv.y);
		uv.x += sin(uv.y * 170.0 + t * 4.2) * 0.0011 * calor;
	}

	vec4 base = texture(TEXTURE, uv);
	vec3 m = usa_mascara ? texture(mascara, uv).rgb : vec3(0.0);
	// a luz do cristal só bate do horizonte para baixo
	float lz = luz_ceu.r;
	if (lz > 0.004) {
		float wl = smoothstep(0.40, 0.24, uv.x);
		float wr = smoothstep(0.60, 0.76, uv.x);
		float acesa = energia * mix(1.0, luz_lados.x, wl) * mix(1.0, luz_lados.y, wr);
		// apagada: de noite tira o vermelho da luz e escurece (fica a pedra
		// azulada no escuro); de dia (areia já laranja do sol) só escurece.
		// ouro_noite é 0 na imagem do sol e 1 na da lua.
		vec3 sem_noite = min(vec3(min(base.r, max(base.g, base.b) * 1.12), base.g, base.b) * 0.78, vec3(0.17, 0.18, 0.24));
		vec3 sem = mix(base.rgb * 0.80, sem_noite, ouro_noite);
		base.rgb = mix(base.rgb, sem, (1.0 - acesa) * lz);
		base.rgb += base.rgb * lz * acesa * (0.10 * batida + 0.07 * grave);
	}
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
