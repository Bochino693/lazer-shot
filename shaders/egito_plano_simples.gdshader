shader_type canvas_item;

// Colunas e estátuas do Egito (planos sem brilho próprio, Rodada 21): a mesma
// luz que passa no fundo passa nelas — a onda que sai do cristal na batida, o
// pulso da música e o crepúsculo da troca sol/lua —, então plano e fundo
// parecem uma peça só (antes a luz passava atrás delas e mostrava o recorte).
// As contas são as do shaders/deserto_fundo.gdshader, em UV da imagem.

uniform vec2 centro = vec2(0.5, 0.52);           // o cristal, em UV da imagem
uniform vec3 cor_energia = vec3(1.0, 0.74, 0.34);
uniform float onda = 9.0;
uniform float energia = 1.0;
uniform float batida = 0.0;
uniform float forca = 1.0;
uniform float crepusculo = 0.0;
instance uniform vec2 canto = vec2(0.0);         // canto do plano na imagem (px)

varying vec2 uv_img;

void vertex() {
	uv_img = (canto + VERTEX) / vec2(1024.0, 1536.0);
}

void fragment() {
	vec3 rgb = COLOR.rgb * (1.0 + 0.06 * batida);
	if (COLOR.a > 0.002 && onda < 0.625 && energia > 0.05) {
		float d = length((uv_img - centro) * vec2(1.0, 1.5));
		float anel = smoothstep(0.045, 0.0, abs(d - onda)) * clamp(1.0 - onda * 1.6, 0.0, 1.0);
		rgb += (cor_energia * anel * 0.10 + COLOR.rgb * anel * 0.18) * energia * forca;
	}
	if (crepusculo > 0.001) {
		rgb = mix(rgb, rgb * vec3(0.92, 0.62, 0.52), crepusculo * 0.8);
	}
	COLOR.rgb = rgb;
}
