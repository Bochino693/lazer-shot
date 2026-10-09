shader_type canvas_item;

// Fundo do Deserto Sagrado: a imagem fixa ganha vida só onde a máscara diz.
//   R = feixes de energia (pulsos saem do cristal e correm até os obeliscos)
//   G = cristal e pontas dos obeliscos (brilho que sobe e cintila)
//   B = disco do sol/lua (respira devagar)
// Fora da máscara é só a imagem: custa o mesmo que desenhar a textura.

uniform sampler2D mascara : filter_linear, repeat_disable;
uniform vec3 cor_energia = vec3(1.0, 0.72, 0.32);
uniform vec2 centro = vec2(0.5, 0.52);   // cristal, em UV da imagem
uniform float forca = 1.0;

// No fragment o COLOR já vem multiplicado pela textura; a cor do nó
// (modulate, usado no cruzamento sol/lua) é guardada aqui no vertex.
varying vec4 cor_no;

void vertex() {
	cor_no = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 m = texture(mascara, UV).rgb;
	if (m.r + m.g + m.b < 0.004) {
		COLOR = base * cor_no;
	} else {
		float t = TIME;
		// distância ao cristal com a proporção da imagem (2:3)
		float d = length((UV - centro) * vec2(1.0, 1.5));

		float pulso = 0.5 + 0.5 * sin(d * 52.0 - t * 6.5);
		pulso = pulso * pulso * pulso * pulso;
		pulso = pulso * pulso;
		float laser = m.r * (0.22 + 1.15 * pulso + 0.08 * sin(t * 11.0));

		float faixa = 0.5 + 0.5 * sin(UV.y * 64.0 + t * 3.2);
		faixa = faixa * faixa;
		float cintila = 0.5 + 0.5 * sin(t * 7.3 + UV.x * 90.0);
		float cristal = m.g * (0.10 + 0.42 * faixa + 0.14 * cintila);

		float disco = m.b * (0.07 + 0.07 * sin(t * 1.35));

		vec3 soma = cor_energia * laser * 0.85 + base.rgb * (cristal + disco) + cor_energia * cristal * 0.18;
		COLOR = vec4(base.rgb + soma * forca, base.a) * cor_no;
	}
}
