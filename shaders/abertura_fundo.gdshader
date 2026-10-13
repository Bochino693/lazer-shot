shader_type canvas_item;

// Fundo da abertura Lazer & Sport Games (scripts/abertura_ls.gd): parede de
// estande de tiro no escuro, com faixas de painel, um foco de luz vermelha no
// meio e um facho fraco de cima. Só aritmética (sem textura).

uniform float luz = 1.0;
uniform vec2 foco = vec2(0.5, 0.42);
uniform float pulso = 0.0;   // clarão vermelho no tiro final

void fragment() {
	vec2 uv = UV;
	float grao = sin(uv.x * 311.0 + sin(uv.y * 173.0) * 2.0) * 0.5 + 0.5;
	grao = grao * 0.035 + (sin(uv.y * 913.0 + uv.x * 37.0) * 0.5 + 0.5) * 0.012;
	float painel = (1.0 - smoothstep(0.0, 0.006, abs(fract(uv.y * 8.0) - 0.5) - 0.488)) * 0.06;
	vec2 d = (uv - foco) * vec2(1.0, 0.6);
	float spot = exp(-dot(d, d) * 7.5);
	float cone = smoothstep(0.30, 0.0, abs(uv.x - 0.5) - uv.y * 0.14) * (1.0 - uv.y) * 0.22;
	vec3 col = vec3(0.04, 0.04, 0.05) + grao + painel;
	col += vec3(0.42, 0.06, 0.07) * spot * (0.5 + pulso) * luz;
	col += vec3(0.85, 0.88, 1.0) * cone * 0.12 * luz;
	float vinheta = smoothstep(1.15, 0.30, length((uv - 0.5) * vec2(1.3, 1.0)));
	COLOR = vec4(col * vinheta, 1.0);
}
