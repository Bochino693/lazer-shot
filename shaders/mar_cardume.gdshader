shader_type canvas_item;

// Cardume (scripts/mar_vida.gd): um MultiMesh, um peixe por instância. Todo o
// nado é calculado aqui, sem custo de processador por quadro:
//   - o cardume atravessa a água de "inicio" a "fim" ondulando, surge e some
//     na névoa e recomeça;
//   - cada peixe passeia um pouco em volta do seu lugar e bate o rabo.
// A instância só guarda o lugar do peixe (meio do caminho + lugar no cardume,
// só translação) e, na cor:
// r = fase própria, g = tamanho, b = distância (mais longe = mais apagado).

uniform vec2 meio = vec2(0.0);       // meio do caminho (a instância já está lá)
uniform vec2 inicio = vec2(0.0);
uniform vec2 fim = vec2(100.0, 0.0);
uniform float periodo = 30.0;
uniform float fase = 0.0;
uniform float onda = 14.0;
uniform vec4 cor : source_color = vec4(0.10, 0.20, 0.30, 0.8);

varying float alfa;
varying vec3 tom;

void vertex() {
	float propria = COLOR.r;
	float longe = COLOR.b;
	float tamanho = (0.42 + COLOR.g * 0.30) * (1.0 - longe * 0.35);
	float t = TIME / periodo + fase;
	float k = fract(t);
	vec2 dir = fim - inicio;
	float lado = dir.x < 0.0 ? -1.0 : 1.0;
	vec2 centro = inicio + dir * k;
	centro.y += sin(t * 6.2831 * 1.7) * onda;
	float tp = TIME * (0.5 + propria) + propria * 40.0;
	vec2 solto = vec2(sin(tp * 0.7) * 7.0, cos(tp * 0.9) * 3.5);
	vec2 v = VERTEX * tamanho;
	float rabo = 1.0 - UV.x;
	v.y += sin(TIME * (8.0 + propria * 4.0) + propria * 20.0 + UV.x * 3.0) * 1.4 * rabo * tamanho;
	v.x *= lado;
	VERTEX = v + (centro - meio) + solto;
	alfa = smoothstep(0.0, 0.12, k) * smoothstep(1.0, 0.86, k) * (1.0 - longe * 0.5);
	tom = mix(cor.rgb, vec3(0.42, 0.64, 0.82), longe * 0.7);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tom * tex.rgb, tex.a * cor.a * alfa);
}
