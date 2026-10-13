shader_type canvas_item;
render_mode blend_add;

// Brilho do diamante (scripts/deserto_vivo.gd), somado por cima da imagem.
// Máscara em 2x: R = corpo, G = arestas das facetas, B = miolo.
// De dia o diamante espalha as cores do arco-íris pelas arestas; de noite
// brilha vermelho por dentro. Nos dois: uma faixa de luz sobe girando, as
// facetas acendem uma de cada vez e o miolo pulsa com a música.

uniform float noite = 0.0;
uniform float grave = 0.0;
uniform float batida = 0.0;

varying vec4 cor_no;

void vertex() {
	cor_no = COLOR;
}

void fragment() {
	vec3 m = texture(TEXTURE, UV).rgb;
	float t = TIME;
	float s = fract(t * 0.17);
	float d = (UV.y + UV.x * 0.55) - (1.35 - s * 1.9);
	float faixa = exp(-d * d * 220.0);
	float cel = floor(UV.x * 4.0) + floor(UV.y * 9.0) * 5.0;
	float cint = 0.5 + 0.5 * sin(t * 2.3 + cel * 1.7);
	cint = cint * cint * cint; cint *= cint; cint *= cint;

	vec3 arco = 0.5 + 0.5 * cos(6.2831 * (UV.y * 1.6 + UV.x * 0.9 - t * 0.33 + vec3(0.0, 0.33, 0.67)));
	vec3 dia = arco * (m.g * (0.30 + 1.0 * faixa) + m.r * cint * 0.22)
		+ vec3(1.0, 0.92, 0.80) * faixa * m.r * 0.32
		+ vec3(1.0, 0.75, 0.95) * m.b * (0.12 + 0.30 * grave + 0.40 * batida);
	vec3 noite_c = vec3(1.0, 0.22, 0.32) * (m.g * (0.28 + 0.9 * faixa) + m.r * cint * 0.28)
		+ vec3(1.0, 0.62, 0.72) * faixa * m.r * 0.25
		+ vec3(1.0, 0.12, 0.28) * m.b * (0.18 + 0.38 * grave + 0.5 * batida);
	COLOR = vec4(mix(dia, noite_c, noite) * cor_no.a, 1.0);
}
