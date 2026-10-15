shader_type canvas_item;

// Um plano do Egito (coluna, Anúbis, obelisco, cristal) recortado da imagem
// (tools/gerar_camadas.py). A folha do dia é a textura do nó; a da noite vem
// aqui e as duas se misturam pela "noite" (a troca sol/lua é um cruzamento).
// Onde o recorte brilha (cristal e cristais das pontas dos obeliscos, folha
// _brilho), a luz pulsa com a música como no fundo, e apaga quando o cristal
// quebra ("apagado" de cada plano: 1 = cristal quebrado, sem luz nenhuma).
// A luz que o cristal joga nas coisas (G da folha _brilho: degraus, pedestal,
// obeliscos, colunas) também some com o "apagado".
// A onda de luz da batida e o crepúsculo são as mesmas contas do fundo
// (shaders/deserto_fundo.gdshader), na mesma posição da imagem: a luz passa
// pelo plano e pelo fundo como se fossem uma peça só.

uniform sampler2D folha_lua : filter_linear_mipmap, repeat_disable;
uniform sampler2D brilho : filter_linear_mipmap, repeat_disable;
uniform float noite = 0.0;
uniform float crepusculo = 0.0;   // no meio da troca sol/lua: a luz baixa e quente do poente
uniform float grave = 0.0;
uniform float batida = 0.0;
uniform vec3 cor_dia = vec3(1.0, 0.74, 0.34);
uniform vec3 cor_noite = vec3(1.0, 0.28, 0.30);
uniform vec2 centro = vec2(0.5, 0.52);   // cristal, em UV da imagem
uniform float onda = 9.0;
uniform float energia = 1.0;
instance uniform float apagado = 0.0;
instance uniform vec2 canto = vec2(0.0);  // canto do plano na imagem (px)

varying vec4 cor_no;
varying vec2 uv_img;

void vertex() {
	cor_no = COLOR;
	uv_img = (canto + VERTEX) / vec2(1024.0, 1536.0);
}

void fragment() {
	// fora da troca sol/lua lê uma folha só
	vec4 base;
	if (noite <= 0.001) {
		base = texture(TEXTURE, UV);
	} else if (noite >= 0.999) {
		base = texture(folha_lua, UV);
	} else {
		base = mix(texture(TEXTURE, UV), texture(folha_lua, UV), noite);
	}
	vec3 col = base.rgb;
	// fora do recorte (boa parte da caixa do plano) não lê o brilho nem faz
	// conta nenhuma (na Mali-G31 cada leitura de textura pesa)
	if (base.a > 0.002) {
		vec2 gm = texture(brilho, UV).rg;
		float g = gm.r;
		vec3 cor = mix(cor_dia, cor_noite, noite);
		if (gm.g > 0.004) {
			vec3 sem_noite = min(vec3(min(col.r, max(col.g, col.b) * 1.12), col.g, col.b) * 0.78, vec3(0.17, 0.18, 0.24));
			vec3 sem = mix(col * 0.80, sem_noite, noite);
			col = mix(col, sem, apagado * gm.g);
			col += col * gm.g * (1.0 - apagado) * (0.10 * batida + 0.07 * grave);
		}
		if (g > 0.004) {
			float t = TIME;
			float lum = dot(col, vec3(0.3, 0.59, 0.11));
			float faixa = 0.5 + 0.5 * sin(UV.y * 260.0 + t * 3.2);
			faixa *= faixa;
			float cintila = 0.5 + 0.5 * sin(t * 7.3 + UV.x * 400.0);
			float luz = g * (0.10 + 0.42 * faixa + 0.14 * cintila + 0.45 * batida + 0.2 * grave) * (1.0 - apagado);
			col += col * luz + cor * luz * 0.18;
			// quebrado: o cristal vira vidro escuro, sem luz
			vec3 morto = vec3(lum * 0.42, lum * 0.40, lum * 0.46);
			col = mix(col, morto, apagado * clamp(g * 1.6, 0.0, 1.0));
		}
		col *= 1.0 + 0.06 * batida;
		if (onda < 0.625 && energia > 0.05) {
			float d = length((uv_img - centro) * vec2(1.0, 1.5));
			float anel = smoothstep(0.045, 0.0, abs(d - onda)) * clamp(1.0 - onda * 1.6, 0.0, 1.0);
			col += (cor * anel * 0.10 + col * anel * 0.18) * energia;
		}
		if (crepusculo > 0.001) {
			col = mix(col, col * vec3(0.92, 0.62, 0.52), crepusculo * 0.8);
		}
	}
	COLOR = vec4(col, base.a) * cor_no;
}
