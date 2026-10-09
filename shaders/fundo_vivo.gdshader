shader_type canvas_item;

// Fundo vivo (scripts/fundo_vivo.gd): uma imagem parada ganha movimento na
// placa de vídeo, sem decodificar vídeo no processador. A máscara diz onde:
//   R = luzes que piscam e sobem com o grave da música
//   G = superfícies que ondulam (chão molhado, água) com reflexo correndo
//   B = brilho grande que acende na batida (alvo, títulos, raios de luz)
// Em tudo: zoom lento ("respiração"), faixa de brilho que cruza a tela de
// tempos em tempos e vinheta que abre com o grave.

uniform sampler2D mascara : filter_linear, repeat_disable;
uniform vec3 cor = vec3(1.0, 0.25, 0.2);
uniform float grave = 0.0;     // 0..1, energia do grave da música
uniform float batida = 0.0;    // 0..1, salta em cada pancada
uniform float respiro = 1.0;   // zoom lento (0 = parado)
uniform float forca = 1.0;
uniform float fase = 0.0;      // cada fundo num ponto diferente do ciclo

varying vec4 cor_no;
varying vec2 uv_vivo;

void vertex() {
	cor_no = COLOR;
	// zoom sempre acima de 1 + deslize lento: nunca aparece borda. É igual
	// para a tela toda, então é calculado aqui (4 cantos) e não por pixel.
	float t = TIME + fase;
	float z = 1.0 + respiro * (0.032 + 0.016 * sin(t * 0.19) + 0.010 * batida);
	uv_vivo = (UV - 0.5) / z + 0.5 + respiro * vec2(0.007 * sin(t * 0.13), 0.005 * cos(t * 0.11));
}

void fragment() {
	float t = TIME + fase;
	vec2 uv = uv_vivo;

	vec3 m = texture(mascara, uv).rgb;
	if (m.g > 0.02) {
		uv += vec2(sin(uv.y * 85.0 + t * 2.6), cos(uv.x * 63.0 - t * 2.1)) * (0.0026 * m.g);
	}
	vec3 base = texture(TEXTURE, uv).rgb;
	float lum = dot(base, vec3(0.3, 0.59, 0.11));

	// R: cada luz pisca no seu ritmo e todas sobem com o som
	float luz = 0.0;
	if (m.r > 0.01) {
		float pisca = 0.5 + 0.5 * sin(t * 9.0 + uv.x * 23.0 + uv.y * 31.0) * sin(t * 5.3 - uv.y * 17.0);
		luz = m.r * (0.10 + 0.55 * grave + 0.30 * pisca + 0.35 * batida);
	}

	// G: reflexo correndo sobre a superfície
	float agua = 0.0;
	if (m.g > 0.02) {
		float reflexo = 0.5 + 0.5 * sin(uv.x * 38.0 + uv.y * 22.0 - t * 1.7);
		reflexo = reflexo * reflexo;
		reflexo = reflexo * reflexo;
		agua = m.g * reflexo * (0.10 + 0.25 * grave);
	}

	// B: brilho na batida
	float clarao = m.b * (0.06 + 0.85 * batida + 0.15 * grave);

	// faixa de brilho na diagonal (~12 s por passagem)
	float x = uv.x + uv.y * 0.55 - (fract(t * 0.085) * 2.6 - 0.5);
	float faixa = smoothstep(0.09, 0.0, abs(x)) * (0.05 + 0.25 * lum);

	vec3 soma = base * (luz * 1.1 + agua + clarao + faixa) + cor * (luz * 0.30 + clarao * 0.30 + agua * 0.4);
	vec3 rgb = base * (1.0 + 0.05 * batida) + soma * forca;

	vec2 c = UV - 0.5;
	rgb *= 1.0 - dot(c, c) * (0.55 - 0.25 * grave);
	COLOR = vec4(rgb, 1.0) * cor_no;
}
