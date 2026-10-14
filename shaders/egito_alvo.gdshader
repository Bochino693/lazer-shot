shader_type canvas_item;

// Brasões do Egito (scripts/deserto.gd) dentro da cena 3D do fundo: cada
// brasão sabe a sua distância (inv_z = 1/Z) e some atrás do que, na foto,
// está mais perto que ele (cristal, obeliscos, Anúbis, colunas), pelo mesmo
// mapa de profundidade que move o fundo (sprites/egito_profundidade.png).
// Longe, a névoa do deserto (de dia) ou da noite cobre o brasão aos poucos.
// A teia de luz de cada brasão usa o mesmo material.

uniform sampler2D profundidade : filter_linear, repeat_disable;
uniform vec2 fundo_origem = vec2(0.0);          // canto (0,0) da imagem do fundo (px de tela)
uniform vec2 fundo_tam = vec2(1024.0, 1536.0);  // tamanho da imagem do fundo na tela (px)
uniform vec2 olhar = vec2(0.0);                 // quanto a câmera andou (px de tela)
uniform float inv_z_longe = 0.1;
uniform float inv_z_perto = 1.4285714;
uniform vec3 cor_nevoa = vec3(0.96, 0.74, 0.46);
instance uniform float inv_z = 1.0;
instance uniform float nevoa = 0.0;

varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float fundo_inv_z(vec2 p) {
	return mix(inv_z_longe, inv_z_perto, texture(profundidade, (p - fundo_origem) / fundo_tam).r);
}

void fragment() {
	// o pixel do fundo que aparece aqui veio de um pouco antes (a câmera andou)
	float zb = fundo_inv_z(mundo);
	zb = fundo_inv_z(mundo - olhar * (1.0 - zb));
	float esconde = smoothstep(inv_z + 0.012, inv_z + 0.045, zb);
	COLOR.rgb = mix(COLOR.rgb, cor_nevoa, nevoa);
	COLOR.a *= 1.0 - esconde;
}
