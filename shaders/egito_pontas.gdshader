shader_type canvas_item;

// Pontas de ouro das pirâmides (scripts/deserto_vivo.gd), em 2x.
// Textura de dados: R = detalhe do metal, G = face (0,25 esquerda /
// 0,75 direita), B = quinas, A = cobertura.
// De dia: ouro quente, a face iluminada troca devagar conforme a luz anda e
// um reflexo do sol corre de pirâmide em pirâmide. De noite: o mesmo ouro sob
// o luar, frio e prateado, com reflexo azulado mais lento.

uniform float noite = 0.0;
uniform float grave = 0.0;
uniform float batida = 0.0;

varying vec4 cor_no;

void vertex() {
	cor_no = COLOR;
}

void fragment() {
	vec4 d = texture(TEXTURE, UV);
	float cob = d.a;
	float k = 1.0 / max(cob, 0.004);
	float det = d.r * k;
	float esq = step(d.g * k, 0.5);
	float quina = clamp(d.b * k, 0.0, 1.0);
	float t = TIME;

	// a luz anda: o lado aceso vai trocando aos poucos; mais claro no ápice
	float lado = sin(t * 0.21);
	float ilum = mix(0.52 + 0.24 * lado, 1.0 - 0.16 * lado, esq);
	float apice = 1.0 + 0.35 * (1.0 - smoothstep(0.0, 0.75, UV.y));

	// reflexo correndo pela fila de pirâmides
	float vel = mix(0.085, 0.05, noite);
	float s = fract(t * vel) * 1.6 - 0.3;
	float x = UV.x - s + (UV.y - 0.5) * 0.25;
	float reflexo = exp(-x * x * 900.0);

	vec3 ouro_dia = vec3(1.0, 0.70, 0.18) * det * 1.75 * ilum * apice;
	ouro_dia += vec3(1.0, 0.96, 0.78) * (reflexo * 0.85 + quina * (0.30 + 0.9 * reflexo + 0.35 * batida));
	vec3 ouro_noite = vec3(0.82, 0.62, 0.28) * det * 1.05 * ilum * apice;
	ouro_noite = mix(ouro_noite, vec3(0.50, 0.60, 0.82) * det * ilum, 0.22);
	ouro_noite += vec3(0.72, 0.86, 1.0) * (reflexo * 0.55 + quina * (0.22 + 0.7 * reflexo + 0.25 * grave));

	vec3 col = mix(ouro_dia, ouro_noite, noite);
	COLOR = vec4(col, cob * cor_no.a);
}
