shader_type canvas_item;

// Fundo do Egito na qualidade LEVE (TV Box mais fraca, Rodada 29;
// scripts/deserto_vivo.gd). A mesma imagem do shaders/deserto_fundo.gdshader,
// andando com a câmera, e as pontas de ouro reagindo ao jogo (combo, erros,
// cristais quebrados, reflexo do acerto, tiro no ouro) exatamente como lá.
// Fica de fora o que era conta em cada ponto da tela inteira: ar quente no
// horizonte, nuvens ondulando, luz do cristal no chão, onda da batida e o
// crepúsculo da troca sol/lua. Na Mali-G31 o fundo completo, sozinho, pesava
// mais que todo o resto do quadro.

// Câmera: a imagem inteira anda igual (1/Z fixo, como no fundo completo).
uniform vec2 olhar = vec2(0.0);           // quanto a câmera andou (px de tela)
uniform vec2 px_uv = vec2(0.0);           // 1 px de tela em UV da imagem
uniform float inv_z_longe = 0.45;

uniform float grave = 0.0;
uniform float batida = 0.0;

// Pontas de ouro (iguais às do shaders/deserto_fundo.gdshader).
uniform sampler2D pontas : filter_linear, repeat_disable;
uniform vec4 pontas_caixa = vec4(0.0);
uniform float ouro_noite = 0.0;
uniform float ouro_brilho = 0.0;
uniform float ouro_varre = -1.0;
uniform vec3 ouro_toque = vec3(0.0, 0.0, -1.0);
uniform vec3 pontas_acesas = vec3(1.0);

varying vec4 cor_no;

void vertex() {
	cor_no = COLOR;
}

vec3 ouro(vec3 pedra, vec4 msk, vec2 up) {
	float cob = msk.a;
	float quina = clamp(msk.b / max(cob, 0.004), 0.0, 1.0);
	float l = dot(pedra, vec3(0.30, 0.59, 0.11));
	float wl = smoothstep(0.32, 0.22, up.x);
	float wr = smoothstep(0.68, 0.78, up.x);
	float acesa = dot(vec3(wl, 1.0 - wl - wr, wr), pontas_acesas);
	vec3 tom = mix(vec3(1.26, 0.98, 0.50), vec3(1.0, 0.96, 0.86), ouro_noite);
	vec3 col = mix(pedra, tom * l * (1.06 + 0.28 * acesa), 0.62 + 0.24 * acesa);
	float aceso = smoothstep(0.30, 0.80, l);
	vec3 luz = mix(vec3(1.0, 0.92, 0.66), vec3(0.80, 0.88, 1.0), ouro_noite);
	luz *= acesa;
	col += luz * quina * (0.20 + 0.10 * batida + 0.05 * grave + 0.14 * max(ouro_brilho, 0.0)) * (0.4 + aceso);
	col += luz * tom * 0.07;
	float sobe = fract(TIME * 0.38 + wl * 0.33 + wr * 0.66);
	float fy = (up.y - 1.05 + sobe * 1.1) / 0.075;
	col += luz * exp(-fy * fy) * (0.18 + 0.42 * aceso);
	if (ouro_varre >= 0.0) {
		float x = up.x - (ouro_varre * 1.4 - 0.2) + (up.y - 0.5) * 0.3;
		col += luz * exp(-x * x * 500.0) * (0.22 + 0.5 * aceso) * (1.0 - ouro_varre);
	}
	col *= 1.0 + 0.22 * ouro_brilho;
	if (ouro_toque.z >= 0.0 && ouro_toque.z < 0.7) {
		float dd = length((up - ouro_toque.xy) * vec2(1.0, 0.23));
		float idade = ouro_toque.z;
		float ka = (dd - idade * 0.22) / 0.012;   // x*x: pow() com base negativa é indefinido no GLSL ES (NaN na Mali)
		float anel = exp(-ka * ka) * (1.0 - idade / 0.7);
		float clarao = exp(-dd * dd * 2600.0) * max(0.0, 1.0 - idade * 3.0);
		col += luz * (anel * 1.2 + clarao * 2.2);
	}
	vec3 velho = mix(pedra * 0.7, vec3(0.42, 0.33, 0.20) * l * 1.1, 0.4);
	col = mix(velho, col, acesa);
	return mix(pedra, col, cob);
}

void fragment() {
	// na borda, espelha (fica sob o placar), como no fundo completo
	vec2 uv = UV - olhar * (1.0 - inv_z_longe) * px_uv;
	uv = 1.0 - abs(1.0 - abs(uv));
	vec4 base = texture(TEXTURE, uv);
	base.rgb *= 1.0 + 0.06 * batida;
	if (pontas_caixa.z > 0.0) {
		vec2 up = (uv - pontas_caixa.xy) / pontas_caixa.zw;
		if (up.x > 0.0 && up.x < 1.0 && up.y > 0.0 && up.y < 1.0) {
			vec4 msk = texture(pontas, up);
			if (msk.a > 0.004) {
				base.rgb = ouro(base.rgb, msk, up);
			}
		}
	}
	COLOR = base * cor_no;
}
