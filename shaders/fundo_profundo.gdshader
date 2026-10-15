shader_type canvas_item;

// Fundo do Mar: a pintura inteira (com as pedras com escritas no lugar
// delas) e a luz do sol lá de fora andando por cima (shaders/mar_luz.gdshaderinc).
// A cena anda junta com a mira (scripts/mar_profundo.gd move o nó inteiro):
// nada se desloca do fundo, então não há recorte nem remendo para aparecer.
// As pedras são desenhadas por cima com os mesmos pixels e a mesma luz
// (shaders/mar_pedra.gdshader), só para esconder o que passa atrás delas.

#include "res://shaders/mar_luz.gdshaderinc"

varying vec4 cor_no;
// o que só depende do tempo sai no vértice (4 vezes por quadro, não por pixel)
varying flat vec4 onda_t;
varying flat vec4 cau_t;

void vertex() {
	cor_no = COLOR;
	onda_t = luz_onda();
	cau_t = luz_cau();
}

void fragment() {
	vec3 col = texture(TEXTURE, UV).rgb;
	COLOR = vec4(luz_do_mar(col, UV, onda_t, cau_t), 1.0) * cor_no;
}
