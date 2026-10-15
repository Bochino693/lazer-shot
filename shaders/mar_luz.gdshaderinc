// Luz do sol lá de fora no Mar, entrando pela superfície e nunca parada:
//   - raios: fachos largos saindo do alto, balançando devagar e respirando
//     (as ondas da superfície mexem a luz); fortes na água aberta, fracos
//     na frente das coisas perto;
//   - cáustica: as linhas de luz que a superfície joga em tudo que está
//     embaixo, andando sem parar: no chão em perspectiva (grande perto,
//     miúda lá longe) e nas coisas em pé (pedras, templo, paredes) numa
//     camada só, presa na foto.
// A MESMA conta no fundo (shaders/fundo_profundo.gdshader) e nas pedras com
// escritas (shaders/mar_pedra.gdshader): cada pixel recebe a luz pelo lugar
// dele na foto, então a pedra e o fundo em volta acendem juntos, sem
// contorno nenhum quando um facho ou a cáustica passa.
// Máscara (sprites/mar_profundidade.png, 1/4 da foto; tools/gerar_profundidade.py):
// G = onde cai a cáustica, B = coisa em pé (as pedras: cáustica de parede,
// não de chão), A = força parada dos raios.
// Leve para a TV box: sem seno por pixel (os fachos já vêm animados numa
// textura, sprites/mar_raios.png: x = direção, y = tempo, em ciclo); o que
// só depende do tempo sai no vértice (luz_onda / luz_cau).

uniform sampler2D profundidade : filter_linear, repeat_disable;
uniform sampler2D caustica : filter_linear_mipmap, repeat_enable;   // sprites/mar_caustica.png (alfa)
uniform sampler2D caustica_perto : filter_linear, repeat_enable;    // a mesma, sem mipmap (onde ela fica grande)
uniform sampler2D raios : filter_linear, repeat_enable;             // sprites/mar_raios.png (raios animados)
uniform float raios_ciclo = 48.0;      // segundos de uma volta de mar_raios.png (RAIOS_CICLO do tools/gerar_fx.py)
uniform vec2 sol = vec2(0.52, -0.10);  // de onde a luz entra (UV da foto, acima do topo; SOL_MAR do tools/gerar_profundidade.py)
uniform float forca_raios = 1.0;
uniform float forca_caustica = 0.34;
uniform float horizonte = 0.515;       // y (UV) onde começa o chão
uniform float fuga_x = 0.43;           // x (UV) da porta do templo (para onde o chão foge)

// x = balanço dos raios, y = instante do ciclo, w = respiração * força
vec4 luz_onda() {
	float t = TIME;
	float balanco = 0.9 * sin(t * 0.21) + 0.5 * sin(t * 0.13 + 1.3);
	return vec4(balanco * 0.06, fract(t / raios_ciclo), 0.0, (0.8 + 0.2 * sin(t * 0.43) * sin(t * 0.27 + 0.8)) * forca_raios);
}

// o andar das duas camadas de cáustica
vec4 luz_cau() {
	float t = TIME;
	return vec4(fract(t * 0.035), fract(t * 0.020), fract(-t * 0.028 + 0.37), fract(t * 0.031 + 0.61));
}

// cáustica de parede (coisas em pé): uma camada, presa na foto
float cau_parede(vec2 uv, vec4 cau_t) {
	float ca = texture(caustica_perto, uv * vec2(2.3, 3.5) + cau_t.xy).a;
	return ca * ca * 0.9 * 0.6;
}

// cáustica de chão: em perspectiva, duas camadas andando para lados diferentes
float cau_chao(vec2 uv, vec4 cau_t) {
	float py = (uv.y - horizonte) / (1.0 - horizonte);
	float dd = 1.0 / (0.16 + py * 0.84);
	vec2 g = vec2((uv.x - fuga_x) * 3.2 * dd, dd * 2.4);
	float ca = texture(caustica, g * 0.55 + cau_t.xy).a;
	float cb = texture(caustica, g * 0.78 + cau_t.zw).a;
	return (min(ca, cb) * 1.8 + (ca + cb) * 0.12) * min(py * 4.5, 1.0);
}

// a cor `col` do ponto `uv` da foto com a luz do sol de agora
vec3 luz_do_mar(vec3 col, vec2 uv, vec4 onda_t, vec4 cau_t) {
	vec4 m = texture(profundidade, uv);
	// raios de sol: cada facho é uma direção saindo do sol (a inclinação
	// x/y); a textura traz os fachos nascendo, se juntando e sumindo, e o
	// balanço lento mexe todos juntos
	// (onde a máscara não tem raio não lê a textura deles: na Mali-G31 cada
	// leitura pesa, e o resultado é o mesmo)
	float r = 0.0;
	if (m.a > 0.004) {
		vec2 v = uv - sol;
		r = texture(raios, vec2(v.x / v.y * 0.42 + onda_t.x, onda_t.y)).r;
		float raio = r * m.a * onda_t.w;
		col = 1.0 - (1.0 - col) * (1.0 - vec3(0.80, 0.95, 1.0) * raio);
	}
	if (m.g > 0.06) {
		float c;
		if (uv.y <= horizonte || m.b > 0.99) {
			c = cau_parede(uv, cau_t);
		} else if (m.b < 0.01) {
			c = cau_chao(uv, cau_t);
		} else {
			c = mix(cau_chao(uv, cau_t), cau_parede(uv, cau_t), m.b);
		}
		// onde passa um facho a cáustica acende mais (a mesma luz)
		col += vec3(0.62, 0.92, 1.0) * c * m.g * forca_caustica * (0.75 + 1.6 * r * m.a);
	}
	return col;
}
