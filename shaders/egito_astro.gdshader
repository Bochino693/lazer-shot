shader_type canvas_item;

// O sol / a lua passando atrás das pirâmides (pôr do sol e nascer da lua,
// scripts/deserto_vivo.gd): o pedaço do astro que fica atrás de uma pirâmide
// ou abaixo do horizonte não aparece (borda lisa, 1 px). Só fica no astro
// durante a troca; parado no céu ele não usa shader nenhum.
// As contas são em px da imagem do fundo (a camada do céu, que anda com a
// câmera junto com as pirâmides): para_imagem leva da tela para lá.

uniform vec4 para_imagem = vec4(0.0, 0.0, 1.0, 1.0);   // xy = origem da camada (tela), zw = escala
uniform float horizonte = 700.0;
uniform vec2 piramides[9];                              // 3 triângulos (ponta, base esq, base dir)

varying vec2 img;

void vertex() {
	vec2 mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	img = (mundo - para_imagem.xy) / para_imagem.zw;
}

// distância (px, com sinal) do ponto p até a reta ab
float lado(vec2 p, vec2 a, vec2 b) {
	vec2 e = b - a;
	return (e.x * (p.y - a.y) - e.y * (p.x - a.x)) / max(length(e), 0.001);
}

void fragment() {
	float atras = clamp(img.y - horizonte + 0.5, 0.0, 1.0);
	for (int i = 0; i < 3; i++) {
		vec2 a = piramides[i * 3];
		vec2 b = piramides[i * 3 + 1];
		vec2 c = piramides[i * 3 + 2];
		float s = sign(lado(c, a, b));
		float d = min(min(lado(img, a, b) * s, lado(img, b, c) * s), lado(img, c, a) * s);
		atras = max(atras, clamp(d + 0.5, 0.0, 1.0));
	}
	COLOR.a *= 1.0 - atras;
}
