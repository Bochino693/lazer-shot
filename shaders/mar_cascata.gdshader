shader_type canvas_item;

// Água das cachoeiras do fundo do mar.
// Recortes do próprio fundo (atlantis.png) que escorrem para baixo:
// duas leituras deslocadas no tempo se revezam (sem salto) e uns riscos
// de espuma descem por cima. A máscara diz onde há água.

uniform sampler2D mascara : filter_linear, repeat_disable;
uniform float velocidade = 34.0;   // pixels da textura por segundo
uniform float ciclo = 26.0;        // distância percorrida antes de revezar
uniform float espuma = 0.42;

// No fragment o COLOR já vem multiplicado pela textura; a cor do nó
// (modulate) é guardada aqui no vertex.
varying vec4 cor_no;

void vertex() {
	cor_no = COLOR;
}

float ruido(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float m = texture(mascara, UV).r;
	if (m < 0.01) {
		COLOR = base * cor_no;
	} else {
		float px_x = UV.x / TEXTURE_PIXEL_SIZE.x;
		float px_y = UV.y / TEXTURE_PIXEL_SIZE.y;
		float t = TIME * velocidade / ciclo;
		float f1 = fract(t);
		float f2 = fract(t + 0.5);
		vec2 d1 = vec2(0.0, f1 * ciclo * TEXTURE_PIXEL_SIZE.y);
		vec2 d2 = vec2(0.0, f2 * ciclo * TEXTURE_PIXEL_SIZE.y);
		vec3 c1 = texture(TEXTURE, UV - d1).rgb;
		vec3 c2 = texture(TEXTURE, UV - d2).rgb;
		float troca = abs(f1 * 2.0 - 1.0);
		vec3 fluxo = mix(c1, c2, troca);
		// só puxa cor de onde também é água (não arrasta pedra para dentro)
		float m_origem = texture(mascara, UV - mix(d1, d2, troca)).r;
		float peso = m * mix(0.35, 1.0, m_origem);

		float coluna = floor(px_x * 0.5);
		float h = ruido(coluna);
		float onda = sin((px_y - TIME * velocidade * (1.2 + 0.8 * h)) * 0.11 + h * 6.2831) * 0.5 + 0.5;
		float risco = onda * onda * onda * onda * onda * onda;

		vec3 cor = mix(base.rgb, fluxo, peso);
		cor += vec3(0.80, 0.93, 1.0) * risco * espuma * m;
		COLOR = vec4(cor, base.a) * cor_no;
	}
}
