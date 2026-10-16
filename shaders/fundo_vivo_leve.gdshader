shader_type canvas_item;

// Fundo vivo na qualidade LEVE (TV Box mais fraca, Rodada 29): a mesma
// imagem e a mesma máscara do shaders/fundo_vivo.gdshader (menu, ranking,
// cenários e Arena), com a respiração (zoom lento), as luzes subindo com o
// grave, o brilho na batida e a vinheta. Ficam de fora as contas feitas em
// cada ponto da tela: ondas no chão e na água, reflexo correndo, o piscar
// ponto a ponto e a faixa de brilho. As duas leituras de imagem vêm direto
// do vértice (a placa já as busca antes).
//   R = luzes que sobem com o grave da música
//   B = brilho grande que acende na batida

uniform sampler2D mascara : filter_linear, repeat_disable;
uniform vec3 cor = vec3(1.0, 0.25, 0.2);
uniform float grave = 0.0;
uniform float batida = 0.0;
uniform float respiro = 1.0;
uniform float forca = 1.0;
uniform float fase = 0.0;

varying vec4 cor_no;
varying vec2 uv_vivo;

void vertex() {
	cor_no = COLOR;
	float t = TIME + fase;
	float z = 1.0 + respiro * (0.032 + 0.016 * sin(t * 0.19) + 0.010 * batida);
	uv_vivo = (UV - 0.5) / z + 0.5 + respiro * vec2(0.007 * sin(t * 0.13), 0.005 * cos(t * 0.11));
}

void fragment() {
	vec3 m = texture(mascara, uv_vivo).rgb;
	vec3 base = texture(TEXTURE, uv_vivo).rgb;
	float luz = m.r * (0.10 + 0.55 * grave + 0.35 * batida);
	float clarao = m.b * (0.06 + 0.85 * batida + 0.15 * grave);
	vec3 rgb = base * (1.0 + 0.05 * batida + (luz * 1.1 + clarao) * forca) + cor * ((luz + clarao) * 0.30 * forca);
	vec2 c = UV - 0.5;
	rgb *= 1.0 - dot(c, c) * (0.55 - 0.25 * grave);
	COLOR = vec4(rgb, 1.0) * cor_no;
}
