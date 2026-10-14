shader_type canvas_item;

// Um pedaço do próprio fundo do mar desenhado de novo por cima de algo que
// está mais longe (scripts/mar_vida.gd): mesma textura e mesma caixa da foto,
// só recortado pela máscara. Assim o navio afunda atrás do templo e do
// poneglifo pequeno sem nenhuma diferença de cor na frente dele.

uniform sampler2D mascara : filter_linear, repeat_disable;
uniform vec4 regiao = vec4(0.0, 0.0, 1.0, 1.0);   // caixa do recorte em UV da textura

void fragment() {
	vec2 luv = (UV - regiao.xy) / regiao.zw;
	COLOR.a *= texture(mascara, luv).r;
}
