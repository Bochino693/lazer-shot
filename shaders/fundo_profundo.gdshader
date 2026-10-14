shader_type canvas_item;

// Fundo com profundidade (Mar): a foto vira uma cena de câmera. Cada pixel
// tem a sua distância (sprites/mar_profundidade.png, tirada da própria
// imagem por tools/gerar_profundidade.py) e, quando a "câmera" anda junto com
// a mira, o que está perto anda mais que o que está longe — paralaxe pixel a
// pixel, como num jogo 3D. O nó do fundo já anda inteiro como a parte mais
// longe; aqui cada pixel ganha a diferença da distância dele.
//
// A luz do sol lá de fora, entrando pela superfície, nunca para:
//   - raios: fachos largos saindo do alto, balançando devagar e respirando
//     (as ondas da superfície mexem a luz); fortes na água aberta, fracos
//     na frente das coisas perto;
//   - cáustica: as linhas de luz que a superfície joga em tudo que está
//     embaixo, andando sem parar — no chão em perspectiva, nas pedras, no
//     templo e nos corais (onde a máscara diz que há superfície).
// Máscara (mar_profundidade.png): R = distância, G = onde cai a cáustica,
// A = força parada dos raios (queda saindo do sol e onde eles aparecem).
// Leve para a TV box: sem seno por pixel — os fachos já vêm animados numa
// textura (sprites/mar_raios.png: x = direção, y = tempo, em ciclo), lida
// uma vez; o que só depende do tempo é feito no vértice; a cáustica das
// coisas em pé é uma camada só, sem mipmap. Tudo num desenho só.

uniform sampler2D profundidade : filter_linear, repeat_disable;
uniform sampler2D caustica : filter_linear_mipmap, repeat_enable;   // sprites/mar_caustica.png (alfa)
uniform sampler2D caustica_perto : filter_linear, repeat_enable;    // a mesma, sem mipmap (onde ela fica grande)
uniform sampler2D raios : filter_linear, repeat_enable;             // sprites/mar_raios.png (raios animados)
uniform float raios_ciclo = 48.0;      // segundos de uma volta de mar_raios.png (RAIOS_CICLO do tools/gerar_fx.py)
uniform vec2 olhar = vec2(0.0);        // quanto a câmera andou (px de tela)
uniform float inv_z_fundo = 0.125;     // 1/Z da parte mais longe (o nó já anda isso)
uniform float inv_z_longe = 0.1;       // 1/Z do preto do mapa
uniform float inv_z_perto = 1.4285714; // 1/Z do branco do mapa
uniform vec2 px_uv = vec2(0.0009765625, 0.00065104167);   // 1 px da textura em UV (1/1024, 1/1536)
uniform float escala = 1.0;            // px de tela por px da textura
uniform vec2 sol = vec2(0.52, -0.10);  // de onde a luz entra (UV da foto, acima do topo; SOL_MAR do tools/gerar_profundidade.py)
uniform float forca_raios = 1.0;
uniform float forca_caustica = 0.34;
uniform float horizonte = 0.515;       // y (UV) onde começa o chão
uniform float fuga_x = 0.43;           // x (UV) da porta do templo (para onde o chão foge)

varying vec4 cor_no;
// o que só depende do tempo sai no vértice (4 vezes por quadro, não por pixel)
varying flat vec4 onda_t;   // x = balanço dos raios, y = instante do ciclo, w = respiração * força
varying flat vec4 cau_t;    // andar das duas camadas de cáustica

void vertex() {
	cor_no = COLOR;
	float t = TIME;
	float balanco = 0.9 * sin(t * 0.21) + 0.5 * sin(t * 0.13 + 1.3);
	onda_t = vec4(balanco * 0.06, fract(t / raios_ciclo), 0.0, (0.8 + 0.2 * sin(t * 0.43) * sin(t * 0.27 + 0.8)) * forca_raios);
	cau_t = vec4(fract(t * 0.035), fract(t * 0.020), fract(-t * 0.028 + 0.37), fract(t * 0.031 + 0.61));
}

void fragment() {
	vec4 m = texture(profundidade, UV);
	float inv_z = mix(inv_z_longe, inv_z_perto, m.r);
	vec2 d = olhar * (inv_z_fundo - inv_z) / escala;
	vec2 uv = UV - d * px_uv;
	vec3 col = texture(TEXTURE, uv).rgb;

	// raios de sol: cada facho é uma direção saindo do sol (a inclinação
	// x/y); a textura traz os fachos nascendo, se juntando e sumindo, e o
	// balanço lento mexe todos juntos
	vec2 v = UV - sol;
	float r = texture(raios, vec2(v.x / v.y * 0.42 + onda_t.x, onda_t.y)).r;
	float raio = r * m.a * onda_t.w;
	col = 1.0 - (1.0 - col) * (1.0 - vec3(0.80, 0.95, 1.0) * raio);

	// cáustica: no chão em perspectiva (grande perto, miúda lá longe), duas
	// camadas andando para lados diferentes; nas coisas em pé (templo,
	// paredes) uma camada só, presa na foto e mais fraca
	if (m.g > 0.06) {
		float c;
		float longe;
		if (uv.y > horizonte) {
			float py = (uv.y - horizonte) / (1.0 - horizonte);
			float dd = 1.0 / (0.16 + py * 0.84);
			vec2 g = vec2((uv.x - fuga_x) * 3.2 * dd, dd * 2.4);
			float ca = texture(caustica, g * 0.55 + cau_t.xy).a;
			float cb = texture(caustica, g * 0.78 + cau_t.zw).a;
			c = min(ca, cb) * 1.8 + (ca + cb) * 0.12;
			longe = min(py * 4.5, 1.0);
		} else {
			float ca = texture(caustica_perto, uv * vec2(2.3, 3.5) + cau_t.xy).a;
			c = ca * ca * 0.9;
			longe = 0.6;
		}
		// onde passa um facho a cáustica acende mais (a mesma luz)
		col += vec3(0.62, 0.92, 1.0) * c * m.g * longe * forca_caustica * (0.75 + 1.6 * r * m.a);
	}
	COLOR = vec4(col, 1.0) * cor_no;
}
