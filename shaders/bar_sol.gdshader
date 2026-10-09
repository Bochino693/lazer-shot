shader_type canvas_item;
render_mode blend_add;

// Feixe de sol da janela do bar (somado por cima da parede).
// R = força do feixe, G = posição na largura do feixe, B = distância da janela.
// Listras finas de ar/poeira deslizam devagar pelo feixe e a luz respira
// como se nuvens passassem lá fora.

uniform vec3 cor_luz : source_color = vec3(1.0, 0.78, 0.48);
uniform float forca = 0.46;

varying vec4 cor_no;

void vertex() {
	cor_no = COLOR;
}

void fragment() {
	vec3 t = texture(TEXTURE, UV).rgb;
	float largura = t.g;
	float longe = t.b;
	float listras = 0.72
		+ 0.18 * sin(largura * 210.0 + TIME * 0.55 - longe * 3.0)
		+ 0.10 * sin(largura * 530.0 - TIME * 0.9 + longe * 7.0);
	float nuvem = 0.86 + 0.14 * sin(TIME * 0.21) * sin(TIME * 0.137 + 1.3);
	COLOR = vec4(cor_luz * cor_no.rgb, t.r * listras * nuvem * forca * cor_no.a);
}
