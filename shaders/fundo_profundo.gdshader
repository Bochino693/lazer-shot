shader_type canvas_item;

// Fundo com profundidade (Mar): a foto vira uma cena de câmera. Cada pixel
// tem a sua distância (sprites/mar_profundidade.png, tirada da própria
// imagem por tools/gerar_profundidade.py) e, quando a "câmera" anda junto com
// a mira, o que está perto anda mais que o que está longe — paralaxe pixel a
// pixel, como num jogo 3D. O nó do fundo já anda inteiro como a parte mais
// longe; aqui cada pixel ganha a diferença da distância dele.

uniform sampler2D profundidade : filter_linear, repeat_disable;
uniform vec2 olhar = vec2(0.0);        // quanto a câmera andou (px de tela)
uniform float inv_z_fundo = 0.125;     // 1/Z da parte mais longe (o nó já anda isso)
uniform float inv_z_longe = 0.1;       // 1/Z do preto do mapa
uniform float inv_z_perto = 1.4285714; // 1/Z do branco do mapa
uniform vec2 px_uv = vec2(0.0009765625, 0.00065104167);   // 1 px da textura em UV (1/1024, 1/1536)
uniform float escala = 1.0;            // px de tela por px da textura

varying vec4 cor_no;

void vertex() {
	cor_no = COLOR;
}

void fragment() {
	float inv_z = mix(inv_z_longe, inv_z_perto, texture(profundidade, UV).r);
	vec2 d = olhar * (inv_z_fundo - inv_z) / escala;
	COLOR = texture(TEXTURE, UV - d * px_uv) * cor_no;
}
