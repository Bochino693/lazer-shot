shader_type canvas_item;

// Pedra com escritas do fundo do mar (scripts/mar_vida.gd). Desenha a pedra
// recortada (sprites/mar_pedra_*.png, o contorno no alfa) por cima do fundo
// sem ela, então tudo que acontece aqui fica preso nela:
//   - as runas acendem com uma faixa de luz que desce do topo à base, e as
//     que a luz já passou ficam acesas um pouco;
//   - cada tiro abre um buraco (fundo escuro, parede iluminada pela luz de
//     cima, borda clara) com rachaduras saindo dele; runa quebrada apaga.
//   - a luz cáustica do sol lá de fora anda pela pedra (a mesma do fundo,
//     shaders/fundo_profundo.gdshader), mais forte no alto e nas partes claras.
// Máscara (1x da caixa da pedra): R = runas, G = altura (0 topo .. 1 base),
// B = pedra, A = halo das runas.

uniform sampler2D mascara : filter_linear, repeat_disable;
uniform vec4 regiao = vec4(0.0, 0.0, 1.0, 1.0);   // caixa da máscara em UV da textura da pedra
uniform float aspecto = 0.5;                       // largura / altura da caixa
uniform float periodo = 4.6;
uniform float fase = 0.0;
uniform vec4 danos[12];                            // xy = ponto (UV da caixa), z = raio (em largura), w = semente
uniform int n_danos = 0;
uniform sampler2D caustica : filter_linear, repeat_enable;          // sprites/mar_caustica.png (alfa; grande, sem mipmap)
uniform vec2 tam_px = vec2(476.0, 758.0);          // tamanho da textura da pedra (px do fundo)
uniform float forca_caustica = 0.4;

varying vec4 cor_no;

void vertex() {
	cor_no = COLOR;
}

void fragment() {
	vec2 luv = (UV - regiao.xy) / regiao.zw;
	// fora da caixa da máscara (a folga do recorte) não há runas
	float dentro = step(0.0, luv.x) * step(luv.x, 1.0) * step(0.0, luv.y) * step(luv.y, 1.0);
	vec4 m = texture(mascara, luv) * dentro;
	vec4 base = texture(TEXTURE, UV);
	vec3 col = base.rgb;

	float quebrado = 0.0;
	for (int i = 0; i < n_danos; i++) {
		vec4 d = danos[i];
		vec2 q = (luv - d.xy) * vec2(1.0, 1.0 / aspecto);
		float dq = length(q);
		float r = dq / d.z;
		if (r < 3.2) {
			vec2 n = q / max(dq, 1e-5);
			float luz = dot(n, vec2(-0.6, -0.8));
			float fundo = smoothstep(1.0, 0.5, r);
			float parede = smoothstep(1.05, 0.65, r) - fundo;
			col *= 1.0 - fundo * 0.74;
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

	// luz cáustica (uma camada, como nas paredes do fundo)
	float ca = texture(caustica, UV * tam_px / 445.0 + vec2(fase * 3.1 + TIME * 0.035, fase * 1.7 + TIME * 0.026)).a;
	float lum = dot(base.rgb, vec3(0.3, 0.55, 0.15));
	col += vec3(0.62, 0.92, 1.0) * ca * ca * forca_caustica
		* (0.35 + 0.65 * clamp(lum / 0.55, 0.0, 1.0)) * (1.0 - 0.5 * m.g) * (1.0 - quebrado);

	float p = fract(TIME / periodo + fase) * 1.4 - 0.2;
	float dy = m.g - p;
	float faixa = exp(-dy * dy * 140.0);
	float rastro = dy < 0.0 ? exp(dy * 6.0) * 0.6 : 0.0;
	float acende = (0.20 + faixa * 1.7 + rastro) * (1.0 - quebrado);
	vec3 ciano = vec3(0.32, 0.95, 1.0);
	col += ciano * (m.r * acende * 0.85 + m.a * acende * 0.28);
	col += ciano * faixa * m.b * 0.035;   // a luz passando de leve pela pedra
	COLOR = vec4(col, base.a) * cor_no;
}
