shader_type canvas_item;
render_mode blend_add;

// Luz cáustica no chão do Mar (scripts/mar_vida.gd): as linhas de luz que a
// superfície da água joga no fundo, andando sem parar. Duas camadas da mesma
// textura (sprites/mar_caustica.png, emenda nos quatro lados) andando para
// lados diferentes; onde as duas linhas se cruzam a luz fica forte, e as
// linhas se formam e se desfazem como na água de verdade. O chão está em
// perspectiva: perto as linhas são grandes, lá longe (perto do templo) bem
// pequenas e fracas.
// O sprite cobre o chão; UV.y = 0 longe (na linha do templo), 1 perto.

uniform sampler2D caustica : filter_linear_mipmap, repeat_enable;
uniform vec3 cor = vec3(0.62, 0.92, 1.0);
uniform float forca = 0.22;
uniform float centro_x = 0.43;      // x da porta do templo (para onde o chão foge)

void fragment() {
	float py = UV.y;
	float d = 1.0 / (0.16 + py * 0.84);                  // ~6 longe, 1 perto
	vec2 g = vec2((UV.x - centro_x) * 3.2 * d, d * 2.4);  // chão em perspectiva
	float a = texture(caustica, g * 0.55 + vec2(TIME * 0.035, TIME * 0.020)).a;
	float b = texture(caustica, g * 0.78 + vec2(-TIME * 0.028, TIME * 0.031) + vec2(0.37, 0.61)).a;
	float c = min(a, b) * 1.8 + (a + b) * 0.12;
	float fade = smoothstep(0.0, 0.28, py) * (1.0 - 0.3 * py);
	COLOR = vec4(cor, c * forca * fade);
}
