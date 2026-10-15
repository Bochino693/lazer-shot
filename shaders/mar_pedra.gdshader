shader_type canvas_item;

// Pedra com escritas do fundo do mar (scripts/mar_vida.gd). A pedra está na
// pintura do fundo; este plano por cima dela serve para esconder o que passa
// atrás e para o que é só dela:
//   - a cor vem da própria textura do fundo, no mesmo ponto da foto, com a
//     mesma luz do sol de fora (shaders/mar_luz.gdshaderinc): pedra e fundo
//     são os mesmos pixels, sem contorno nenhum (a textura do plano só dá o
//     contorno, no alfa);
//   - as runas acendem com uma faixa de luz que desce do topo à base, e as
//     que a luz já passou ficam acesas um pouco;
//   - cada tiro abre um buraco (fundo escuro, parede iluminada pela luz de
//     cima, borda clara) com rachaduras saindo dele; runa quebrada apaga.
// Máscara (1x da caixa da pedra): R = runas, G = altura (0 topo .. 1 base),
// A = halo das runas.

#include "res://shaders/mar_luz.gdshaderinc"

uniform sampler2D fundo : filter_linear, repeat_disable;   // a textura do fundo (a mesma do nó dele)
uniform vec2 canto = vec2(0.0);                    // canto da textura da pedra na foto (px)
uniform vec2 tam_foto = vec2(1024.0, 1536.0);      // a foto em px (o tamanho que o jogo vê)
uniform sampler2D mascara : filter_linear, repeat_disable;
uniform vec4 regiao = vec4(0.0, 0.0, 1.0, 1.0);   // caixa da máscara em UV da textura da pedra
uniform float aspecto = 0.5;                       // largura / altura da caixa
uniform float periodo = 4.6;
uniform float fase = 0.0;
uniform vec4 danos[12];                            // xy = ponto (UV da caixa), z = raio (em largura), w = semente
uniform int n_danos = 0;

varying vec4 cor_no;
varying vec2 uv_foto;
varying flat vec4 onda_t;
varying flat vec4 cau_t;

void vertex() {
	cor_no = COLOR;
	uv_foto = (canto + VERTEX) / tam_foto;
	onda_t = luz_onda();
	cau_t = luz_cau();
}

void fragment() {
	vec2 luv = (UV - regiao.xy) / regiao.zw;
	// fora da caixa da máscara (a folga do recorte) não há runas
	float dentro = step(0.0, luv.x) * step(luv.x, 1.0) * step(0.0, luv.y) * step(luv.y, 1.0);
	vec4 m = texture(mascara, luv) * dentro;
	float alfa = texture(TEXTURE, UV).a;
	vec3 col = luz_do_mar(texture(fundo, uv_foto).rgb, uv_foto, onda_t, cau_t);

	float quebrado = 0.0;
	for (int i = 0; i < n_danos; i++) {
		vec4 d = danos[i];
		vec2 q = (luv - d.xy) * vec2(1.0, 1.0 / aspecto);
		float dq = length(q);
		float r = dq / d.z;
		if (r < 3.2) {
			vec2 n = q / max(dq, 1e-5);
			float luz = dot(n, vec2(-0.6, -0.8));
			float poco = smoothstep(1.0, 0.5, r);
			float parede = smoothstep(1.05, 0.65, r) - poco;
			col *= 1.0 - poco * 0.74;
			// buraco: a parede do lado da luz fica na sombra, a oposta acesa
			col *= 1.0 - parede * clamp(0.35 + 0.5 * luz, 0.0, 1.0);
			col += vec3(0.16, 0.20, 0.22) * parede * max(-luz, 0.0);
			float aro = smoothstep(0.82, 1.0, r) * smoothstep(1.28, 1.0, r);
			col += vec3(0.22, 0.27, 0.29) * aro * max(luz, 0.0);
			float ang = atan(q.y, q.x);
			float s = d.w * 17.0;
			float rach = abs(sin(ang * 3.0 + s + sin(r * 4.0 + s) * 0.5)) * abs(sin(ang * 5.0 - s * 1.3 + r * 0.7));
			float linha = (1.0 - smoothstep(0.0, 0.09, rach)) * smoothstep(3.2, 1.1, r) * step(0.95, r);
			col *= 1.0 - 0.7 * linha;
			quebrado = max(quebrado, smoothstep(1.05, 0.7, r));
		}
	}

	float p = fract(TIME / periodo + fase) * 1.4 - 0.2;
	float dy = m.g - p;
	float faixa = exp(-dy * dy * 140.0);
	float rastro = dy < 0.0 ? exp(dy * 6.0) * 0.6 : 0.0;
	float acende = (0.20 + faixa * 1.7 + rastro) * (1.0 - quebrado);
	vec3 ciano = vec3(0.32, 0.95, 1.0);
	col += ciano * (m.r * acende * 0.85 + m.a * acende * 0.28);
	COLOR = vec4(col, alfa) * cor_no;
}
