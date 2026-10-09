shader_type canvas_item;

// Baleia recortada do fundo: o corpo ondula e a cauda bate.
// Cabeça à esquerda (UV.x = 0), cauda à direita (UV.x = 1).

uniform float fase = 0.0;
uniform float batida = 1.6;      // batidas da cauda por segundo
uniform float amplitude = 0.07;  // em UV (altura do recorte)

// No fragment o COLOR já vem multiplicado pela textura; a cor do nó
// (modulate) é guardada aqui no vertex.
varying vec4 cor_no;

void vertex() {
	cor_no = COLOR;
}

void fragment() {
	float x = UV.x;
	float cauda = smoothstep(0.42, 1.0, x);
	float corpo = 0.12 * smoothstep(0.0, 0.5, x);
	float onda = sin(TIME * batida * 6.2831 + fase - x * 3.4);
	vec2 uv = UV;
	uv.y += onda * amplitude * (cauda * cauda + corpo);
	// a cauda encolhe um pouco quando passa pelo meio da batida (efeito de giro)
	uv.x += cos(TIME * batida * 6.2831 + fase - x * 3.4) * 0.012 * cauda;
	vec4 c = texture(TEXTURE, uv);
	COLOR = c * cor_no;
}
