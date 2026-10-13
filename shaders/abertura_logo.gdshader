shader_type canvas_item;

// Logo da Lazer & Sport na abertura: clarão branco quando o tiro acerta e
// uma faixa de brilho que passa por cima depois.

uniform float faixa = -1.0;   // posição da faixa de brilho (-0.3 .. 1.4)
uniform float branco = 0.0;   // clarão de entrada (0..1)

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = (UV.x * 0.8 + UV.y * 0.6) - faixa;
	float b = exp(-d * d * 110.0);
	c.rgb += vec3(1.0) * b * 0.45 * c.a;
	c.rgb = mix(c.rgb, vec3(1.0), branco);
	COLOR = c * COLOR;
}
